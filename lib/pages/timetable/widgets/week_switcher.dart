import 'package:flutter/material.dart';

import '../../../core/utils/date_utils.dart';
import '../../../domain/rules/week_calculator.dart';

/// 顶部周次切换条：上一周 / 第 N 周（点开可跳任意周） / 下一周，
/// 非当前周时额外给出「回到本周」入口。
class WeekSwitcher extends StatelessWidget {
  const WeekSwitcher({
    super.key,
    required this.displayedWeek,
    required this.totalWeeks,
    required this.isShowingCurrentWeek,
    required this.firstWeekMonday,
    required this.onPrevious,
    required this.onNext,
    required this.onGoToWeek,
    required this.onLocateCurrent,
  });

  final int displayedWeek;
  final int totalWeeks;
  final bool isShowingCurrentWeek;

  /// 第 1 周周一；为空时只是不展示日期范围。
  final DateTime? firstWeekMonday;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onGoToWeek;
  final VoidCallback onLocateCurrent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? dateRange = _dateRangeText();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: onPrevious,
                tooltip: '上一周',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: PopupMenuButton<int>(
                    tooltip: '选择周次',
                    initialValue: displayedWeek,
                    onSelected: onGoToWeek,
                    itemBuilder: (BuildContext context) => _buildMenuItems(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '第 $displayedWeek 周',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                tooltip: '下一周',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (dateRange != null)
                Text(
                  dateRange,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (!isShowingCurrentWeek) ...<Widget>[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onLocateCurrent,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '回到本周',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<int>> _buildMenuItems() {
    final List<PopupMenuEntry<int>> items = <PopupMenuEntry<int>>[];
    for (int week = 1; week <= totalWeeks; week++) {
      items.add(
        PopupMenuItem<int>(
          value: week,
          child: Text('第 $week 周'),
        ),
      );
    }
    return items;
  }

  String? _dateRangeText() {
    final DateTime? monday = firstWeekMonday;
    if (monday == null) {
      return null;
    }
    final DateTime start = WeekCalculator.dateOf(
      firstWeekMonday: monday,
      week: displayedWeek,
      weekday: DateTime.monday,
    );
    final DateTime end = WeekCalculator.dateOf(
      firstWeekMonday: monday,
      week: displayedWeek,
      weekday: DateTime.sunday,
    );
    return '${AppDateUtils.toChineseMonthDay(start)} - '
        '${AppDateUtils.toChineseMonthDay(end)}';
  }
}
