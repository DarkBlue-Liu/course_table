import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 课程配色选择器（横向色块）。
class ColorPicker extends StatelessWidget {
  const ColorPicker({
    super.key,
    required this.selectedValue,
    required this.onSelected,
  });

  final int selectedValue;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppColors.coursePalette.map((int value) {
        final bool selected = value == selectedValue;
        return GestureDetector(
          onTap: () => onSelected(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(value),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: selected
                ? Icon(Icons.check, size: 20, color: AppColors.onColor(value))
                : null,
          ),
        );
      }).toList(),
    );
  }
}
