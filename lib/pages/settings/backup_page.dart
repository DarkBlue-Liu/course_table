import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/course_list_provider.dart';
import '../../providers/semester_provider.dart';
import '../../providers/time_slot_provider.dart';
import '../../services/backup_service.dart';
import '../../widgets/confirm_dialog.dart';

/// 备份与恢复：导出 JSON 文件 / 从剪贴板或文件路径导入。
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final TextEditingController _pathController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  void _showTip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _export() async {
    if (_busy) {
      return;
    }
    final BackupService backup = context.read<BackupService>();
    setState(() => _busy = true);
    try {
      final File file = await backup.exportToFile();
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      await _showExportedDialog(file);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showTip('导出失败：$error');
    }
  }

  Future<void> _showExportedDialog(File file) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('导出成功'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('备份文件已保存到：'),
              const SizedBox(height: 8),
              SelectableText(file.path),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Share.shareXFiles(
                  <XFile>[XFile(file.path)],
                  text: '课程表备份',
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('分享'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importFromClipboard() async {
    if (_busy) {
      return;
    }
    String? text;
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text;
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTip('导入失败：$error');
      return;
    }
    if (!mounted) {
      return;
    }
    if (text == null || text.trim().isEmpty) {
      _showTip('剪贴板中没有可用的备份内容');
      return;
    }
    final String content = text;
    final bool confirmed = await ConfirmDialog.show(
      context,
      title: '从剪贴板导入',
      message: '导入会覆盖当前全部数据（学期、节次表与课程），确定继续吗？',
      confirmLabel: '覆盖导入',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final BackupService backup = context.read<BackupService>();
    await _runImport(() => backup.importJson(content));
  }

  Future<void> _importFromPath() async {
    final String path = _pathController.text.trim();
    if (path.isEmpty) {
      _showTip('请输入备份文件的完整路径');
      return;
    }
    final bool confirmed = await ConfirmDialog.show(
      context,
      title: '从文件导入',
      message: '导入会覆盖当前全部数据（学期、节次表与课程），确定继续吗？',
      confirmLabel: '覆盖导入',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final BackupService backup = context.read<BackupService>();
    await _runImport(() => backup.importFromFile(path));
  }

  Future<void> _runImport(Future<int> Function() action) async {
    final CourseListProvider courseListProvider =
        context.read<CourseListProvider>();
    final SemesterProvider semesterProvider = context.read<SemesterProvider>();
    final TimeSlotProvider timeSlotProvider = context.read<TimeSlotProvider>();
    setState(() => _busy = true);
    try {
      final int count = await action();
      await Future.wait<void>(<Future<void>>[
        courseListProvider.load(),
        semesterProvider.load(),
        timeSlotProvider.load(),
      ]);
      await courseListProvider.syncReminders();
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showTip('导入成功，共 $count 门课程');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showTip('导入失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text('备份说明', style: theme.textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '备份内容包含学期设置、节次时间表与全部课程。'
                    '导入会覆盖当前数据，请谨慎操作。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('导出备份'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _importFromClipboard,
              icon: const Icon(Icons.content_paste_outlined),
              label: const Text('从剪贴板导入'),
            ),
          ),
          if (_busy) ...<Widget>[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 28),
          Text('高级：从文件路径导入', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _pathController,
            decoration: const InputDecoration(
              labelText: '备份文件路径',
              hintText: '/storage/emulated/0/.../course_table_backup.json',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _importFromPath,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('从文件导入'),
            ),
          ),
        ],
      ),
    );
  }
}
