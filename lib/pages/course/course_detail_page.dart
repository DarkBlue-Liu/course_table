import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/course.dart';
import '../../domain/models/course_schedule.dart';
import '../../providers/course_list_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';

/// 课程详情：展示课程信息与全部上课时段，支持编辑 / 删除。
class CourseDetailPage extends StatelessWidget {
  const CourseDetailPage({super.key, required this.courseId});

  final int courseId;

  Course? _findCourse(CourseListProvider provider) {
    for (final Course item in provider.courses) {
      if (item.id == courseId) {
        return item;
      }
    }
    return null;
  }

  Future<void> _openEdit(BuildContext context, Course course) async {
    // 路由表统一使用 MaterialPageRoute<Object?>，这里用 Object? 接结果，
    // 避免 pushNamed<bool> 在运行期把 Route<Object?> 强转成 Route<bool> 而崩溃。
    final Object? saved = await Navigator.of(context).pushNamed<Object?>(
      RouteNames.courseEdit,
      arguments: course,
    );
    if (saved == true && context.mounted) {
      await context.read<CourseListProvider>().load();
    }
  }

  Future<void> _delete(BuildContext context) async {
    final bool confirmed = await ConfirmDialog.show(
      context,
      title: '删除课程',
      message: '删除后该课程及其全部上课时段将不可恢复，确定删除吗？',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    await context.read<CourseListProvider>().deleteCourse(courseId);
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CourseListProvider provider = context.watch<CourseListProvider>();
    final Course? found = _findCourse(provider);

    if (found == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('课程详情')),
        body: EmptyState(
          icon: Icons.menu_book_outlined,
          title: '课程不存在',
          description: '这门课程可能已经被删除',
          actionLabel: '返回',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final Course course = found;
    final List<CourseSchedule> schedules = provider.schedulesOf(courseId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('课程详情'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑',
            onPressed: () => _openEdit(context, course),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.blockBackground(
                    course.colorValue,
                    theme.brightness,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.toColor(course.colorValue),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  course.name,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (course.teacher.isNotEmpty)
            _InfoRow(
              icon: Icons.person_outline,
              label: '教师',
              value: course.teacher,
            ),
          if (course.location.isNotEmpty)
            _InfoRow(
              icon: Icons.place_outlined,
              label: '地点',
              value: course.location,
            ),
          if (course.note.isNotEmpty)
            _InfoRow(
              icon: Icons.sticky_note_2_outlined,
              label: '备注',
              value: course.note,
            ),
          const SizedBox(height: 20),
          Text('上课时段', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (schedules.isEmpty)
            Text(
              '暂无上课时段',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final CourseSchedule schedule in schedules)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        schedule.summary,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// 详情页的一行「图标 + 标签 + 值」。
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
