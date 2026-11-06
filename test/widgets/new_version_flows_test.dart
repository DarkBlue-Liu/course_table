import 'package:course_table/core/constants/routes.dart';
import 'package:course_table/domain/models/course.dart';
import 'package:course_table/domain/models/course_edit_seed.dart';
import 'package:course_table/domain/models/course_schedule.dart';
import 'package:course_table/domain/models/scheduled_entry.dart';
import 'package:course_table/domain/models/semester.dart';
import 'package:course_table/domain/models/time_slot.dart';
import 'package:course_table/pages/course/course_edit_page.dart';
import 'package:course_table/pages/course/widgets/schedule_form.dart';
import 'package:course_table/pages/onboarding/onboarding_page.dart';
import 'package:course_table/pages/onboarding/tutorial_page.dart';
import 'package:course_table/pages/settings/settings_page.dart';
import 'package:course_table/pages/settings/semester_settings_page.dart';
import 'package:course_table/pages/splash/splash_page.dart';
import 'package:course_table/pages/timetable/timetable_page.dart';
import 'package:course_table/pages/timetable/widgets/timetable_grid.dart';
import 'package:course_table/providers/course_list_provider.dart';
import 'package:course_table/providers/semester_provider.dart';
import 'package:course_table/providers/settings_provider.dart';
import 'package:course_table/providers/time_slot_provider.dart';
import 'package:course_table/providers/week_provider.dart';
import 'package:course_table/repositories/semester_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SemesterStore implements SemesterRepository {
  Semester? value;
  int writes = 0;
  @override
  Future<Semester?> getSemester() async => value;
  @override
  Future<void> saveSemester(Semester semester) async {
    value = semester;
    writes++;
  }
}

