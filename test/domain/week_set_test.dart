import 'package:course_table/domain/models/week_type.dart';
import 'package:course_table/domain/rules/week_set.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeekSet.of', () {
    test('全周：1-16 共 16 周', () {
      final Set<int> weeks = WeekSet.of(
        startWeek: 1,
        endWeek: 16,
        weekType: WeekType.all,
      );
      expect(weeks.length, 16);
      expect(weeks.first, 1);
      expect(weeks.last, 16);
    });

    test('单周：1-16 取奇数周', () {
      final Set<int> weeks = WeekSet.of(
        startWeek: 1,
        endWeek: 16,
        weekType: WeekType.odd,
      );
      expect(weeks, <int>{1, 3, 5, 7, 9, 11, 13, 15});
    });

    test('双周：1-16 取偶数周', () {
      final Set<int> weeks = WeekSet.of(
        startWeek: 1,
        endWeek: 16,
        weekType: WeekType.even,
      );
      expect(weeks, <int>{2, 4, 6, 8, 10, 12, 14, 16});
    });

    test('双周 + 起始周为奇数：第一周不生效，从第 2 周开始', () {
      final Set<int> weeks = WeekSet.of(
        startWeek: 1,
        endWeek: 5,
        weekType: WeekType.even,
      );
      expect(weeks, <int>{2, 4});
    });

    test('单周 + 起始周为偶数：从第 3 周开始', () {
      final Set<int> weeks = WeekSet.of(
        startWeek: 2,
        endWeek: 9,
        weekType: WeekType.odd,
      );
      expect(weeks, <int>{3, 5, 7, 9});
    });

    test('起止周颠倒返回空集', () {
      expect(
        WeekSet.of(startWeek: 9, endWeek: 2, weekType: WeekType.all),
        isEmpty,
      );
    });
  });

  group('WeekSet.intersects（单双周组合）', () {
    test('全周 vs 全周：有交集', () {
      expect(
        WeekSet.intersects(
          startWeekA: 1,
          endWeekA: 16,
          weekTypeA: WeekType.all,
          startWeekB: 8,
          endWeekB: 20,
          weekTypeB: WeekType.all,
        ),
        isTrue,
      );
    });

    test('全周 vs 全周：区间不相交', () {
      expect(
        WeekSet.intersects(
          startWeekA: 1,
          endWeekA: 8,
          weekTypeA: WeekType.all,
          startWeekB: 9,
          endWeekB: 20,
          weekTypeB: WeekType.all,
        ),
        isFalse,
      );
    });

    test('单周 vs 双周：永不相交', () {
      expect(
        WeekSet.intersects(
          startWeekA: 1,
          endWeekA: 16,
          weekTypeA: WeekType.odd,
          startWeekB: 1,
          endWeekB: 16,
          weekTypeB: WeekType.even,
        ),
        isFalse,
      );
    });

    test('单周 vs 单周：有交集', () {
      expect(
        WeekSet.intersects(
          startWeekA: 1,
          endWeekA: 9,
          weekTypeA: WeekType.odd,
          startWeekB: 5,
          endWeekB: 15,
          weekTypeB: WeekType.odd,
        ),
        isTrue,
      );
    });

    test('双周 vs 双周：有交集', () {
      expect(
        WeekSet.intersects(
          startWeekA: 1,
          endWeekA: 9,
          weekTypeA: WeekType.even,
          startWeekB: 4,
          endWeekB: 16,
          weekTypeB: WeekType.even,
        ),
        isTrue,
      );
    });

    test('全周 vs 双周：区间里没有偶数周则不相交', () {
      expect(
        WeekSet.intersects(
          startWeekA: 3,
          endWeekA: 3,
          weekTypeA: WeekType.all,
          startWeekB: 1,
          endWeekB: 16,
          weekTypeB: WeekType.even,
        ),
        isFalse,
      );
    });
  });

  group('WeekSet.contains', () {
    test('单双周与范围同时判断', () {
      expect(
        WeekSet.contains(
          week: 7,
          startWeek: 1,
          endWeek: 16,
          weekType: WeekType.odd,
        ),
        isTrue,
      );
      expect(
        WeekSet.contains(
          week: 8,
          startWeek: 1,
          endWeek: 16,
          weekType: WeekType.odd,
        ),
        isFalse,
      );
      expect(
        WeekSet.contains(
          week: 17,
          startWeek: 1,
          endWeek: 16,
          weekType: WeekType.odd,
        ),
        isFalse,
      );
    });
  });
}
