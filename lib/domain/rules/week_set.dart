import '../models/week_type.dart';

/// 「某条 schedule 实际落在哪些周」的唯一实现。
/// 单双周一律按绝对周号判奇偶，起止周范围先裁剪。
class WeekSet {
  const WeekSet._();

  static Set<int> of({
    required int startWeek,
    required int endWeek,
    required WeekType weekType,
  }) {
    final Set<int> result = <int>{};
    if (startWeek > endWeek) {
      return result;
    }
    for (int week = startWeek; week <= endWeek; week++) {
      if (week <= 0) {
        continue;
      }
      if (weekType.matchesWeek(week)) {
        result.add(week);
      }
    }
    return result;
  }

  static bool contains({
    required int week,
    required int startWeek,
    required int endWeek,
    required WeekType weekType,
  }) {
    if (week < startWeek || week > endWeek) {
      return false;
    }
    return weekType.matchesWeek(week);
  }

  /// 两个周次区间是否存在公共周。
  static bool intersects({
    required int startWeekA,
    required int endWeekA,
    required WeekType weekTypeA,
    required int startWeekB,
    required int endWeekB,
    required WeekType weekTypeB,
  }) {
    final int from = startWeekA > startWeekB ? startWeekA : startWeekB;
    final int to = endWeekA < endWeekB ? endWeekA : endWeekB;
    if (from > to) {
      return false;
    }
    for (int week = from; week <= to; week++) {
      if (weekTypeA.matchesWeek(week) && weekTypeB.matchesWeek(week)) {
        return true;
      }
    }
    return false;
  }
}
