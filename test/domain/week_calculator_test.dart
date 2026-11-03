import 'package:course_table/domain/rules/week_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('按开学与放假日期推算周数', () {
    test('周一放假不增加教学周', () {
      expect(
          WeekCalculator.inferTotalWeeks(
              startDate: DateTime(2026, 9, 2),
              holidayStartDate: DateTime(2026, 9, 14)),
          2);
    });
    test('不足一周也计为一周', () {
      expect(
          WeekCalculator.inferTotalWeeks(
              startDate: DateTime(2026, 9, 2),
              holidayStartDate: DateTime(2026, 9, 3)),
          1);
      expect(
          WeekCalculator.inferTotalWeeks(
              startDate: DateTime(2026, 9, 2),
              holidayStartDate: DateTime(2026, 9, 15)),
          3);
    });
    test('跨年日期', () {
      expect(
          WeekCalculator.inferTotalWeeks(
              startDate: DateTime(2026, 12, 30),
              holidayStartDate: DateTime(2027, 1, 11)),
          2);
    });
    test('拒绝同日与倒置日期', () {
      for (final int day in <int>[1, 2]) {
        expect(
            () => WeekCalculator.inferTotalWeeks(
                startDate: DateTime(2026, 9, 2),
                holidayStartDate: DateTime(2026, 9, day)),
            throwsArgumentError);
      }
    });
  });

  // 2026-03-02 是周一。
  final DateTime firstMonday = DateTime(2026, 3, 2);

  group('normalizeStart 归一化到周一', () {
    test('周一不变', () {
      expect(
        WeekCalculator.normalizeStart(DateTime(2026, 3, 2)),
        DateTime(2026, 3, 2),
      );
    });

    test('周三归一到本周周一', () {
      expect(
        WeekCalculator.normalizeStart(DateTime(2026, 3, 4)),
        DateTime(2026, 3, 2),
      );
    });

    test('周日归一到本周周一（不是下周）', () {
      expect(
        WeekCalculator.normalizeStart(DateTime(2026, 3, 8)),
        DateTime(2026, 3, 2),
      );
    });
  });

  group('currentWeek', () {
    test('开学当天是第 1 周', () {
      expect(
        WeekCalculator.currentWeek(
          firstWeekMonday: firstMonday,
          today: DateTime(2026, 3, 2),
          totalWeeks: 20,
        ),
        1,
      );
    });

    test('开学前的周日仍是第 1 周（钳制）', () {
      expect(
        WeekCalculator.currentWeek(
          firstWeekMonday: firstMonday,
          today: DateTime(2026, 3, 1),
          totalWeeks: 20,
        ),
        1,
      );
    });

    test('第 1 周最后一天（周日）仍是第 1 周', () {
      expect(
        WeekCalculator.currentWeek(
          firstWeekMonday: firstMonday,
          today: DateTime(2026, 3, 8),
          totalWeeks: 20,
        ),
        1,
      );
    });

    test('第 8 天进入第 2 周', () {
      expect(
        WeekCalculator.currentWeek(
          firstWeekMonday: firstMonday,
          today: DateTime(2026, 3, 9),
          totalWeeks: 20,
        ),
        2,
      );
    });

    test('跨年计算正确', () {
      final DateTime crossYearMonday = DateTime(2025, 12, 29);
      expect(
        WeekCalculator.currentWeek(
          firstWeekMonday: crossYearMonday,
          today: DateTime(2026, 1, 5),
          totalWeeks: 20,
        ),
        2,
      );
    });

    test('学期结束后钳制到总周数', () {
      expect(
        WeekCalculator.currentWeek(
          firstWeekMonday: firstMonday,
          today: DateTime(2027, 1, 1),
          totalWeeks: 20,
        ),
        20,
      );
    });

    test('时区/夏令时不影响：带时分秒的日期只按日期算', () {
      expect(
        WeekCalculator.currentWeek(
          firstWeekMonday: firstMonday,
          today: DateTime(2026, 3, 9, 23, 59, 59),
          totalWeeks: 20,
        ),
        2,
      );
      expect(
        WeekCalculator.currentWeek(
          firstWeekMonday: firstMonday,
          today: DateTime(2026, 3, 9, 0, 0, 1),
          totalWeeks: 20,
        ),
        2,
      );
    });
  });

  group('边界判断', () {
    test('开学前', () {
      expect(
        WeekCalculator.isBeforeSemester(
          firstWeekMonday: firstMonday,
          today: DateTime(2026, 3, 1),
        ),
        isTrue,
      );
      expect(
        WeekCalculator.isBeforeSemester(
          firstWeekMonday: firstMonday,
          today: DateTime(2026, 3, 2),
        ),
        isFalse,
      );
    });

    test('学期结束后', () {
      expect(
        WeekCalculator.isAfterSemester(
          firstWeekMonday: firstMonday,
          today: DateTime(2026, 7, 20),
          totalWeeks: 20,
        ),
        isTrue,
      );
    });
  });

  group('dateOf', () {
    test('第 1 周周一', () {
      expect(
        WeekCalculator.dateOf(
          firstWeekMonday: firstMonday,
          week: 1,
          weekday: 1,
        ),
        DateTime(2026, 3, 2),
      );
    });

    test('第 2 周周三是第 10 天', () {
      expect(
        WeekCalculator.dateOf(
          firstWeekMonday: firstMonday,
          week: 2,
          weekday: 3,
        ),
        DateTime(2026, 3, 11),
      );
    });

    test('第 20 周周日', () {
      expect(
        WeekCalculator.dateOf(
          firstWeekMonday: firstMonday,
          week: 20,
          weekday: 7,
        ),
        DateTime(2026, 7, 19),
      );
    });
  });
}
