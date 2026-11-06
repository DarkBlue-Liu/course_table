import 'package:course_table/core/theme/app_colors.dart';
import 'package:course_table/domain/models/course_edit_seed.dart';
import 'package:course_table/domain/models/week_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('14种颜色保持原十色值及默认颜色', () {
    expect(AppColors.coursePalette.length, 14);
    expect(AppColors.coursePalette.toSet().length, 14);
    expect(AppColors.coursePalette.take(10), <int>[
      0xFF4C6FFF,
      0xFF00A8A8,
      0xFF3FA34D,
      0xFFB8860B,
      0xFFE07A1F,
      0xFFD64545,
      0xFFC2417A,
      0xFF8E5BD9,
      0xFF6B7A8F,
      0xFF5C4033,
    ]);
    expect(AppColors.defaultCourseColor, 0xFF4C6FFF);
  });
  test('快捷预填位置可用且周次仍为1到学期末和全部周', () {
    final schedule = const CourseEditSeed(weekday: 3, slotIndex: 5)
        .schedule(totalWeeks: 18, maxSlot: 12);
    expect(schedule.weekday, 3);
    expect(schedule.startSlot, 5);
    expect(schedule.endSlot, 5);
    expect(schedule.startWeek, 1);
    expect(schedule.endWeek, 18);
    expect(schedule.weekType, WeekType.all);
  });
}
