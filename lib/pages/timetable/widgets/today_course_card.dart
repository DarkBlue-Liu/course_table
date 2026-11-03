import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/models/time_slot.dart';
import '../../../domain/view_models/week_grid_item.dart';

/// 今日课程卡片：没课时给一行轻提示，有课时横向滚动展示课程小卡片。
class TodayCourseCard extends StatelessWidget {
  const TodayCourseCard({
    super.key,
    required this.items,
    required this.timeSlots,
    required this.onCourseTap,
  });

  /// 单张课程小卡片宽度。
  static const double itemWidth = 156;

  /// 横向滚动区域高度。
  static const double listHeight = 84;

  final List<WeekGridItem> items;
  final List<TimeSlot> timeSlots;
  final ValueChanged<WeekGridItem> onCourseTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.today_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                '今日课程',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                AppDateUtils.toChineseMonthDay(DateTime.now()),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              '今天没有课',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int index) =>
                    _buildItem(context, items[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, WeekGridItem item) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = AppColors.toColor(item.colorValue);

    return SizedBox(
      width: itemWidth,
      child: Material(
        color: AppColors.blockBackground(item.colorValue, scheme.brightness),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onCourseTap(item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _slotText(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.location.isEmpty ? '未填地点' : item.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 「第3-4节 08:00-09:40」，查不到节次时间时只显示节次。
  String _slotText(WeekGridItem item) {
    final String slotText = item.startSlot == item.endSlot
        ? '第${item.startSlot}节'
        : '第${item.startSlot}-${item.endSlot}节';
    final TimeSlot? start = _slotOf(item.startSlot);
    if (start == null) {
      return slotText;
    }
    final TimeSlot? end = _slotOf(item.endSlot);
    final String endLabel = end?.endLabel ?? start.endLabel;
    return '$slotText ${start.startLabel}-$endLabel';
  }

  TimeSlot? _slotOf(int slotIndex) {
    for (final TimeSlot slot in timeSlots) {
      if (slot.slotIndex == slotIndex) {
        return slot;
      }
    }
    return null;
  }
}
