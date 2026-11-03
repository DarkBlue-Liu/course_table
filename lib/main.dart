import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/utils/logger.dart';
import 'providers/course_list_provider.dart';
import 'providers/semester_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/time_slot_provider.dart';
import 'repositories/local/local_course_repository.dart';
import 'repositories/local/local_semester_repository.dart';
import 'repositories/local/local_time_slot_repository.dart';
import 'services/backup_service.dart';
import 'services/course_service.dart';
import 'services/reminder_service.dart';

/// 入口：初始化存储/通知/依赖，然后交给 [CourseTableApp]。
/// 这里没有 UI 逻辑，只有依赖组装。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  final AppDatabase database = AppDatabase();
  final LocalCourseRepository courseRepository =
      LocalCourseRepository(database);
  final LocalSemesterRepository semesterRepository =
      LocalSemesterRepository(database);
  final LocalTimeSlotRepository timeSlotRepository =
      LocalTimeSlotRepository(database);

  final ReminderService reminderService = ReminderService();
  await reminderService.init();

  final SettingsProvider settingsProvider = SettingsProvider(prefs);
  final SemesterProvider semesterProvider =
      SemesterProvider(repository: semesterRepository);
  final TimeSlotProvider timeSlotProvider =
      TimeSlotProvider(repository: timeSlotRepository);
  final CourseService courseService = CourseService(
    courseRepository: courseRepository,
    semesterRepository: semesterRepository,
  );
  final CourseListProvider courseListProvider = CourseListProvider(
    courseService: courseService,
    courseRepository: courseRepository,
    semesterRepository: semesterRepository,
    timeSlotRepository: timeSlotRepository,
    reminderService: reminderService,
    settingsProvider: settingsProvider,
  );
  final BackupService backupService = BackupService(
    courseRepository: courseRepository,
    semesterRepository: semesterRepository,
    timeSlotRepository: timeSlotRepository,
  );

  // 任何会影响提醒的数据变化，都统一触发一次全量重排。
  semesterProvider.onChanged = courseListProvider.syncReminders;
  timeSlotProvider.onChanged = courseListProvider.syncReminders;
  settingsProvider.onReminderSettingsChanged = courseListProvider.syncReminders;

  await Future.wait<void>(<Future<void>>[
    semesterProvider.load(),
    timeSlotProvider.load(),
    courseListProvider.load(),
  ]);

  // 权限与通知重排失败不应阻塞启动。
  try {
    if (settingsProvider.reminderEnabled) {
      await reminderService.requestPermission();
      await courseListProvider.syncReminders();
    }
  } catch (error, stackTrace) {
    Logger.error('启动时初始化提醒失败', error, stackTrace);
  }

  runApp(
    CourseTableApp(
      settingsProvider: settingsProvider,
      semesterProvider: semesterProvider,
      timeSlotProvider: timeSlotProvider,
      courseListProvider: courseListProvider,
      backupService: backupService,
      reminderService: reminderService,
    ),
  );
}
