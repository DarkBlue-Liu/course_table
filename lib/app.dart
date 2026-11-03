import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/routes.dart';
import 'core/theme/app_theme.dart';
import 'domain/models/course.dart';
import 'pages/course/course_detail_page.dart';
import 'pages/course/course_edit_page.dart';
import 'pages/home/home_page.dart';
import 'pages/onboarding/onboarding_page.dart';
import 'pages/settings/backup_page.dart';
import 'pages/settings/reminder_settings_page.dart';
import 'pages/settings/semester_settings_page.dart';
import 'pages/settings/time_slot_settings_page.dart';
import 'pages/splash/splash_page.dart';
import 'providers/course_list_provider.dart';
import 'providers/semester_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/time_slot_provider.dart';
import 'providers/week_provider.dart';
import 'services/backup_service.dart';
import 'services/reminder_service.dart';

/// 应用装配层：只负责 Provider 注入、主题、路由表。不放业务逻辑。
class CourseTableApp extends StatelessWidget {
  const CourseTableApp({
    super.key,
    required this.settingsProvider,
    required this.semesterProvider,
    required this.timeSlotProvider,
    required this.courseListProvider,
    required this.backupService,
    required this.reminderService,
  });

  final SettingsProvider settingsProvider;
  final SemesterProvider semesterProvider;
  final TimeSlotProvider timeSlotProvider;
  final CourseListProvider courseListProvider;
  final BackupService backupService;
  final ReminderService reminderService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<SemesterProvider>.value(value: semesterProvider),
        ChangeNotifierProvider<TimeSlotProvider>.value(value: timeSlotProvider),
        ChangeNotifierProvider<CourseListProvider>.value(
            value: courseListProvider),
        ChangeNotifierProvider<WeekProvider>(
          create: (BuildContext context) =>
              WeekProvider(context.read<SemesterProvider>()),
        ),
        Provider<BackupService>.value(value: backupService),
        Provider<ReminderService>.value(value: reminderService),
      ],
      child: Consumer<SettingsProvider>(
        builder: (BuildContext context, SettingsProvider settings, Widget? _) {
          return MaterialApp(
            title: '课程表',
            locale: const Locale('zh', 'CN'),
            supportedLocales: const <Locale>[Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            initialRoute: RouteNames.splash,
            onGenerateRoute: _onGenerateRoute,
          );
        },
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return MaterialPageRoute<Object?>(
          builder: (_) => const SplashPage(),
        );
      case RouteNames.onboarding:
        return MaterialPageRoute<Object?>(
          builder: (_) => const OnboardingPage(),
        );
      case RouteNames.home:
        return MaterialPageRoute<Object?>(
          builder: (_) => const HomePage(),
        );
      case RouteNames.courseEdit:
        final Object? args = settings.arguments;
        final Course? course = args is Course ? args : null;
        return MaterialPageRoute<Object?>(
          builder: (_) => CourseEditPage(course: course),
        );
      case RouteNames.courseDetail:
        final Object? args = settings.arguments;
        if (args is! int) {
          return null;
        }
        return MaterialPageRoute<Object?>(
          builder: (_) => CourseDetailPage(courseId: args),
        );
      case RouteNames.semesterSettings:
        return MaterialPageRoute<Object?>(
          builder: (_) => const SemesterSettingsPage(),
        );
      case RouteNames.timeSlotSettings:
        return MaterialPageRoute<Object?>(
          builder: (_) => const TimeSlotSettingsPage(),
        );
      case RouteNames.reminderSettings:
        return MaterialPageRoute<Object?>(
          builder: (_) => const ReminderSettingsPage(),
        );
      case RouteNames.backup:
        return MaterialPageRoute<Object?>(
          builder: (_) => const BackupPage(),
        );
      default:
        return null;
    }
  }
}
