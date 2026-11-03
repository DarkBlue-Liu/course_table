import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/models/time_slot.dart';
import '../../../domain/rules/week_calculator.dart';
import '../../../domain/view_models/week_grid_item.dart';
import 'course_block.dart';
import 'time_axis.dart';

/// 周视图网格：左侧节次轴 + 7 天等宽列，课程块用 Stack + Positioned 精确定位。
///
/// 不用 GridView：课程块需要跨节次、同格重叠分列，只能用固定高度 Stack。
class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.week,
    required this.items,
    required this.timeSlots,
    required this.firstWeekMonday,
    required this.isCurrentWeek,
    required this.onCourseTap,
    required this.onEmptyTap,
    this.onTimeSlotTap,
  });

  /// 每节固定行高。
  static const double rowHeight = 56;

  /// 顶部星期表头高度。
  static const double headerHeight = 44;

  /// 没有任何节次配置时的兜底行数。
  static const int fallbackSlotCount = 8;

  final int week;
  final List<WeekGridItem> items;
  final List<TimeSlot> timeSlots;

  /// 第 1 周周一；为空时不展示日期。
  final DateTime? firstWeekMonday;

  /// 当前展示的周是否为「今天所在的周」，用于高亮今天那一列。
  final bool isCurrentWeek;

  final ValueChanged<WeekGridItem> onCourseTap;
  final ValueChanged<TimeSlot>? onTimeSlotTap;
  final void Function(int weekday, int slotIndex) onEmptyTap;

  int get _slotCount =>
      timeSlots.isEmpty ? fallbackSlotCount : timeSlots.length;

  @override
  Widget build(BuildContext context) {
    final int slotCount = _slotCount;
    final double gridHeight = slotCount * rowHeight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(context),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TimeAxis(
                slots: timeSlots,
                slotCount: slotCount,
                rowHeight: rowHeight,
                onSlotTap: onTimeSlotTap,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double columnWidth =
                        constraints.maxWidth / AppConstants.daysPerWeek;
                    return _buildGridBody(
                      context,
                      columnWidth: columnWidth,
                      gridHeight: gridHeight,
                      slotCount: slotCount,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int todayWeekday = DateTime.now().weekday;
    final List<Widget> cells = <Widget>[];

    for (int i = 0; i < AppConstants.daysPerWeek; i++) {
      final int weekday = i + 1;
      final bool isToday = isCurrentWeek && weekday == todayWeekday;
      final Color labelColor =
          isToday ? scheme.primary : scheme.onSurfaceVariant;
      final DateTime? date = _dateOf(weekday);

      cells.add(
        Expanded(
          child: SizedBox(
            height: headerHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      AppDateUtils.weekdayLabel(weekday),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                    if (isToday) ...<Widget>[
                      const SizedBox(width: 3),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                if (date != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('M/d').format(date),
                    style: TextStyle(
                      fontSize: 10,
                      color: isToday
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        const SizedBox(width: TimeAxis.width),
        Expanded(
          child: Row(children: cells),
        ),
      ],
    );
  }

  Widget _buildGridBody(
    BuildContext context, {
    required double columnWidth,
    required double gridHeight,
    required int slotCount,
  }) {
    final Color lineColor =
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3);

    Offset? doubleTapPosition;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (TapDownDetails details) {
        doubleTapPosition = details.localPosition;
      },
      onDoubleTap: () {
        final Offset? position = doubleTapPosition;
        if (position == null) return;
        final int weekdayIndex = (position.dx / columnWidth)
            .floor()
            .clamp(0, AppConstants.daysPerWeek - 1)
            .toInt();
        final int slotIndex =
            (position.dy / rowHeight).floor().clamp(0, slotCount - 1).toInt();
        if (items.any((WeekGridItem item) =>
            item.weekday == weekdayIndex + 1 &&
            slotIndex + 1 >= item.startSlot &&
            slotIndex + 1 <= item.endSlot)) {
          return;
        }
        onEmptyTap(weekdayIndex + 1, slotIndex + 1);
      },
      child: SizedBox(
        height: gridHeight,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _GridLinesPainter(
                  rowCount: slotCount,
                  columnCount: AppConstants.daysPerWeek,
                  rowHeight: rowHeight,
                  color: lineColor,
                ),
              ),
            ),
            ..._buildBlocks(columnWidth),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBlocks(double columnWidth) {
    final List<Widget> blocks = <Widget>[];
    for (final WeekGridItem item in items) {
      final int weekdayIndex = item.weekday - 1;
      if (weekdayIndex < 0 || weekdayIndex >= AppConstants.daysPerWeek) {
        continue;
      }
      final int laneCount = item.laneCount < 1 ? 1 : item.laneCount;
      final int lane = item.lane.clamp(0, laneCount - 1).toInt();
      final double left =
          weekdayIndex * columnWidth + lane / laneCount * columnWidth;
      final double width = columnWidth / laneCount - 2;
      final double height = item.slotSpan * rowHeight - 2;
      if (width <= 0 || height <= 0) {
        continue;
      }
      blocks.add(
        Positioned(
          top: (item.startSlot - 1) * rowHeight,
          left: left,
          width: width,
          height: height,
          child: CourseBlock(
            item: item,
            onTap: () => onCourseTap(item),
          ),
        ),
      );
    }
    return blocks;
  }

  DateTime? _dateOf(int weekday) {
    final DateTime? monday = firstWeekMonday;
    if (monday == null) {
      return null;
    }
    return WeekCalculator.dateOf(
      firstWeekMonday: monday,
      week: week,
      weekday: weekday,
    );
  }
}

/// 只画网格线：每节一条横线，每天一条竖线。
class _GridLinesPainter extends CustomPainter {
  const _GridLinesPainter({
    required this.rowCount,
    required this.columnCount,
    required this.rowHeight,
    required this.color,
  });

  final int rowCount;
  final int columnCount;
  final double rowHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    for (int row = 0; row <= rowCount; row++) {
      final double y = row * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final double columnWidth = size.width / columnCount;
    for (int column = 0; column <= columnCount; column++) {
      final double x = column * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridLinesPainter oldDelegate) {
    return oldDelegate.rowCount != rowCount ||
        oldDelegate.columnCount != columnCount ||
        oldDelegate.rowHeight != rowHeight ||
        oldDelegate.color != color;
  }
}
