/// 时间工具：一天中的「分钟数」与可读字符串互转。
/// 数据库里时间一律存分钟数（0 点起算），不存字符串。
class TimeUtils {
  const TimeUtils._();

  static const int minutesPerDay = 24 * 60;

  /// 分钟数 -> HH:mm
  static String formatMinute(int minuteOfDay) {
    final int safe = minuteOfDay.clamp(0, minutesPerDay - 1).toInt();
    final String hour = (safe ~/ 60).toString().padLeft(2, '0');
    final String minute = (safe % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// HH:mm -> 分钟数；解析失败返回 null。
  static int? parseHhMm(String value) {
    final List<String> parts = value.trim().split(':');
    if (parts.length != 2) {
      return null;
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  /// 08:00-08:45
  static String rangeLabel(int startMinute, int endMinute) =>
      '${formatMinute(startMinute)}-${formatMinute(endMinute)}';

  /// 08:00 上课
  static String labelWithPrefix(int minuteOfDay) =>
      '${formatMinute(minuteOfDay)} 上课';

  /// 时间是否合法：开始早于结束，且都在一天之内。
  static bool isValidRange(int startMinute, int endMinute) =>
      startMinute >= 0 && endMinute <= minutesPerDay && startMinute < endMinute;
}
