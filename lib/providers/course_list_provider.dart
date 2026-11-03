import 'package:flutter/foundation.dart';

import '../core/utils/logger.dart';
import '../domain/models/course.dart';
import '../domain/models/course_schedule.dart';
import '../domain/models/scheduled_entry.dart';
import '../domain/models/semester.dart';
import '../domain/models/time_slot.dart';
import '../repositories/course_repository.dart';
import '../repositories/semester_repository.dart';
import '../repositories/time_slot_repository.dart';
import '../services/course_service.dart';
import '../services/reminder_service.dart';
import 'settings_provider.dart';

/// 课程列表状态：所有页面读课程数据都走这里。
/// 写操作统一经过 CourseService（校验 + 冲突 + 事务），随后重排通知。
class CourseListProvider extends ChangeNotifier {
  CourseListProvider({
    required CourseService courseService,
    required CourseRepository courseRepository,
    required SemesterRepository semesterRepository,
    required TimeSlotRepository timeSlotRepository,
    required ReminderService reminderService,
    required SettingsProvider settingsProvider,
  })  : _courseService = courseService,
        _courseRepository = courseRepository,
        _semesterRepository = semesterRepository,
        _timeSlotRepository = timeSlotRepository,
        _reminderService = reminderService,
        _settingsProvider = settingsProvider;

  final CourseService _courseService;
  final CourseRepository _courseRepository;
  final SemesterRepository _semesterRepository;
  final TimeSlotRepository _timeSlotRepository;
  final ReminderService _reminderService;
  final SettingsProvider _settingsProvider;

  List<ScheduledEntry> _entries = <ScheduledEntry>[];
  bool _loading = true;
  int _dataVersion = 0;

  List<ScheduledEntry> get entries =>
      List<ScheduledEntry>.unmodifiable(_entries);

  bool get isLoading => _loading;

  bool get isEmpty => _entries.isEmpty;

  /// 数据版本号，可作为周视图缓存 key 的一部分。
  int get dataVersion => _dataVersion;

  /// 去重后的课程列表（按创建时间倒序，与 Repository 一致）。
  List<Course> get courses {
    final Map<int, Course> unique = <int, Course>{};
    for (final ScheduledEntry entry in _entries) {
      final int? id = entry.course.id;
      if (id != null) {
        unique[id] = entry.course;
      }
    }
    final List<Course> list = unique.values.toList();
    list.sort((Course a, Course b) {
      final DateTime? aTime = a.createdAt;
      final DateTime? bTime = b.createdAt;
      if (aTime == null || bTime == null) {
        return 0;
      }
      return bTime.compareTo(aTime);
    });
    return list;
  }

  List<CourseSchedule> schedulesOf(int courseId) => _entries
      .where((ScheduledEntry entry) => entry.course.id == courseId)
      .map((ScheduledEntry entry) => entry.schedule)
      .toList();

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    await _reloadEntries(notify: false);
    _loading = false;
    notifyListeners();
  }

  Future<SaveResult> saveCourse({
    required Course course,
    required List<CourseSchedule> schedules,
    bool force = false,
  }) async {
    final SaveResult result = await _courseService.saveCourse(
      course: course,
      schedules: schedules,
      force: force,
    );
    if (result.isSaved) {
      await _reloadEntries(notify: false);
      await syncReminders();
      _dataVersion++;
      notifyListeners();
    }
    return result;
  }

  Future<void> deleteCourse(int courseId) async {
    await _courseService.deleteCourse(courseId);
    await _reloadEntries(notify: false);
    await syncReminders();
    _dataVersion++;
    notifyListeners();
  }

  Future<Course?> findCourse(int courseId) =>
      _courseRepository.getCourse(courseId);

  /// 重新排布未来两周的上课提醒。任何影响课程/学期/节次/提醒设置的变化后都要调用。
  Future<void> syncReminders() async {
    try {
      final Semester? semester = await _semesterRepository.getSemester();
      final List<TimeSlot> slots = await _timeSlotRepository.getAll();
      await _reminderService.syncAll(
        semester: semester,
        entries: _entries,
        slots: slots,
        enabled: _settingsProvider.reminderEnabled,
        leadMinutes: _settingsProvider.leadMinutes,
      );
    } catch (error, stackTrace) {
      Logger.error('重排提醒失败', error, stackTrace);
    }
  }

  Future<void> _reloadEntries({bool notify = true}) async {
    try {
      _entries = await _courseRepository.getAllEntries();
    } catch (error, stackTrace) {
      Logger.error('读取课程失败', error, stackTrace);
      _entries = <ScheduledEntry>[];
    }
    if (notify) {
      notifyListeners();
    }
  }
}
