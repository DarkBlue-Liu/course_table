import '../models/scheduled_entry.dart';
import '../models/time_slot.dart';
import '../models/week_type.dart';
import '../view_models/week_grid_item.dart';

/// 周视图构建：纯函数。
/// 输入「第几周 + 所有课程时段 + 节次表」，输出可直接渲染的课程块列表。
///
/// 负责三件事：按周过滤（含单双周）、跨节次合并、同格重叠分列（lane）。
/// 不碰 Widget、不查数据库。
class WeekGridBuilder {
  const WeekGridBuilder._();

  static List<WeekGridItem> build({
    required int week,
    required List<ScheduledEntry> entries,
    List<TimeSlot> timeSlots = const <TimeSlot>[],
  }) {
    final int maxSlot = _maxSlotOf(timeSlots);

    final List<WeekGridItem> visible = <WeekGridItem>[];
    for (final ScheduledEntry entry in entries) {
      final _ScheduleGeometry? geometry = _resolve(entry, week);
      if (geometry == null) {
        continue;
      }
      int endSlot = geometry.endSlot;
      if (maxSlot > 0 && endSlot > maxSlot) {
        endSlot = maxSlot;
      }
      if (geometry.startSlot > endSlot) {
        continue;
      }
      visible.add(
        WeekGridItem(
          courseId: entry.course.id,
          name: entry.course.name,
          location: entry.course.location,
          colorValue: entry.course.colorValue,
          weekday: geometry.weekday,
          startSlot: geometry.startSlot,
          endSlot: endSlot,
        ),
      );
    }

    return _assignLanes(visible);
  }

  /// 当前周某天实际有哪些课（用于「今日课程」卡片）。
  static List<WeekGridItem> buildForDay({
    required int week,
    required int weekday,
    required List<ScheduledEntry> entries,
    List<TimeSlot> timeSlots = const <TimeSlot>[],
  }) {
    final List<WeekGridItem> all = build(
      week: week,
      entries: entries,
      timeSlots: timeSlots,
    );
    final List<WeekGridItem> dayItems =
        all.where((WeekGridItem item) => item.weekday == weekday).toList();
    dayItems.sort(
        (WeekGridItem a, WeekGridItem b) => a.startSlot.compareTo(b.startSlot));
    return dayItems;
  }

  static _ScheduleGeometry? _resolve(ScheduledEntry entry, int week) {
    final int weekday = entry.schedule.weekday;
    if (weekday < 1 || weekday > 7) {
      return null;
    }
    if (week < entry.schedule.startWeek || week > entry.schedule.endWeek) {
      return null;
    }
    if (!entry.schedule.weekType.matchesWeek(week)) {
      return null;
    }
    final int start = entry.schedule.startSlot;
    final int end = entry.schedule.endSlot;
    if (start < 1 || end < start) {
      return null;
    }
    return _ScheduleGeometry(weekday: weekday, startSlot: start, endSlot: end);
  }

  static int _maxSlotOf(List<TimeSlot> slots) {
    int max = 0;
    for (final TimeSlot slot in slots) {
      if (slot.slotIndex > max) {
        max = slot.slotIndex;
      }
    }
    return max;
  }

  /// 同一天内重叠的块分列：贪心占列 + 按重叠簇计算总列数。
  static List<WeekGridItem> _assignLanes(List<WeekGridItem> items) {
    final Map<int, List<WeekGridItem>> byDay = <int, List<WeekGridItem>>{};
    for (final WeekGridItem item in items) {
      byDay.putIfAbsent(item.weekday, () => <WeekGridItem>[]).add(item);
    }

    final List<WeekGridItem> result = <WeekGridItem>[];
    for (final List<WeekGridItem> dayItems in byDay.values) {
      dayItems.sort((WeekGridItem a, WeekGridItem b) {
        final int byStart = a.startSlot.compareTo(b.startSlot);
        if (byStart != 0) {
          return byStart;
        }
        return b.endSlot.compareTo(a.endSlot);
      });

      // laneEnds[lane] = 该列最近一个块的结束节次
      final List<int> laneEnds = <int>[];
      final List<int> lanes = <int>[];
      for (final WeekGridItem item in dayItems) {
        int lane = -1;
        for (int i = 0; i < laneEnds.length; i++) {
          if (laneEnds[i] < item.startSlot) {
            lane = i;
            break;
          }
        }
        if (lane == -1) {
          laneEnds.add(item.endSlot);
          lane = laneEnds.length - 1;
        } else {
          laneEnds[lane] = item.endSlot;
        }
        lanes.add(lane);
      }

      for (int i = 0; i < dayItems.length; i++) {
        final WeekGridItem item = dayItems[i];
        int maxLaneInCluster = lanes[i];
        for (int j = 0; j < dayItems.length; j++) {
          if (i == j) {
            continue;
          }
          final WeekGridItem other = dayItems[j];
          final bool overlap = item.startSlot <= other.endSlot &&
              other.startSlot <= item.endSlot;
          if (overlap && lanes[j] > maxLaneInCluster) {
            maxLaneInCluster = lanes[j];
          }
        }
        result.add(
            item.copyWith(lane: lanes[i], laneCount: maxLaneInCluster + 1));
      }
    }

    result.sort((WeekGridItem a, WeekGridItem b) {
      final int byDay = a.weekday.compareTo(b.weekday);
      if (byDay != 0) {
        return byDay;
      }
      return a.startSlot.compareTo(b.startSlot);
    });
    return result;
  }
}

class _ScheduleGeometry {
  const _ScheduleGeometry({
    required this.weekday,
    required this.startSlot,
    required this.endSlot,
  });

  final int weekday;
  final int startSlot;
  final int endSlot;
}

/// 供外部（测试/UI）判断某周是否显示某个 WeekType，避免重复实现。
bool weekTypeMatches(WeekType type, int week) => type.matchesWeek(week);
