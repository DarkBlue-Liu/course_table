import '../domain/models/time_slot.dart';

/// 节次时间表接口。整表替换是主要写操作（设置页保存时）。
abstract class TimeSlotRepository {
  Future<List<TimeSlot>> getAll();

  /// 整表替换（事务：先删后插）。
  Future<void> replaceAll(List<TimeSlot> slots);

  Future<void> updateSlot(TimeSlot slot);
}
