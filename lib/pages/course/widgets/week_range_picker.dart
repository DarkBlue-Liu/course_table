import 'package:flutter/material.dart';

/// 周次范围选择器：RangeSlider + 可读文案。
///
/// 天然保证 start <= end（RangeSlider 的 values 是升序的），对外回调取整。
class WeekRangePicker extends StatelessWidget {
  const WeekRangePicker({
    super.key,
    required this.startWeek,
    required this.endWeek,
    required this.totalWeeks,
    required this.onChanged,
  });

  final int startWeek;
  final int endWeek;
  final int totalWeeks;

  /// 回调参数为取整后的起止周（含端点）。
  final void Function(int start, int end) onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int weeks = totalWeeks < 1 ? 1 : totalWeeks;
    final int start = startWeek.clamp(1, weeks).toInt();
    final int end = endWeek.clamp(start, weeks).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('周次范围', style: theme.textTheme.titleSmall),
            Text(
              '共 $weeks 周',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (weeks > 1)
          RangeSlider(
            values: RangeValues(start.toDouble(), end.toDouble()),
            min: 1,
            max: weeks.toDouble(),
            divisions: weeks - 1,
            labels: RangeLabels('第 $start 周', '第 $end 周'),
            onChanged: (RangeValues values) {
              onChanged(values.start.round(), values.end.round());
            },
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('当前学期只有 1 周，无需选择范围'),
          ),
        Text(
          '第 $start-$end 周',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
