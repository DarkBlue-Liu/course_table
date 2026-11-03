import '../models/conflict.dart';
import '../models/course_schedule.dart';
import '../models/scheduled_entry.dart';

/// 冲突检测：纯函数，只返回冲突列表，不弹窗、不写库。
///
/// 判定规则（缺一不可）：
/// 1. 同一个星期几；
/// 2. 节次区间相交；
/// 3. 周次集合相交（正确处理单双周）；
/// 4. 不是同一门课（同一门课一周多次上不同时段不算冲突）。
class ConflictDetector {
  const ConflictDetector._();

  static List<Conflict> detect({
    required List<CourseSchedule> candidateSchedules,
    int? candidateCourseId,
    required List<ScheduledEntry> existing,
  }) {
    final List<Conflict> conflicts = <Conflict>[];
    for (final CourseSchedule candidate in candidateSchedules) {
      for (final ScheduledEntry entry in existing) {
        final CourseSchedule other = entry.schedule;
        if (candidateCourseId != null && entry.course.id == candidateCourseId) {
          continue;
        }
        if (!_isConflict(candidate, other)) {
          continue;
        }
        conflicts.add(
          Conflict(
            courseId: entry.course.id,
            courseName: entry.course.name,
            schedule: other,
          ),
        );
      }
    }
    return conflicts;
  }

  /// 单条 schedule 与已有集合是否冲突。
  static bool hasConflict({
    required CourseSchedule candidate,
    int? candidateCourseId,
    required List<ScheduledEntry> existing,
  }) =>
      detect(
        candidateSchedules: <CourseSchedule>[candidate],
        candidateCourseId: candidateCourseId,
        existing: existing,
      ).isNotEmpty;

  /// 两条 schedule 本身是否互相冲突（不含"同课程"判断）。
  static bool schedulesConflict(CourseSchedule a, CourseSchedule b) {
    if (a.weekday != b.weekday) {
      return false;
    }
    if (!a.slotsOverlap(b)) {
      return false;
    }
    return a.weeksOverlap(b);
  }

  static bool _isConflict(CourseSchedule a, CourseSchedule b) =>
      schedulesConflict(a, b);
}