class _Courses extends ChangeNotifier implements CourseListProvider {
  List<ScheduledEntry> data = <ScheduledEntry>[];
  @override
  List<ScheduledEntry> get entries => data;
  @override
  bool get isEmpty => data.isEmpty;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Slots extends ChangeNotifier implements TimeSlotProvider {
  @override
  List<TimeSlot> get slots => const <TimeSlot>[
        TimeSlot(slotIndex: 1, startMinute: 480, endMinute: 525),
        TimeSlot(slotIndex: 2, startMinute: 535, endMinute: 580),
      ];
  @override
  int get slotCount => 2;
  @override
  int get maxSlotIndex => 2;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _SemesterStore store;
  late SemesterProvider semester;
  late WeekProvider week;
  late _Courses courses;
  late _Slots slots;
  late SettingsProvider settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PrefKeys.themeMode: 'dark',
      PrefKeys.reminderEnabled: false,
      PrefKeys.reminderLeadMinutes: 30,
    });
    settings = SettingsProvider(await SharedPreferences.getInstance());
    store = _SemesterStore()
      ..value = Semester(
          id: 1,
          firstWeekMonday: DateTime(2026, 11, 2),
          totalWeeks: 20,
          startDate: DateTime(2026, 11, 4),
          holidayStartDate: DateTime(2027, 3, 1),
          autoWeeks: false);
    semester = SemesterProvider(repository: store);
    await semester.load();
    week = WeekProvider(semester)..goToWeek(1);
    courses = _Courses();
    slots = _Slots();
  });
  tearDown(() {
    week.dispose();
    semester.dispose();
    courses.dispose();
    slots.dispose();
    settings.dispose();
  });
  Widget app(Widget home) => MultiProvider(
          providers: [
            ChangeNotifierProvider<SemesterProvider>.value(value: semester),
            ChangeNotifierProvider<WeekProvider>.value(value: week),
            ChangeNotifierProvider<CourseListProvider>.value(value: courses),
            ChangeNotifierProvider<TimeSlotProvider>.value(value: slots),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ],
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: const <Locale>[Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: home,
            onGenerateRoute: (RouteSettings route) =>
                MaterialPageRoute<void>(builder: (_) {
              if (route.name == RouteNames.courseEdit) {
                return CourseEditPage(seed: route.arguments as CourseEditSeed?);
              }
              if (route.name == RouteNames.onboarding) {
                return const OnboardingPage();
              }
              return const Scaffold(body: Text('已进入主页'));
            }),
          ));

  testWidgets('空课表可选空格进入原编辑页并预填星期节次', (WidgetTester tester) async {
    await tester.pumpWidget(app(const TimetablePage()));
    await tester.pumpAndSettle();
    final Finder grid = find.byType(TimetableGrid);
    expect(grid, findsOneWidget);
    final Offset origin = tester.getTopLeft(grid);
    await tester.tapAt(origin + const Offset(12 + 46 + 20, 8 + 44 + 20));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('quick-add-course')));
    await tester.pumpAndSettle();
    final CourseEditPage editor = tester.widget(find.byType(CourseEditPage));
    expect(editor.seed!.weekday, 1);
    expect(editor.seed!.slotIndex, 1);
    await tester.scrollUntilVisible(find.byTooltip('编辑时段'), 220,
        scrollable: find
            .descendant(
                of: find.byType(CourseEditPage),
                matching: find.byType(Scrollable))
            .first);
    expect(find.byTooltip('编辑时段'), findsOneWidget);
    await tester.tap(find.byTooltip('编辑时段'));
    await tester.pumpAndSettle();
    final ScheduleForm form = tester.widget(find.byType(ScheduleForm));
    expect(form.initial!.weekday, 1);
    expect(form.initial!.startSlot, 1);
    expect(form.initial!.endWeek, 20);
    expect(store.writes, 0);
  });

  testWidgets('周日视图共用数据，日视图前后导航按实际星期过滤', (WidgetTester tester) async {
    courses.data = <ScheduledEntry>[
      for (int day = 1; day <= 7; day++)
        ScheduledEntry(
            Course(id: day, name: '测试课程$day', colorValue: 0xFF4C6FFF),
            CourseSchedule(
                weekday: day,
                startSlot: 1,
                endSlot: 1,
                startWeek: 1,
                endWeek: 20)),
    ];
    await tester.pumpWidget(app(const TimetablePage()));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TimetableGrid>(find.byType(TimetableGrid)).items.length,
        7);
    await tester.tap(find.byTooltip('切换周／日课表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日课表').last);
    await tester.pumpAndSettle();
    TimetableGrid grid = tester.widget(find.byType(TimetableGrid));
    final int selectedDay = grid.visibleWeekday!;
    expect(grid.items.single.weekday, selectedDay);
    expect(grid.week, 1);
    await tester.tap(find.byTooltip('后一天'));
    await tester.pumpAndSettle();
    grid = tester.widget(find.byType(TimetableGrid));
    expect(grid.visibleWeekday, selectedDay % 7 + 1);
    expect(grid.items.single.weekday, grid.visibleWeekday);
    // 选择学期外日期，不应误显示被钳制到首末教学周的课程。
    await tester.tap(find.textContaining('2026年').first);
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2027, 12, 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(tester.widget<TimetableGrid>(find.byType(TimetableGrid)).items,
        isEmpty);
    expect(find.text('所选日期不在教学周范围内'), findsOneWidget);
    await tester.tap(find.byTooltip('切换周／日课表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('周课表').last);
    await tester.pumpAndSettle();
    expect(
        tester.widget<TimetableGrid>(find.byType(TimetableGrid)).items.length,
        7);
    expect(store.writes, 0);
  });

  testWidgets('已有学期的老用户跳过首次教程且不写学期', (WidgetTester tester) async {
    final Semester original = store.value!;
    await tester.pumpWidget(app(const SplashPage()));
    await tester.pumpAndSettle();
    expect(find.text('已进入主页'), findsOneWidget);
    expect(find.byType(TutorialPage), findsNothing);
    expect(identical(store.value, original), true);
    expect(store.writes, 0);
  });

  testWidgets('首次用户先看教程再设置学期', (WidgetTester tester) async {
    store.value = null;
    await semester.load();
    await tester.pumpWidget(app(const SplashPage()));
    await tester.pumpAndSettle();
    expect(find.text('欢迎使用课程表'), findsOneWidget);
    await tester.tap(find.text('下一步：设置学期'));
    await tester.pumpAndSettle();
    expect(find.text('开学日期'), findsOneWidget);
    expect(store.writes, 0);
    await tester.scrollUntilVisible(find.text('开始使用'), 240,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    expect(
        store.value!.holidayStartDate!.isAfter(store.value!.startDate!), true);
    expect(find.text('已进入主页'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(const SplashPage()));
    await tester.pumpAndSettle();
    expect(find.text('已进入主页'), findsOneWidget);
    expect(find.byType(TutorialPage), findsNothing);
    expect(store.writes, 1);
  });

  testWidgets('学期日期顺序错误时禁用保存且不改原数据', (WidgetTester tester) async {
    store.value =
        store.value!.copyWith(holidayStartDate: DateTime(2026, 11, 3));
    await semester.load();
    final Semester original = store.value!;
    await tester.pumpWidget(app(const SemesterSettingsPage()));
    await tester.scrollUntilVisible(find.text('保存'), 240,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('放假日期必须晚于开学日期'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(identical(store.value, original), true);
    expect(store.writes, 0);
  });

  testWidgets('设置重看教程不覆盖已有学期和偏好', (WidgetTester tester) async {
    final Semester original = store.value!;
    await tester.pumpWidget(app(const SettingsPage()));
    await tester.scrollUntilVisible(find.text('使用教程'), 250);
    await tester.tap(find.text('使用教程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(identical(store.value, original), true);
    expect(store.writes, 0);
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.reminderEnabled, false);
    expect(settings.leadMinutes, 30);
  });
}
