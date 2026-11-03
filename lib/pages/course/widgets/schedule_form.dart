import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/models/course_schedule.dart';
import '../../../domain/models/week_type.dart';
import 'week_range_picker.dart';

/// 上课时段编辑表单，作为底部弹层内容使用。
///
/// 返回值：`Navigator.pop(context, CourseSchedule)`，取消则为 null。
class ScheduleForm extends StatefulWidget {
  const ScheduleForm({
    super.key,
    this.initial,
    required this.totalWeeks,
    required this.maxSlot,
  });

  /// 编辑已有则传入，新建传 null。
  final CourseSchedule? initial;

  /// 来自 SemesterProvider.totalWeeks。
  final int totalWeeks;

  /// 来自 TimeSlotProvider.maxSlotIndex，为 0 时回退 12。
  final int maxSlot;

  @override
  State<ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<ScheduleForm> {
  late int _weekday;
  late int _startSlot;
  late int _endSlot;
  late int _startWeek;
  late int _endWeek;
  late WeekType _weekType;

  int get _totalWeeks => widget.totalWeeks < 1 ? 1 : widget.totalWeeks;

  int get _slotCount => widget.maxSlot <= 0 ? 12 : widget.maxSlot;

  @override
  void initState() {
    super.initState();
    final CourseSchedule? initial = widget.initial;
    final int slots = _slotCount;
    final int weeks = _totalWeeks;
    _weekday = (initial?.weekday ?? DateTime.monday).clamp(1, 7).toInt();
    _startSlot = (initial?.startSlot ?? 1).clamp(1, slots).toInt();
    _endSlot = (initial?.endSlot ?? 2).clamp(_startSlot, slots).toInt();
    _startWeek = (initial?.startWeek ?? 1).clamp(1, weeks).toInt();
    _endWeek = (initial?.endWeek ?? weeks).clamp(_startWeek, weeks).toInt();
    _weekType = initial?.weekType ?? WeekType.all;
  }

  void _showTip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _submit() {
    if (_startSlot > _endSlot) {
      _showTip('起始节次不能晚于结束节次');
      return;
    }
    if (_startWeek > _endWeek) {
      _showTip('起始周不能晚于结束周');
      return;
    }
    if (_endWeek > _totalWeeks) {
      _showTip('周次超出学期总周数（$_totalWeeks 周）');
      return;
    }
    final CourseSchedule schedule = CourseSchedule(
      id: widget.initial?.id,
      courseId: widget.initial?.courseId ?? 0,
      weekday: _weekday,
      startSlot: _startSlot,
      endSlot: _endSlot,
      startWeek: _startWeek,
      endWeek: _endWeek,
      weekType: _weekType,
    );
    Navigator.of(context).pop(schedule);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<DropdownMenuItem<int>> slotItems = <DropdownMenuItem<int>>[
      for (int i = 1; i <= _slotCount; i++)
        DropdownMenuItem<int>(value: i, child: Text('第 $i 节')),
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('上课时段', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              Text('星期', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (int day = 1; day <= AppConstants.daysPerWeek; day++)
                    ChoiceChip(
                      label: Text(AppDateUtils.weekdayLabel(day)),
                      selected: _weekday == day,
                      onSelected: (bool selected) {
                        if (!selected) {
                          return;
                        }
                        setState(() => _weekday = day);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('节次', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _startSlot,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '开始节次'),
                      items: slotItems,
                      onChanged: (int? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _startSlot = value;
                          if (_endSlot < value) {
                            _endSlot = value;
                          }
                        });
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('到'),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _endSlot,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '结束节次'),
                      items: slotItems,
                      onChanged: (int? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _endSlot = value;
                          if (_startSlot > value) {
                            _startSlot = value;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              WeekRangePicker(
                startWeek: _startWeek,
                endWeek: _endWeek,
                totalWeeks: _totalWeeks,
                onChanged: (int start, int end) {
                  setState(() {
                    _startWeek = start;
                    _endWeek = end;
                  });
                },
              ),
              const SizedBox(height: 12),
              Text('单双周', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<WeekType>(
                segments: <ButtonSegment<WeekType>>[
                  for (final WeekType type in WeekType.values)
                    ButtonSegment<WeekType>(
                      value: type,
                      label: Text(type.label),
                    ),
                ],
                selected: <WeekType>{_weekType},
                onSelectionChanged: (Set<WeekType> selection) {
                  if (selection.isEmpty) {
                    return;
                  }
                  setState(() => _weekType = selection.first);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
