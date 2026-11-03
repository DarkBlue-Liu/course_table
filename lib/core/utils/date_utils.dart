/// 日期工具：所有计算都在「仅日期」上进行，避免时区/夏令时把跨天算错。
class AppDateUtils {
  const AppDateUtils._();

  static const List<String> weekdayLabels = <String>[
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  /// 去掉时分秒，只保留年月日。
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// 统一转成 UTC 的「日期零点」，只用于做日期差，不用于展示。
  static DateTime _utcDateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  /// 两个日期相差的天数（b - a），忽略时分秒与夏令时。
  static int daysBetween(DateTime a, DateTime b) =>
      _utcDateOnly(b).difference(_utcDateOnly(a)).inDays;

  /// 所在周的周一（周一为一周第一天）。
  static DateTime mondayOf(DateTime value) {
    final DateTime day = dateOnly(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// 给日期加天数，按日历加，不受夏令时影响。
  static DateTime addDays(DateTime value, int days) {
    final DateTime day = dateOnly(value);
    return DateTime(day.year, day.month, day.day + days);
  }

  /// yyyy-MM-dd，入库存库格式。
  static String toIsoDate(DateTime value) {
    final DateTime day = dateOnly(value);
    final String month = day.month.toString().padLeft(2, '0');
    final String date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  /// 解析 yyyy-MM-dd。
  static DateTime parseIsoDate(String value) {
    final List<String> parts = value.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// 2026年3月2日
  static String toChineseDate(DateTime value) =>
      '${value.year}年${value.month}月${value.day}日';

  /// 3月2日
  static String toChineseMonthDay(DateTime value) =>
      '${value.month}月${value.day}日';

  /// 周一 .. 周日；越界安全返回空串。
  static String weekdayLabel(int weekday) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      return '';
    }
    return weekdayLabels[weekday - 1];
  }

  /// 今天是否落在 [start, end] 区间（含端点，仅比日期）。
  static bool isBetween(DateTime target, DateTime start, DateTime end) {
    final int a = daysBetween(start, target);
    final int b = daysBetween(start, end);
    return a >= 0 && a <= b;
  }
}
