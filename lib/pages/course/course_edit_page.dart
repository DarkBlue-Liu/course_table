import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/conflict.dart';
import '../../domain/models/course.dart';
import '../../domain/models/course_schedule.dart';
import '../../providers/course_list_provider.dart';
import '../../providers/semester_provider.dart';
import '../../providers/time_slot_provider.dart';
import '../../services/course_service.dart';
import '../../widgets/color_picker.dart';
import '../../widgets/confirm_dialog.dart';
import 'widgets/schedule_form.dart';

/// 新建 / 编辑课程。保存成功时 `Navigator.pop(context, true)`。
class CourseEditPage extends StatefulWidget {
  const CourseEditPage({super.key, this.course});

  /// 为 null 表示新建。
  final Course? course;

  @override
  State<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends State<CourseEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _teacherController;
  late final TextEditingController _locationController;
  late final TextEditingController _noteController;

  int _colorValue = AppColors.defaultCourseColor;
  List<CourseSchedule> _schedules = <CourseSchedule>[];
  bool _saving = false;

  bool get _isEditing => widget.course != null;

  @override
  void initState() {
    super.initState();
    final Course? course = widget.course;
    _nameController = TextEditingController(text: course?.name ?? '');
    _teacherController = TextEditingController(text: course?.teacher ?? '');
    _locationController = TextEditingController(text: course?.location ?? '');
    _noteController = TextEditingController(text: course?.note ?? '');
    _colorValue = course?.colorValue ?? AppColors.defaultCourseColor;

    final int? courseId = course?.id;
    if (courseId != null) {
      // 已加载完成的数据，读一次即可，不需要监听。
      final CourseListProvider provider = context.read<CourseListProvider>();
      _schedules = List<CourseSchedule>.of(provider.schedulesOf(courseId));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showTip(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _addSchedule() async {
    final int totalWeeks = context.read<SemesterProvider>().totalWeeks;
    final int maxSlot = context.read<TimeSlotProvider>().maxSlotIndex;
    final CourseSchedule? result = await showModalBottomSheet<CourseSchedule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) => ScheduleForm(
        totalWeeks: totalWeeks,
        maxSlot: maxSlot,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    final CourseSchedule created = result;
    setState(() => _schedules.add(created));
  }

  Future<void> _editSchedule(int index) async {
    final CourseSchedule current = _schedules[index];
    final int totalWeeks = context.read<SemesterProvider>().totalWeeks;
    final int maxSlot = context.read<TimeSlotProvider>().maxSlotIndex;
    final CourseSchedule? result = await showModalBottomSheet<CourseSchedule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) => ScheduleForm(
        initial: current,
        totalWeeks: totalWeeks,
        maxSlot: maxSlot,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    final CourseSchedule updated = result;
    setState(() => _schedules[index] = updated);
  }

  Future<void> _deleteSchedule(int index) async {
    final CourseSchedule schedule = _schedules[index];
    final bool confirmed = await ConfirmDialog.show(
      context,
      title: '删除上课时段',
      message: '确定删除「${schedule.summary}」吗？',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _schedules.removeAt(index));
  }

  /// 调用 provider 保存，异常统一转成 SnackBar；失败返回 null。
  Future<SaveResult?> _saveWithFeedback({
    required Course course,
    required List<CourseSchedule> schedules,
    bool force = false,
  }) async {
    try {
      return await context.read<CourseListProvider>().saveCourse(
            course: course,
            schedules: schedules,
            force: force,
          );
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showTip('保存失败：$error');
      }
      return null;
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      _showTip('请输入课程名称');
      return;
    }
    if (_schedules.isEmpty) {
      _showTip('请至少添加一个上课时段');
      return;
    }

    final Course base = widget.course ?? const Course(name: '');
    final Course course = base.copyWith(
      name: name,
      teacher: _teacherController.text.trim(),
      location: _locationController.text.trim(),
      colorValue: _colorValue,
      note: _noteController.text.trim(),
    );
    final List<CourseSchedule> schedules = List<CourseSchedule>.of(_schedules);

    setState(() => _saving = true);
    SaveResult? result = await _saveWithFeedback(
      course: course,
      schedules: schedules,
    );
    if (result == null || !mounted) {
      return;
    }

    if (result.hasConflict) {
      final String message = result.conflicts
          .map((Conflict conflict) => conflict.description)
          .join('\n');
      final bool confirmed = await ConfirmDialog.show(
        context,
        title: '时间冲突',
        message: '以下课程与本次安排时间冲突：\n\n$message\n\n仍然要保存吗？',
        confirmLabel: '仍然保存',
      );
      if (!mounted) {
        return;
      }
      if (!confirmed) {
        setState(() => _saving = false);
        return;
      }
      result = await _saveWithFeedback(
        course: course,
        schedules: schedules,
        force: true,
      );
      if (result == null || !mounted) {
        return;
      }
    }

    if (result.isSaved) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _saving = false);
    _showTip(result.error ?? '保存失败，请检查填写内容');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑课程' : '新建课程'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          TextField(
            controller: _nameController,
            maxLength: AppConstants.maxCourseNameLength,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '课程名称',
              hintText: '必填，例如 高等数学',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _teacherController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: '教师'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: '地点'),
          ),
          const SizedBox(height: 20),
          Text('课程颜色', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          ColorPicker(
            selectedValue: _colorValue,
            onSelected: (int value) => setState(() => _colorValue = value),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _noteController,
            maxLength: AppConstants.maxNoteLength,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '备注',
              hintText: '选填，例如 需要带计算器',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('上课时段', style: theme.textTheme.titleSmall),
              Text(
                '至少 1 个',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '还没有上课时段，点击下方按钮添加',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (int index = 0; index < _schedules.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.schedule_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(_schedules[index].summary),
                onTap: () => _editSchedule(index),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: '编辑时段',
                      onPressed: () => _editSchedule(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '删除时段',
                      onPressed: () => _deleteSchedule(index),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addSchedule,
            icon: const Icon(Icons.add),
            label: const Text('添加上课时段'),
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
