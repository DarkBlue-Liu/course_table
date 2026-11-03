import 'package:flutter/material.dart';

/// 课程配色板。数据库里存 int（ARGB），这里负责 int <-> Color。
class AppColors {
  const AppColors._();

  /// 10 个课程可选颜色（深色模式下也保持足够对比度）。
  static const List<int> coursePalette = <int>[
    0xFF4C6FFF, // 蓝
    0xFF00A8A8, // 青
    0xFF3FA34D, // 绿
    0xFFB8860B, // 暗金
    0xFFE07A1F, // 橙
    0xFFD64545, // 红
    0xFFC2417A, // 玫红
    0xFF8E5BD9, // 紫
    0xFF6B7A8F, // 灰蓝
    0xFF5C4033, // 棕
  ];

  static int colorAt(int index) {
    if (index < 0 || index >= coursePalette.length) {
      return coursePalette.first;
    }
    return coursePalette[index];
  }

  static int get defaultCourseColor => coursePalette.first;

  static Color toColor(int value) => Color(value);

  /// 用于文字/图标：按亮度选黑或白，保证对比度。
  static Color onColor(int value) {
    final Color color = Color(value);
    return color.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
  }

  /// 卡片底色：统一降低饱和度，避免周视图太吵。
  static Color blockBackground(int value, Brightness brightness) {
    final Color color = Color(value);
    return brightness == Brightness.dark
        ? Color.alphaBlend(
            color.withValues(alpha: 0.30), const Color(0xFF1C1C1E))
        : Color.alphaBlend(color.withValues(alpha: 0.16), Colors.white);
  }
}
