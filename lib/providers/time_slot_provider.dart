import 'package:flutter/foundation.dart';

import '../core/utils/logger.dart';
import '../domain/models/time_slot.dart';
import '../repositories/time_slot_repository.dart';

/// 节次时间表状态。
class TimeSlotProvider extends ChangeNotifier {
  TimeSlotProvider({
    required TimeSlotRepository repository,
    this.onChanged,
  }) : _repository = repository;

  final TimeSlotRepository _repository;

  /// 节次表变化后回调（用于重排通知与刷新网格），由 main.dart 注入。
  Future<void> Function()? onChanged;

  List<TimeSlot> _slots = <TimeSlot>[];
  bool _loading = true;

  List<TimeSlot> get slots => List<TimeSlot>.unmodifiable(_slots);

  bool get isLoading => _loading;

  int get slotCount => _slots.length;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _slots = await _repository.getAll();
    } catch (error, stackTrace) {
      Logger.error('读取节次表失败', error, stackTrace);
      _slots = <TimeSlot>[];
    }
    _loading = false;
    notifyListeners();
  }

  TimeSlot? slotOf(int slotIndex) {
    for (final TimeSlot slot in _slots) {
      if (slot.slotIndex == slotIndex) {
        return slot;
      }
    }
    return null;
  }

  int get maxSlotIndex => _slots.isEmpty
      ? 0
      : _slots
          .map((TimeSlot s) => s.slotIndex)
          .reduce((int a, int b) => a > b ? a : b);

  /// 整表保存（设置页）。
  Future<void> replaceAll(List<TimeSlot> slots) async {
    final List<TimeSlot> normalized = <TimeSlot>[];
    for (int i = 0; i < slots.length; i++) {
      final TimeSlot slot = slots[i];
      normalized.add(slot.copyWith(slotIndex: i + 1));
    }
    await _repository.replaceAll(normalized);
    _slots = normalized;
    notifyListeners();
    await onChanged?.call();
  }
}
