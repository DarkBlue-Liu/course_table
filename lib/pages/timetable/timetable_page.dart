import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../domain/rules/week_grid_builder.dart';
import '../../domain/models/time_slot.dart';
import '../../domain/models/course_edit_seed.dart';
import '../../domain/rules/week_calculator.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/view_models/week_grid_item.dart';
import '../../providers/course_list_provider.dart';
import '../../providers/semester_provider.dart';
import '../../providers/time_slot_provider.dart';
import '../../providers/week_provider.dart';
import 'widgets/timetable_grid.dart';
import 'widgets/today_course_card.dart';
import 'widgets/week_switcher.dart';

/// 课程表主页：周次切换 + 今日课程 + 周视图网格。
///
/// 所有数据都从 Provider 读，周次/单双周过滤全部交给 [WeekGridBuilder]，
/// 页面本身不重复实现任何排课规则。
class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage>
    with WidgetsBindingObserver {
  bool _editingTime = false;
  bool _dayView = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 首帧之后再刷新，避免在 build 期间触发 notifyListeners。
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      context.read<WeekProvider>().refreshCurrentWeek();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App 从后台回到前台时可能已经跨天/跨周。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    context.read<WeekProvider>().refreshCurrentWeek();
  }

  @override
  Widget build(BuildContext context) {
    final CourseListProvider courseListProvider =
        context.watch<CourseListProvider>();
    final WeekProvider weekProvider = context.watch<WeekProvider>();
    final TimeSlotProvider timeSlotProvider = context.watch<TimeSlotProvider>();
    final SemesterProvider semesterProvider = context.watch<SemesterProvider>();

    final DateTime? firstWeekMonday =
        semesterProvider.semester?.firstWeekMonday;

    final List<WeekGridItem> weekItems = WeekGridBuilder.build(
      week: weekProvider.displayedWeek,
      entries: courseListProvider.entries,
      timeSlots: timeSlotProvider.slots,
    );
    final List<WeekGridItem> todayItems = WeekGridBuilder.buildForDay(
      week: weekProvider.currentWeek,
      weekday: DateTime.now().weekday,
      entries: courseListProvider.entries,
      timeSlots: timeSlotProvider.slots,
    );

    return Scaffold(
      appBar: AppBar(
        leading: PopupMenuButton<String>(
          tooltip: '切换周／日课表',
          icon: Icon(
              _dayView ? Icons.view_day_outlined : Icons.calendar_view_week),
          onSelected: (String mode) {
            if (mode == 'day' && !_dayView) {
              final DateTime previous = _selectedDate ?? DateTime.now();
              final bool sameWeek = firstWeekMonday != null &&
                  WeekCalculator.rawWeek(
                          firstWeekMonday: firstWeekMonday, today: previous) ==
                      weekProvider.displayedWeek;
              _selectedDate = sameWeek || firstWeekMonday == null
                  ? previous
                  : WeekCalculator.dateOf(
                      firstWeekMonday: firstWeekMonday,
                      week: weekProvider.displayedWeek,
                      weekday: previous.weekday);
            }
            setState(() => _dayView = mode == 'day');
          },
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'week', child: Text('周课表')),
            PopupMenuItem<String>(value: 'day', child: Text('日课表')),
          ],
        ),
        title: Text(_dayView ? '日课表' : '周课表'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCourseEdit,
        tooltip: '添加课程',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: _buildContent(
          weekProvider: weekProvider,
          timeSlotProvider: timeSlotProvider,
          firstWeekMonday: firstWeekMonday,
          weekItems: weekItems,
          todayItems: todayItems,
        ),
      ),
    );
  }

  Widget _buildContent({
    required WeekProvider weekProvider,
    required TimeSlotProvider timeSlotProvider,
    required DateTime? firstWeekMonday,
    required List<WeekGridItem> weekItems,
    required List<WeekGridItem> todayItems,
  }) {
    final DateTime date = _selectedDate ?? DateTime.now();
    final int dayWeek = firstWeekMonday == null
        ? 1
        : WeekCalculator.rawWeek(firstWeekMonday: firstWeekMonday, today: date);
    final List<WeekGridItem> dayItems =
        dayWeek < 1 || dayWeek > weekProvider.totalWeeks
            ? <WeekGridItem>[]
            : WeekGridBuilder.buildForDay(
                week: dayWeek,
                weekday: date.weekday,
                entries: context.read<CourseListProvider>().entries,
                timeSlots: timeSlotProvider.slots);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_dayView)
            Row(
              children: <Widget>[
                IconButton(
                    tooltip: '前一天',
                    onPressed: () => _changeDay(-1),
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                    child: TextButton(
                  onPressed: _pickDay,
                  child: Text(
                      '${AppDateUtils.toChineseDate(date)} ${AppDateUtils.weekdayLabel(date.weekday)}'),
                )),
                IconButton(
                    tooltip: '后一天',
                    onPressed: () => _changeDay(1),
                    icon: const Icon(Icons.chevron_right)),
                TextButton(
                    onPressed: () => _setDay(DateTime.now()),
                    child: const Text('今天')),
              ],
            ),
          if (_dayView && (dayWeek < 1 || dayWeek > weekProvider.totalWeeks))
            const Padding(
                padding: EdgeInsets.all(12), child: Text('所选日期不在教学周范围内')),
          if (!_dayView)
            WeekSwitcher(
              displayedWeek: weekProvider.displayedWeek,
              totalWeeks: weekProvider.totalWeeks,
              isShowingCurrentWeek: weekProvider.isShowingCurrentWeek,
              firstWeekMonday: firstWeekMonday,
              onPrevious: weekProvider.previousWeek,
              onNext: weekProvider.nextWeek,
              onGoToWeek: weekProvider.goToWeek,
              onLocateCurrent: weekProvider.locateCurrentWeek,
            ),
          if (!_dayView)
            TodayCourseCard(
              items: todayItems,
              timeSlots: timeSlotProvider.slots,
              onCourseTap: _openCourseDetail,
            ),
          TimetableGrid(
            week: _dayView ? dayWeek : weekProvider.displayedWeek,
            items: _dayView ? dayItems : weekItems,
            visibleWeekday: _dayView ? date.weekday : null,
            timeSlots: timeSlotProvider.slots,
            firstWeekMonday: firstWeekMonday,
            isCurrentWeek: _dayView
                ? AppDateUtils.daysBetween(date, DateTime.now()) == 0
                : weekProvider.isShowingCurrentWeek,
            onCourseTap: _openCourseDetail,
            onEmptyTap: _handleEmptyTap,
            onTimeSlotTap: _editTimeSlot,
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  Future<void> _editTimeSlot(TimeSlot slot) async {
    if (_editingTime) return;
    _editingTime = true;
    try {
      final TimeOfDay? start = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: slot.startMinute ~/ 60,
          minute: slot.startMinute % 60,
        ),
        helpText: '第 ${slot.slotIndex} 节 上课时间',
        cancelText: '取消',
        confirmText: '下一步',
      );
      if (start == null || !mounted) return;
      final TimeOfDay? end = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: slot.endMinute ~/ 60,
          minute: slot.endMinute % 60,
        ),
        helpText: '第 ${slot.slotIndex} 节 下课时间',
        cancelText: '取消',
        confirmText: '保存',
      );
      if (end == null || !mounted) return;
      final int startMinute = start.hour * 60 + start.minute;
      final int endMinute = end.hour * 60 + end.minute;
      if (startMinute >= endMinute) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上课时间必须早于下课时间，未保存修改')),
        );
        return;
      }
      final TimeSlotProvider provider = context.read<TimeSlotProvider>();
      final List<TimeSlot> updated = provider.slots.map((TimeSlot current) {
        return current.slotIndex == slot.slotIndex
            ? current.copyWith(startMinute: startMinute, endMinute: endMinute)
            : current;
      }).toList();
      await provider.replaceAll(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存，时间轴与提醒已更新')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    } finally {
      _editingTime = false;
    }
  }

  void _openCourseEdit() {
    Navigator.pushNamed<Object?>(context, RouteNames.courseEdit);
  }

  void _openCourseDetail(WeekGridItem item) {
    final int? courseId = item.courseId;
    if (courseId == null) {
      return;
    }
    Navigator.pushNamed<Object?>(
      context,
      RouteNames.courseDetail,
      arguments: courseId,
    );
  }

  /// 点击空白格的加号后预填位置；周次仍从第1周到学期末，全部周。
  void _handleEmptyTap(int weekday, int slotIndex) {
    Navigator.pushNamed<Object?>(context, RouteNames.courseEdit,
        arguments: CourseEditSeed(weekday: weekday, slotIndex: slotIndex));
  }

  void _setDay(DateTime date) {
    setState(() => _selectedDate = DateTime(date.year, date.month, date.day));
    final SemesterProvider semester = context.read<SemesterProvider>();
    final DateTime? monday = semester.semester?.firstWeekMonday;
    if (monday != null) {
      final int week =
          WeekCalculator.rawWeek(firstWeekMonday: monday, today: date);
      if (week >= 1 && week <= semester.totalWeeks) {
        context.read<WeekProvider>().goToWeek(week);
      }
    }
  }

  void _changeDay(int delta) {
    final DateTime date = _selectedDate ?? DateTime.now();
    _setDay(DateTime(date.year, date.month, date.day + delta));
  }

  Future<void> _pickDay() async {
    final DateTime date = _selectedDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31));
    if (picked != null && mounted) {
      _setDay(picked);
    }
  }

  Future<void> _handleRefresh() async {
    final CourseListProvider courseListProvider =
        context.read<CourseListProvider>();
    final TimeSlotProvider timeSlotProvider = context.read<TimeSlotProvider>();
    final WeekProvider weekProvider = context.read<WeekProvider>();

    await Future.wait<void>(<Future<void>>[
      courseListProvider.load(),
      timeSlotProvider.load(),
    ]);
    weekProvider.refreshCurrentWeek();
  }
}
