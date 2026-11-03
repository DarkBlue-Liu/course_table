/// 学期配置。1.0 只支持一个当前学期（表里只有一行，id 固定为 1）。
///
/// 关键约定：[firstWeekMonday] 必须是「第 1 周的周一」，
/// 用户在引导页选任意一天，入库前用 [AppDateUtils.mondayOf] 归一化。
/// 归一化之后「第几周」就退化成一次日期减法。
class Semester {
  const Semester({
    this.id,
    required this.firstWeekMonday,
    required this.totalWeeks,
    this.startDate,
    this.holidayStartDate,
    this.autoWeeks = true,
  });

  final int? id;
  final DateTime firstWeekMonday;
  final int totalWeeks;
  final DateTime? startDate;
  final DateTime? holidayStartDate;
  final bool autoWeeks;

  Semester copyWith({
    int? id,
    DateTime? firstWeekMonday,
    int? totalWeeks,
    DateTime? startDate,
    DateTime? holidayStartDate,
    bool? autoWeeks,
  }) {
    return Semester(
      id: id ?? this.id,
      firstWeekMonday: firstWeekMonday ?? this.firstWeekMonday,
      totalWeeks: totalWeeks ?? this.totalWeeks,
      startDate: startDate ?? this.startDate,
      holidayStartDate: holidayStartDate ?? this.holidayStartDate,
      autoWeeks: autoWeeks ?? this.autoWeeks,
    );
  }

  @override
  String toString() =>
      'Semester(id: $id, firstWeekMonday: ${firstWeekMonday.toIso8601String()}, totalWeeks: $totalWeeks)';
}
