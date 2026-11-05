import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/models/semester.dart';
import '../../providers/semester_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/time_slot_provider.dart';
import 'update_page.dart';

/// 设置 Tab 的内容页（HomePage 直接嵌入，所以自己也提供 Scaffold / AppBar）。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _pickThemeMode(BuildContext context, ThemeMode current) async {
    final ThemeMode? picked = await showDialog<ThemeMode>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          title: const Text('主题模式'),
          children: <Widget>[
            _themeOption(
              dialogContext,
              '跟随系统',
              Icons.brightness_auto_outlined,
              ThemeMode.system,
              current,
            ),
            _themeOption(
              dialogContext,
              '浅色',
              Icons.light_mode_outlined,
              ThemeMode.light,
              current,
            ),
            _themeOption(
              dialogContext,
              '深色',
              Icons.dark_mode_outlined,
              ThemeMode.dark,
              current,
            ),
          ],
        );
      },
    );
    if (picked == null || !context.mounted) {
      return;
    }
    await context.read<SettingsProvider>().setThemeMode(picked);
  }

  Widget _themeOption(
    BuildContext dialogContext,
    String label,
    IconData icon,
    ThemeMode mode,
    ThemeMode current,
  ) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(dialogContext).pop(mode),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (mode == current) const Icon(Icons.check, size: 20),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SemesterProvider semesterProvider = context.watch<SemesterProvider>();
    final SettingsProvider settingsProvider = context.watch<SettingsProvider>();
    final TimeSlotProvider timeSlotProvider = context.watch<TimeSlotProvider>();
    final Semester? semester = semesterProvider.semester;

    final String semesterSubtitle = semester == null
        ? '未设置开学日期'
        : '${AppDateUtils.toChineseDate(semester.firstWeekMonday)} 开学 · 共 ${semester.totalWeeks} 周';

    final int slotCount = timeSlotProvider.slotCount;
    final String reminderSubtitle = settingsProvider.reminderEnabled
        ? '已开启 · ${_leadLabel(settingsProvider.leadMinutes)}'
        : '已关闭';

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          _sectionTitle(context, '学期'),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('学期设置'),
            subtitle: Text(semesterSubtitle),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () =>
                Navigator.of(context).pushNamed(RouteNames.semesterSettings),
          ),
          _sectionTitle(context, '时间'),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('节次时间'),
            subtitle: Text(slotCount == 0 ? '未设置' : '共 $slotCount 节'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () =>
                Navigator.of(context).pushNamed(RouteNames.timeSlotSettings),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('上课提醒'),
            subtitle: Text(reminderSubtitle),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () =>
                Navigator.of(context).pushNamed(RouteNames.reminderSettings),
          ),
          _sectionTitle(context, '数据'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('备份与恢复'),
            subtitle: const Text('导出 / 导入本机数据'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).pushNamed(RouteNames.backup),
          ),
          _sectionTitle(context, '外观'),
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: const Text('主题模式'),
            subtitle: Text(settingsProvider.themeModeLabel),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => _pickThemeMode(context, settingsProvider.themeMode),
          ),
          _sectionTitle(context, '关于'),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('版本与更新'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (BuildContext context) => const UpdatePage(),
            )),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('数据说明'),
            subtitle: Text('所有数据只保存在本机，不会上传到服务器'),
          ),
        ],
      ),
    );
  }

  String _leadLabel(int minutes) => minutes == 0 ? '准时提醒' : '提前 $minutes 分钟提醒';
}
