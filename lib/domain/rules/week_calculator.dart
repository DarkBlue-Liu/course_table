import '../../core/utils/date_utils.dart';

/// 周次计算：纯函数，不依赖 Flutter，可直接 `dart test`。
///
/// 约定：[firstWeekMonday] 是「第 1 周的周一」，因此不存"开学日期"，
/// 也不需要在算法里处理"非周一开学"和跨年。
class WeekCalculator {
  const WeekCalculator._();

  /// 把任意日期归一化为第 1 周周一。
  static DateTime normalizeStart(DateTime anyDate) =>
      AppDateUtils.mondayOf(anyDate);

  /// 放假当天不计入教学日期，不满一周仍计一周。
  static int inferTotalWeeks(
      {required DateTime startDate, required DateTime holidayStartDate}) {
    if (AppDateUtils.daysBetween(startDate, holidayStartDate) <= 0) {
      throw ArgumentError('放假日期必须晚于开学日期');
    }
    final int days =
        AppDateUtils.daysBetween(normalizeStart(startDate), holidayStartDate);
    return (days + 6) ~/ 7;
  }

  /// [today] 处于第几周。开学前钳到 1，学期结束后钳到 [totalWeeks]。
  static int currentWeek({
    required DateTime firstWeekMonday,
    required DateTime today,
    required int totalWeeks,
  }) {
    final int raw = rawWeek(firstWeekMonday: firstWeekMonday, today: today);
    return raw.clamp(1, totalWeeks).toInt();
  }

  /// 未钳制的周次：开学前会返回 <= 0。
  static int rawWeek(
      {required DateTime firstWeekMonday, required DateTime today}) {
    final int days = AppDateUtils.daysBetween(firstWeekMonday, today);
    // 向下取整除法，负数也要向下取整（-3 天属于上一周）。
    final int weekIndex = (days / 7).floor();
    return weekIndex + 1;
  }

  /// 今天是否还没开学。
  static bool isBeforeSemester({
    required DateTime firstWeekMonday,
    required DateTime today,
  }) =>
      AppDateUtils.daysBetween(firstWeekMonday, today) < 0;

  /// 今天是否已经超过学期最后一天。
  static bool isAfterSemester({
    required DateTime firstWeekMonday,
    required DateTime today,
    required int totalWeeks,
  }) =>
      AppDateUtils.daysBetween(firstWeekMonday, today) >= totalWeeks * 7;

  /// 某周某天对应的日期。[weekday] 取 1（周一）.. 7（周日）。
  static DateTime dateOf({
    required DateTime firstWeekMonday,
    required int week,
    required int weekday,
  }) {
    final int offset = (week - 1) * 7 + (weekday - 1);
    return AppDateUtils.addDays(firstWeekMonday, offset);
  }

  /// 当前日期所在周的周一。
  static DateTime mondayOfToday(DateTime today) => AppDateUtils.mondayOf(today);
}
