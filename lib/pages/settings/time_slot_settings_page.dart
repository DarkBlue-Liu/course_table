import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/time_utils.dart';
import '../../domain/models/time_slot.dart';
import '../../providers/time_slot_provider.dart';
import '../../services/course_service.dart';

/// 节次时间设置：编辑每节的上下课时间，支持追加 / 删除最后一节。
///
/// 页面维护一份本地编辑副本，点保存才写回 TimeSlotProvider。
class TimeSlotSettingsPage extends StatefulWidget {
  const TimeSlotSettingsPage({super.key});

  @override
  State<TimeSlotSettingsPage> createState() => _TimeSlotSettingsPageState();
}

class _TimeSlotSettingsPageState extends State<TimeSlotSettingsPage> {
  /// 一节多少分钟（新增节次的默认长度）。
  static const int _classMinutes = 45;

  /// 两节之间的默认间隔分钟数。
  static const int _breakMinutes = 10;

  final List<TimeSlot> _slots = <TimeSlot>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Provider 数据在 runApp 前已加载，这里取一份可编辑副本。
    _slots.addAll(context.read<TimeSlotProvider>().slots);
  }

  void _showTip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int _safeStartMinute(int minuteOfDay) {
    if (minuteOfDay < 0) {
      return 0;
    }
    const int maxStart = TimeUtils.minutesPerDay - _classMinutes;
    return minuteOfDay > maxStart ? maxStart : minuteOfDay;
  }

  Future<void> _editSlot(int index) async {
    final TimeSlot slot = _slots[index];
    final int startSafe =
        slot.startMinute.clamp(0, TimeUtils.minutesPerDay - 1);
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: startSafe ~/ 60, minute: startSafe % 60),
      helpText: '第 ${slot.slotIndex} 节 上课时间',
    );
    if (start == null || !mounted) {
      return;
    }
    final int endSafe = slot.endMinute.clamp(0, TimeUtils.minutesPerDay - 1);
    final TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: endSafe ~/ 60, minute: endSafe % 60),
      helpText: '第 ${slot.slotIndex} 节 下课时间',
    );
    if (end == null || !mounted) {
      return;
    }
    final int startMinute = start.hour * 60 + start.minute;
    final int endMinute = end.hour * 60 + end.minute;
    if (startMinute >= endMinute) {
      _showTip('开始时间必须早于结束时间');
      return;
    }
    setState(() {
      _slots[index] = slot.copyWith(
        startMinute: startMinute,
        endMinute: endMinute,
      );
    });
  }

  void _appendSlot() {
    final int lastEnd =
        _slots.isEmpty ? 8 * 60 : _slots[_slots.length - 1].endMinute;
    final int start = _safeStartMinute(lastEnd + _breakMinutes);
    setState(() {
      _slots.add(
        TimeSlot(
          slotIndex: _slots.length + 1,
          startMinute: start,
          endMinute: start + _classMinutes,
        ),
      );
    });
  }

  void _removeLastSlot() {
    if (_slots.length <= 1) {
      _showTip('至少保留一节课');
      return;
    }
    setState(() => _slots.removeLast());
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (_slots.isEmpty) {
      _showTip('至少保留一节课');
      return;
    }
    final String? error = CourseService.validateTimeSlots(_slots);
    if (error != null) {
      _showTip(error);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<TimeSlotProvider>().replaceAll(_slots);
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      _showTip('已保存，时间轴与提醒已更新');
      Navigator.of(context).pop();
    } catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      _showTip('保存失败：$exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('节次时间')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _appendSlot,
                    icon: const Icon(Icons.add),
                    label: const Text('添加一节'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _removeLastSlot,
                    icon: const Icon(Icons.remove),
                    label: const Text('删除最后一节'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '点击某一行可分别选择上课 / 下课时间，保存后周视图与提醒会同步更新。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: _slots.isEmpty
                ? Center(
                    child: Text(
                      '还没有节次，点击「添加一节」开始设置',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _slots.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const Divider(),
                    itemBuilder: (BuildContext context, int index) {
                      final TimeSlot slot = _slots[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text('${slot.slotIndex}'),
                        ),
                        title: Text('第 ${slot.slotIndex} 节'),
                        subtitle: Text(
                          '${slot.startLabel} - ${slot.endLabel}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: '编辑时间',
                          onPressed: () => _editSlot(index),
                        ),
                        onTap: () => _editSlot(index),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
        ),
      ),
    );
  }
}
