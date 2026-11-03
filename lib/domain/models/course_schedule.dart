import '../../core/utils/date_utils.dart';
import 'week_type.dart';

/// 一次上课时段：星期几 + 节次区间 + 周次区间 + 单双周。
/// 一门课可以有多条（一周两次、不同周次不同教室）。
class CourseSchedule {
  const CourseSchedule({
    this.id,
    this.courseId = 0,
    required this.weekday,
    required this.startSlot,
    required this.endSlot,
    required this.startWeek,
    required this.endWeek,
    this.weekType = WeekType.all,
  });

  final int? id;

  /// 所属课程 id；新建课程时为 0，保存时由 Repository 回填。
  final int courseId;

  /// 1 = 周一 ... 7 = 周日。
  final int weekday;
  final int startSlot;
  final int endSlot;
  final int startWeek;
  final int endWeek;
  final WeekType weekType;

  int get slotSpan => endSlot - startSlot + 1;

  CourseSchedule copyWith({
    int? id,
    int? courseId,
    int? weekday,
    int? startSlot,
    int? endSlot,
    int? startWeek,
    int? endWeek,
    WeekType? weekType,
  }) {
    return CourseSchedule(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      weekday: weekday ?? this.weekday,
      startSlot: startSlot ?? this.startSlot,
      endSlot: endSlot ?? this.endSlot,
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      weekType: weekType ?? this.weekType,
    );
  }

  /// 节次区间是否与另一条相交。
  bool slotsOverlap(CourseSchedule other) =>
      startSlot <= other.endSlot && other.startSlot <= endSlot;

  /// 周次集合是否有交集（正确处理单双周）。
  bool weeksOverlap(CourseSchedule other) {
    final int from = startWeek > other.startWeek ? startWeek : other.startWeek;
    final int to = endWeek < other.endWeek ? endWeek : other.endWeek;
    for (int week = from; week <= to; week++) {
      if (weekType.matchesWeek(week) && other.weekType.matchesWeek(week)) {
        return true;
      }
    }
    return false;
  }

  /// 用于 UI 展示的简短描述：周一 3-4 节 · 第1-16周 · 单周
  String get summary {
    final String day = AppDateUtils.weekdayLabel(weekday);
    final String slots =
        startSlot == endSlot ? '第$startSlot节' : '第$startSlot-$endSlot节';
    final String weeks =
        startWeek == endWeek ? '第$startWeek周' : '第$startWeek-$endWeek周';
    final String type = weekType == WeekType.all ? '' : ' · ${weekType.label}';
    return '$day $slots · $weeks$type';
  }

  @override
  String toString() => 'CourseSchedule($courseId, $summary)';
}
