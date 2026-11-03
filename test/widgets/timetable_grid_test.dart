import 'package:course_table/domain/models/time_slot.dart';
import 'package:course_table/domain/view_models/week_grid_item.dart';
import 'package:course_table/pages/timetable/widgets/timetable_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('空白格单击不添加，双击按星期和节次添加一次', (tester) async {
    final calls = <(int, int)>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TimetableGrid(
      week: 1,
      items: const [],
      timeSlots: const [
        TimeSlot(slotIndex: 1, startMinute: 480, endMinute: 525),
        TimeSlot(slotIndex: 2, startMinute: 535, endMinute: 580)
      ],
      firstWeekMonday: DateTime(2026, 11, 2),
      isCurrentWeek: false,
      onCourseTap: (_) {},
      onEmptyTap: (day, slot) => calls.add((day, slot)),
    ))));
    // 800px 视口：左轴 46px，左右各 12px；选择周三第二节。
    const position =
        Offset(12 + 46 + (800 - 24 - 46) / 7 * 2.5, 8 + 44 + 56 * 1.5);
    await tester.tapAt(position);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(calls, isEmpty);
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tapAt(position);
    await tester.pumpAndSettle();
    expect(calls, [(3, 2)]);
  });

  testWidgets('课程单击打开详情，双击课程区域不会新增', (tester) async {
    int opened = 0;
    int added = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TimetableGrid(
      week: 1,
      items: const [
        WeekGridItem(
            courseId: 1,
            name: '数学',
            location: '',
            colorValue: 0xFF4C6FFF,
            weekday: 1,
            startSlot: 1,
            endSlot: 2)
      ],
      timeSlots: const [
        TimeSlot(slotIndex: 1, startMinute: 480, endMinute: 525),
        TimeSlot(slotIndex: 2, startMinute: 535, endMinute: 580)
      ],
      firstWeekMonday: DateTime(2026, 11, 2),
      isCurrentWeek: false,
      onCourseTap: (_) => opened++,
      onEmptyTap: (day, slot) => added++,
    ))));
    await tester.tap(find.text('数学'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(opened, 1);
    await tester.tap(find.text('数学'));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tap(find.text('数学'));
    await tester.pumpAndSettle();
    expect(added, 0);
  });
}
