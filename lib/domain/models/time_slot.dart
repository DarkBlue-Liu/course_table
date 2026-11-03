import '../../core/utils/time_utils.dart';

/// 某一节的上下课时间。时间用「一天中的分钟数」，不存字符串。
class TimeSlot {
  const TimeSlot({
    this.id,
    required this.slotIndex,
    required this.startMinute,
    required this.endMinute,
  });

  final int? id;

  /// 第几节，从 1 开始，全表唯一。
  final int slotIndex;
  final int startMinute;
  final int endMinute;

  String get startLabel => TimeUtils.formatMinute(startMinute);

  String get endLabel => TimeUtils.formatMinute(endMinute);

  String get rangeLabel => TimeUtils.rangeLabel(startMinute, endMinute);

  TimeSlot copyWith({
    int? id,
    int? slotIndex,
    int? startMinute,
    int? endMinute,
  }) {
    return TimeSlot(
      id: id ?? this.id,
      slotIndex: slotIndex ?? this.slotIndex,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  @override
  String toString() => 'TimeSlot($slotIndex, $rangeLabel)';
}
