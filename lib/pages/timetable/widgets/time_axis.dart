import 'package:flutter/material.dart';

import '../../../domain/models/time_slot.dart';

/// 周视图左侧节次轴：每格显示节次、上课及下课时间。
class TimeAxis extends StatelessWidget {
  const TimeAxis({
    super.key,
    required this.slots,
    required this.slotCount,
    required this.rowHeight,
    this.onSlotTap,
  });

  /// 左侧轴列宽度，网格表头与网格主体共用。
  static const double width = 46;

  final List<TimeSlot> slots;
  final int slotCount;
  final double rowHeight;
  final ValueChanged<TimeSlot>? onSlotTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle indexStyle = TextStyle(
      fontSize: 11,
      height: 1.1,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );
    final TextStyle timeStyle = TextStyle(
      fontSize: 9,
      height: 1.1,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
    );

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < slotCount; i++) {
      final int slotIndex = i + 1;
      final TimeSlot? slot = _slotOf(slotIndex);
      rows.add(
        SizedBox(
          width: width,
          height: rowHeight,
          child: Tooltip(
            message: slot == null ? '' : '点击修改第 $slotIndex 节上下课时间',
            child: InkWell(
              onTap: slot == null || onSlotTap == null
                  ? null
                  : () => onSlotTap!(slot),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(slotIndex.toString(), style: indexStyle),
                  if (slot != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(slot.startLabel,
                        style: timeStyle.copyWith(
                          color: onSlotTap == null ? null : scheme.primary,
                          decoration: onSlotTap == null
                              ? null
                              : TextDecoration.underline,
                        )),
                    const SizedBox(height: 2),
                    Text(slot.endLabel,
                        style: timeStyle.copyWith(
                          color: onSlotTap == null ? null : scheme.primary,
                          decoration: onSlotTap == null
                              ? null
                              : TextDecoration.underline,
                        )),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }

  TimeSlot? _slotOf(int slotIndex) {
    for (final TimeSlot slot in slots) {
      if (slot.slotIndex == slotIndex) {
        return slot;
      }
    }
    return null;
  }
}
