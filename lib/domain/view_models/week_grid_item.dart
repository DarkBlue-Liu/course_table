/// 周视图的渲染块（视图模型，不是持久化实体）。
///
/// 由 WeekGridBuilder 从「课程 + 时段 + 当前周」算出来，
/// 只带渲染需要的字段：格位坐标 + 同格重叠时的列信息（lane / laneCount）。
class WeekGridItem {
  const WeekGridItem({
    required this.courseId,
    required this.name,
    required this.location,
    required this.colorValue,
    required this.weekday,
    required this.startSlot,
    required this.endSlot,
    this.lane = 0,
    this.laneCount = 1,
  });

  final int? courseId;
  final String name;
  final String location;
  final int colorValue;

  /// 1 = 周一 ... 7 = 周日。
  final int weekday;
  final int startSlot;
  final int endSlot;

  /// 同一天同一时段重叠时的列序号（从 0 开始）。
  final int lane;

  /// 该重叠簇一共几列，用于等分宽度。
  final int laneCount;

  int get slotSpan => endSlot - startSlot + 1;

  WeekGridItem copyWith({
    int? lane,
    int? laneCount,
  }) {
    return WeekGridItem(
      courseId: courseId,
      name: name,
      location: location,
      colorValue: colorValue,
      weekday: weekday,
      startSlot: startSlot,
      endSlot: endSlot,
      lane: lane ?? this.lane,
      laneCount: laneCount ?? this.laneCount,
    );
  }

  @override
  String toString() =>
      'WeekGridItem($name, day=$weekday, slots=$startSlot-$endSlot, lane=$lane/$laneCount)';
}
