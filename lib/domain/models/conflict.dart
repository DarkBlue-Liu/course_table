import '../../core/utils/date_utils.dart';
import 'course_schedule.dart';
import 'week_type.dart';

/// 冲突检测结果。纯数据，不含 Widget、不弹窗。
class Conflict {
  const Conflict({
    required this.courseId,
    required this.courseName,
    required this.schedule,
  });

  /// 与之冲突的「已有课程」id。
  final int? courseId;
  final String courseName;
  final CourseSchedule schedule;

  String get dayText => AppDateUtils.weekdayLabel(schedule.weekday);

  String get slotText => schedule.startSlot == schedule.endSlot
      ? '第${schedule.startSlot}节'
      : '第${schedule.startSlot}-${schedule.endSlot}节';

  String get weekText => schedule.weekType == WeekType.all
      ? '第${schedule.startWeek}-${schedule.endWeek}周'
      : '第${schedule.startWeek}-${schedule.endWeek}周(${schedule.weekType.label})';

  /// 「高等数学 · 周一 第3-4节 · 第1-16周」
  String get description => '$courseName · $dayText $slotText · $weekText';

  @override
  String toString() => 'Conflict($description)';
}
