import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdb;
import 'package:timezone/timezone.dart' as tz;

import '../core/constants/app_constants.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/logger.dart';
import '../domain/models/semester.dart';
import '../domain/models/scheduled_entry.dart';
import '../domain/models/time_slot.dart';
import '../domain/rules/week_calculator.dart';

/// 通知的唯一出口：其它任何地方都不允许直接碰通知插件。
///
/// 设计要点：
/// - `syncAll()` 先 `cancelAll()` 再全量重排，避免 id 对不上的脏通知；
/// - 只排未来 [AppConstants.reminderScheduleWindowDays] 天，避开系统 pending 闹钟上限；
/// - 用互斥标记防止连续保存造成的竞态；
/// - `tz.local` 必须显式设置，否则默认 UTC 会让所有提醒偏移 8 小时。
class ReminderService {
  ReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;
  bool _syncing = false;

  /// 1.0 固定东八区：目标用户在国内，且不引入额外时区插件。
  /// 若以后要支持出国，把这里换成 flutter_timezone 读取设备时区即可。
  static const String _defaultTimezone = 'Asia/Shanghai';

  static const String _channelId = 'class_reminder';
  static const String _channelName = '上课提醒';
  static const String _channelDescription = '上课前提醒，默认提前 15 分钟';

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    tzdb.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(_defaultTimezone));
    } catch (error) {
      Logger.error('设置时区失败，回退 UTC', error);
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
    _initialized = true;
    Logger.debug('通知初始化完成');
  }

  /// Android 13+ 需要运行时通知权限。
  Future<bool> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return true;
    }
    final bool? granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Android 12+ 精确闹钟权限。
  Future<bool> canScheduleExact() async {
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return true;
    }
    final bool? allowed = await android.canScheduleExactNotifications();
    return allowed ?? false;
  }

  /// 全量重排通知。任何课程/学期/节次/提醒设置的变更后都要调用。
  ///
  /// [enabled] 为 false 时只清空不重排。
  Future<void> syncAll({
    required Semester? semester,
    required List<ScheduledEntry> entries,
    required List<TimeSlot> slots,
    required bool enabled,
    required int leadMinutes,
  }) async {
    if (!_initialized) {
      await init();
    }
    if (_syncing) {
      // 正在重排中，丢弃本次请求：变更后的状态会在下一次触发时被完整重建。
      Logger.debug('syncAll 已在执行，跳过本次');
      return;
    }
    _syncing = true;
    try {
      await _plugin.cancelAll();
      if (!enabled || semester == null || entries.isEmpty) {
        return;
      }

      final Map<int, TimeSlot> slotById = <int, TimeSlot>{
        for (final TimeSlot slot in slots) slot.slotIndex: slot,
      };
      if (slotById.isEmpty) {
        return;
      }

      final bool exact = await canScheduleExact();
      final AndroidScheduleMode scheduleMode = exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      if (!exact) {
        Logger.debug('无精确闹钟权限，降级为 inexact');
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails details =
          NotificationDetails(android: androidDetails);

      final DateTime now = DateTime.now();
      final DateTime today = AppDateUtils.dateOnly(now);
      int notificationId = 0;

      for (int offset = 0;
          offset < AppConstants.reminderScheduleWindowDays;
          offset++) {
        final DateTime day = AppDateUtils.addDays(today, offset);
        final int weekday = day.weekday;

        for (final ScheduledEntry entry in entries) {
          if (entry.schedule.weekday != weekday) {
            continue;
          }
          final int rawWeek = WeekCalculator.rawWeek(
            firstWeekMonday: semester.firstWeekMonday,
            today: day,
          );
          if (rawWeek < 1 || rawWeek > semester.totalWeeks) {
            continue;
          }
          if (rawWeek < entry.schedule.startWeek ||
              rawWeek > entry.schedule.endWeek ||
              !entry.schedule.weekType.matchesWeek(rawWeek)) {
            continue;
          }
          final TimeSlot? slot = slotById[entry.schedule.startSlot];
          if (slot == null) {
            continue;
          }

          final DateTime classStart = DateTime(
            day.year,
            day.month,
            day.day,
            slot.startMinute ~/ 60,
            slot.startMinute % 60,
          );
          final DateTime remindAt =
              classStart.subtract(Duration(minutes: leadMinutes));
          if (!remindAt.isAfter(now)) {
            continue;
          }

          final String title = '${entry.course.name} · ${slot.startLabel} 上课';
          final String body = <String>[
            if (entry.course.location.isNotEmpty) entry.course.location,
            entry.course.teacher,
          ].where((String part) => part.isNotEmpty).join(' · ');

          await _plugin.zonedSchedule(
            notificationId++,
            title,
            body.isEmpty ? '别忘了上课' : body,
            tz.TZDateTime.from(remindAt, tz.local),
            details,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: scheduleMode,
          );
        }
      }
      Logger.debug('重排通知完成，共 $notificationId 条');
    } catch (error, stackTrace) {
      Logger.error('重排通知失败', error, stackTrace);
    } finally {
      _syncing = false;
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) {
      await init();
    }
    await _plugin.cancelAll();
  }
}
