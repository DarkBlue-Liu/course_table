/// 全局常量：与业务规则相关、但不属于某个具体模型的数值。
class AppConstants {
  const AppConstants._();

  /// 学期默认总周数。
  static const int defaultTotalWeeks = 20;

  /// 学期总周数允许范围。
  static const int minTotalWeeks = 1;
  static const int maxTotalWeeks = 30;

  /// 默认提前提醒分钟数。
  static const int defaultReminderLeadMinutes = 15;

  /// 提醒可选的提前分钟数。
  static const List<int> reminderLeadMinuteOptions = <int>[
    0,
    5,
    10,
    15,
    20,
    30
  ];

  /// 通知只排未来多少天，避免触发系统 pending 闹钟数量上限。
  static const int reminderScheduleWindowDays = 14;

  /// 课程名称最大长度。
  static const int maxCourseNameLength = 20;

  /// 备注最大长度。
  static const int maxNoteLength = 200;

  /// 一天 7 天，周一到周日。
  static const int daysPerWeek = 7;

  /// 课程默认颜色序号。
  static const int defaultCourseColorIndex = 0;

  /// 课程默认颜色（ARGB int，与 AppColors.coursePalette 首色一致）。
  /// 放在这里是为了让 domain 层不必 import Flutter 的 Color。
  static const int defaultCourseColorValue = 0xFF4C6FFF;
}
