import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/routes.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/models/semester.dart';
import '../../domain/rules/week_calculator.dart';
import '../../providers/semester_provider.dart';

class SemesterSettingsPage extends StatefulWidget {
  const SemesterSettingsPage({super.key, this.isOnboarding = false});
  final bool isOnboarding;

  @override
  State<SemesterSettingsPage> createState() => _SemesterSettingsPageState();
}

class _SemesterSettingsPageState extends State<SemesterSettingsPage> {
  late DateTime _start;
  late DateTime _holiday;
  late int _manualWeeks;
  late bool _autoWeeks;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Semester? semester = context.read<SemesterProvider>().semester;
    _start = semester?.startDate ??
        semester?.firstWeekMonday ??
        AppDateUtils.dateOnly(DateTime.now());
    _manualWeeks = semester?.totalWeeks ?? AppConstants.defaultTotalWeeks;
    _holiday = semester?.holidayStartDate ??
        AppDateUtils.addDays(
            WeekCalculator.normalizeStart(_start), _manualWeeks * 7);
    _autoWeeks = semester?.autoWeeks ?? true;
  }

  bool get _validDates => AppDateUtils.daysBetween(_start, _holiday) > 0;
  int get _inferred => _validDates
      ? WeekCalculator.inferTotalWeeks(
          startDate: _start, holidayStartDate: _holiday)
      : 0;
  int get _weeks => _autoWeeks ? _inferred : _manualWeeks;
  String? get _error {
    if (!_validDates) return '放假日期必须晚于开学日期';
    if (_weeks < AppConstants.minTotalWeeks ||
        _weeks > AppConstants.maxTotalWeeks) {
      return '推算为 $_weeks 周，超出 1–30 周范围，请调整日期或关闭自动计算后手动选择';
    }
    return null;
  }

  Future<void> _pickDate(bool start) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      initialDate: (start ? _start : _holiday).isAfter(DateTime(2100, 12, 31))
          ? DateTime(2100, 12, 31)
          : (start ? _start : _holiday),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: start ? '选择开学日期' : '选择放假第一天',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _holiday = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _error != null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<SemesterProvider>().saveSemester(
            anyDate: _start,
            holidayStartDate: _holiday,
            totalWeeks: _weeks,
            autoWeeks: _autoWeeks,
          );
      if (!mounted) return;
      if (widget.isOnboarding) {
        Navigator.of(context).pushNamedAndRemoveUntil(
            RouteNames.home, (Route<dynamic> route) => false);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存，周次与提醒已更新')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateTile(
      {required String title, required DateTime date, required bool start}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading:
          Icon(start ? Icons.school_outlined : Icons.beach_access_outlined),
      title: Text(title),
      subtitle: Text(
          '${AppDateUtils.toChineseDate(date)}（${AppDateUtils.weekdayLabel(date.weekday)}）'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _saving ? null : () => _pickDate(start),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime monday = WeekCalculator.normalizeStart(_start);
    return Scaffold(
      appBar: AppBar(title: Text(widget.isOnboarding ? '欢迎使用课程表' : '学期设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          if (widget.isOnboarding) ...<Widget>[
            Text('先设置一下学期', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
          ],
          _dateTile(title: '开学日期', date: _start, start: true),
          Text('第 1 周从 ${AppDateUtils.toChineseDate(monday)}（周一）开始。',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          _dateTile(title: '放假日期', date: _holiday, start: false),
          Text('选择放假第一天，计算到前一天为止；不满一周也计为一周。', style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('根据日期自动计算周数'),
            subtitle: Text(_validDates ? '按日期推算：$_inferred 周' : '请先调整开学与放假日期'),
            value: _autoWeeks,
            onChanged: _saving
                ? null
                : (bool value) => setState(() {
                      if (!value && _inferred >= 1 && _inferred <= 30) {
                        _manualWeeks = _inferred;
                      }
                      _autoWeeks = value;
                    }),
          ),
          const SizedBox(height: 12),
          if (_autoWeeks)
            InputDecorator(
              decoration: const InputDecoration(labelText: '学期总周数（自动）'),
              child: Text(_validDates ? '$_inferred 周' : '待计算'),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _manualWeeks,
              decoration: const InputDecoration(labelText: '学期总周数（手动）'),
              items: <DropdownMenuItem<int>>[
                for (int week = AppConstants.minTotalWeeks;
                    week <= AppConstants.maxTotalWeeks;
                    week++)
                  DropdownMenuItem<int>(value: week, child: Text('$week 周')),
              ],
              onChanged: _saving
                  ? null
                  : (int? value) {
                      if (value != null) setState(() => _manualWeeks = value);
                    },
            ),
          const SizedBox(height: 8),
          Text(_error ?? '支持 1–30 周。关闭自动计算可手动调整，所有修改点击保存后生效。',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: _error == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error)),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving || _error != null ? null : _save,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.isOnboarding ? '开始使用' : '保存'),
          ),
        ],
      ),
    );
  }
}
