import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/settings_provider.dart';
import '../../services/reminder_service.dart';

/// 上课提醒设置：开关、提前分钟数、精确闹钟权限提示。
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  /// null 表示还在查询中。
  bool? _canExact;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _checkExactPermission();
  }

  void _showTip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _checkExactPermission() async {
    try {
      final bool allowed =
          await context.read<ReminderService>().canScheduleExact();
      if (!mounted) {
        return;
      }
      setState(() => _canExact = allowed);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _canExact = false);
    }
  }

  Future<void> _onEnabledChanged(bool enabled) async {
    final SettingsProvider settings = context.read<SettingsProvider>();
    if (!enabled) {
      await settings.setReminderEnabled(false);
      return;
    }
    if (_requesting) {
      return;
    }
    setState(() => _requesting = true);
    bool granted = false;
    try {
      granted = await context.read<ReminderService>().requestPermission();
    } catch (_) {
      granted = false;
    }
    if (!mounted) {
      return;
    }
    setState(() => _requesting = false);
    if (!granted) {
      // 没有通知权限时不强行打开开关，否则用户会以为提醒生效了。
      _showTip('请在系统设置中允许通知');
      return;
    }
    await settings.setReminderEnabled(true);
    if (!mounted) {
      return;
    }
    await _checkExactPermission();
  }

  Future<void> _onLeadMinutesSelected(int minutes) async {
    await context.read<SettingsProvider>().setLeadMinutes(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final SettingsProvider settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('上课提醒')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('开启上课提醒'),
            subtitle: Text(
              settings.reminderEnabled ? '已开启' : '已关闭',
            ),
            value: settings.reminderEnabled,
            onChanged: _onEnabledChanged,
          ),
          if (_requesting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(),
            ),
          if (_canExact == false)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: scheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '未授予精确闹钟权限，提醒可能延迟',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('提前时间', style: theme.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final int minutes
                    in AppConstants.reminderLeadMinuteOptions)
                  ChoiceChip(
                    label: Text(
                      minutes == 0 ? '准时' : '提前 $minutes 分钟',
                    ),
                    selected: settings.leadMinutes == minutes,
                    onSelected: (bool selected) async {
                      if (!selected) {
                        return;
                      }
                      await _onLeadMinutesSelected(minutes);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '提醒会在上课时间前按所选分钟数送达；选择「准时」则在上课时间点提醒。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('说明', style: theme.textTheme.titleSmall),
          ),
          _tipTile(
            theme,
            Icons.event_available_outlined,
            '只排未来 ${AppConstants.reminderScheduleWindowDays} 天的提醒，'
            '更远的会在下次启动或数据变更后自动补充。',
          ),
          _tipTile(
            theme,
            Icons.battery_saver_outlined,
            '手机重启或系统省电策略可能影响提醒送达，建议允许应用后台运行。',
          ),
          _tipTile(
            theme,
            Icons.alarm_outlined,
            '精确闹钟权限被关闭时，系统可能把提醒延后到某个时间窗内送达。',
          ),
        ],
      ),
    );
  }

  Widget _tipTile(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
