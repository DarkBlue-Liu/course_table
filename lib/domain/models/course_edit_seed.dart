import 'course_schedule.dart';
import 'week_type.dart';

/// 仅用于新建页面的临时预填，不写入已有课程或改变教学周规则。
class CourseEditSeed {
  const CourseEditSeed({required this.weekday, required this.slotIndex});
  final int weekday;
  final int slotIndex;

  CourseSchedule schedule({required int totalWeeks, required int maxSlot}) {
    final int slot = slotIndex.clamp(1, maxSlot > 0 ? maxSlot : 12).toInt();
    return CourseSchedule(
      weekday: weekday.clamp(1, 7).toInt(),
      startSlot: slot,
      endSlot: slot,
      startWeek: 1,
      endWeek: totalWeeks > 0 ? totalWeeks : 1,
      weekType: WeekType.all,
    );
  }
}
