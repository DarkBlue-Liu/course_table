import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/view_models/week_grid_item.dart';

/// 周视图里的课程块：左侧色条 + 课程名 + 地点。
///
/// 位置与尺寸由 TimetableGrid 通过 Positioned 决定，这里只负责内容与样式。
class CourseBlock extends StatelessWidget {
  const CourseBlock({
    super.key,
    required this.item,
    required this.onTap,
  });

  final WeekGridItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color barColor = AppColors.toColor(item.colorValue);
    final Color textColor = _readableTextColor(scheme, item.colorValue);

    return Material(
      color: AppColors.blockBackground(item.colorValue, scheme.brightness),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(width: 3, color: barColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (item.location.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        item.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.8),
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 课程色直接当文字色时，在浅色/深色底上对比度都不够，
  /// 这里按主题亮度把基色压暗或提亮，保证可读性。
  static Color _readableTextColor(ColorScheme scheme, int colorValue) {
    final Color base = AppColors.toColor(colorValue);
    return scheme.brightness == Brightness.dark
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.72), base)
        : Color.alphaBlend(Colors.black.withValues(alpha: 0.55), base);
  }
}
