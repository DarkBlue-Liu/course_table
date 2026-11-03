import 'package:course_table/providers/semester_provider.dart';
import 'package:course_table/core/constants/db_constants.dart';
import 'dart:convert';
import 'package:course_table/services/backup_service.dart';
import 'dart:io';

import 'package:course_table/core/database/app_database.dart';
import 'package:course_table/domain/models/course.dart';
import 'package:course_table/domain/models/course_schedule.dart';
import 'package:course_table/domain/models/scheduled_entry.dart';
import 'package:course_table/domain/models/semester.dart';
import 'package:course_table/domain/models/time_slot.dart';
import 'package:course_table/domain/models/week_type.dart';
import 'package:course_table/repositories/local/local_course_repository.dart';
import 'package:course_table/repositories/local/local_semester_repository.dart';
import 'package:course_table/repositories/local/local_time_slot_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Repository 测试在 PC 上跑，不依赖真机：
/// 用 sqflite_common_ffi 提供 DatabaseFactory，注入 AppDatabase 即可。
void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase database;
  late LocalCourseRepository courseRepository;
  late LocalSemesterRepository semesterRepository;
  late LocalTimeSlotRepository timeSlotRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('course_table_test_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      pathOverride: '${tempDir.path}/test.db',
    );
    courseRepository = LocalCourseRepository(database);
    semesterRepository = LocalSemesterRepository(database);
    timeSlotRepository = LocalTimeSlotRepository(database);
    await database.database; // 触发建库（建表 + 预置节次）
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('备份导入安全', () {
    late BackupService backup;
    late String original;
    setUp(() async {
      await semesterRepository.saveSemester(Semester(
        id: 1,
        firstWeekMonday: DateTime(2026, 9, 7),
        totalWeeks: 20,
      ));
      await courseRepository.saveCourseWithSchedules(
        const Course(name: '保留课程', colorValue: 0xFF4C6FFF),
        const <CourseSchedule>[
          CourseSchedule(
              weekday: 1,
              startSlot: 1,
              endSlot: 2,
              startWeek: 1,
              endWeek: 20,
              weekType: WeekType.all),
        ],
      );
      backup = BackupService(
          courseRepository: courseRepository,
          semesterRepository: semesterRepository,
          timeSlotRepository: timeSlotRepository);
      original = await backup.exportJson();
    });

    test('合法备份完整往返', () async {
      expect(await backup.importJson(original), 1);
      expect((await courseRepository.getAllCourses()).single.name, '保留课程');
      expect((await courseRepository.getAllSchedules()).single.endSlot, 2);
    });

    for (final String corruption in <String>[
      'missingScheduleField',
      'lateType',
      'invalidWeekday',
      'unknownSlot',
      'duplicateSlot',
      'invalidTime',
      'unknownWeekType',
      'missingCourses',
      'invalidSemester',
    ]) {
      test('拒绝 $corruption 且保留全部原数据', () async {
        final data = jsonDecode(original) as Map<String, dynamic>;
        final courses = data['courses'] as List<dynamic>;
        final course = courses.single as Map<String, dynamic>;
        final schedule = (course['schedules'] as List<dynamic>).single
            as Map<String, dynamic>;
        switch (corruption) {
          case 'missingScheduleField':
            schedule.remove('weekday');
          case 'lateType':
            courses.add(<String, dynamic>{'name': 42});
          case 'invalidWeekday':
            schedule['weekday'] = 8;
          case 'unknownSlot':
            schedule['endSlot'] = 99;
          case 'duplicateSlot':
            (data['timeSlots'] as List<dynamic>)[1]['slotIndex'] = 1;
          case 'invalidTime':
            (data['timeSlots'] as List<dynamic>)[0]['endMinute'] = 0;
          case 'unknownWeekType':
            schedule['weekType'] = 9;
          case 'missingCourses':
            data.remove('courses');
          case 'invalidSemester':
            data['semester']['totalWeeks'] = 0;
        }
        await expectLater(
            backup.importJson(jsonEncode(data)), throwsA(anything));
        final after =
            jsonDecode(await backup.exportJson()) as Map<String, dynamic>;
        final before = jsonDecode(original) as Map<String, dynamic>;
        after.remove('exportedAt');
        before.remove('exportedAt');
        expect(after, before);
      });
    }
  });

  test('学期日期和手动模式持久化并随备份恢复', () async {
    await semesterRepository.saveSemester(Semester(
        id: 1,
        firstWeekMonday: DateTime(2026, 8, 31),
        startDate: DateTime(2026, 9, 2),
        holidayStartDate: DateTime(2027, 1, 18),
        totalWeeks: 18,
        autoWeeks: false));
    final backup = BackupService(
        courseRepository: courseRepository,
        semesterRepository: semesterRepository,
        timeSlotRepository: timeSlotRepository);
    final content = await backup.exportJson();
    await backup.importJson(content);
    final saved = (await semesterRepository.getSemester())!;
    expect(saved.startDate, DateTime(2026, 9, 2));
    expect(saved.holidayStartDate, DateTime(2027, 1, 18));
    expect(saved.totalWeeks, 18);
    expect(saved.autoWeeks, false);
  });

  test('旧格式备份仍能导入', () async {
    await semesterRepository.saveSemester(
        Semester(id: 1, firstWeekMonday: DateTime(2026, 9, 7), totalWeeks: 20));
    final backup = BackupService(
        courseRepository: courseRepository,
        semesterRepository: semesterRepository,
        timeSlotRepository: timeSlotRepository);
    final data = jsonDecode(await backup.exportJson()) as Map<String, dynamic>;
    final semester = data['semester'] as Map<String, dynamic>;
    semester.remove('startDate');
    semester.remove('holidayStartDate');
    semester.remove('autoWeeks');
    expect(await backup.importJson(jsonEncode(data)), 0);
    expect((await semesterRepository.getSemester())!.totalWeeks, 20);
  });

  test('v1 数据库升级保留课程与学期', () async {
    final path = '${tempDir.path}/legacy.db';
    final legacy = await databaseFactoryFfi.openDatabase(path);
    for (final sql in DbConstants.createStatements) {
      final oldSql = sql
          .replaceAll('  start_date TEXT,', '')
          .replaceAll('  holiday_start_date TEXT,', '')
          .replaceAll('  auto_weeks INTEGER NOT NULL DEFAULT 1,', '');
      await legacy.execute(oldSql);
    }
    await legacy.execute(
        "INSERT INTO semester (id, first_week_monday, total_weeks, updated_at) VALUES (1, '2026-09-07', 20, '2026-09-07')");
    await legacy.execute(
        "INSERT INTO course (name, color, created_at) VALUES ('旧课程', 0, '2026-09-07')");
    await legacy.setVersion(1);
    await legacy.close();
    final upgraded =
        AppDatabase(factory: databaseFactoryFfi, pathOverride: path);
    try {
      final semester = (await LocalSemesterRepository(upgraded).getSemester())!;
      expect(semester.totalWeeks, 20);
      expect(semester.startDate, isNull);
      expect(
          (await LocalCourseRepository(upgraded).getAllCourses()).single.name,
          '旧课程');
      await LocalSemesterRepository(upgraded).saveSemester(
          semester.copyWith(holidayStartDate: DateTime(2027, 1, 25)));
      expect(
          (await LocalSemesterRepository(upgraded).getSemester())!
              .holidayStartDate,
          DateTime(2027, 1, 25));
    } finally {
      await upgraded.close();
    }
  });

  test('自动推算与手动周数可切换并重新加载', () async {
    final provider = SemesterProvider(repository: semesterRepository);
    await provider.saveSemester(
        anyDate: DateTime(2026, 9, 2),
        holidayStartDate: DateTime(2027, 1, 18),
        totalWeeks: 1,
        autoWeeks: true);
    expect(provider.totalWeeks, 20);
    await provider.updateTotalWeeks(18);
    await provider.load();
    expect(provider.totalWeeks, 18);
    expect(provider.semester!.autoWeeks, false);
    expect(provider.semester!.startDate, DateTime(2026, 9, 2));
    expect(provider.semester!.holidayStartDate, DateTime(2027, 1, 18));
    await expectLater(
        provider.saveSemester(
            anyDate: DateTime(2026, 9, 2),
            holidayStartDate: DateTime(2028, 1, 1),
            totalWeeks: 20,
            autoWeeks: true),
        throwsArgumentError);
    expect(provider.totalWeeks, 18);
    provider.dispose();
  });

  group('建库', () {
    test('预置了默认节次时间表', () async {
      final List<TimeSlot> slots = await timeSlotRepository.getAll();
      expect(slots.length, 10);
    });

    test('节次按序号升序', () async {
      final List<int> indexes = (await timeSlotRepository.getAll())
          .map((TimeSlot slot) => slot.slotIndex)
          .toList();
      expect(indexes, List<int>.generate(10, (int i) => i + 1));
    });

    test('初始没有学期', () async {
      expect(await semesterRepository.getSemester(), isNull);
    });
  });

  group('学期仓储', () {
    test('保存后可读回', () async {
      await semesterRepository.saveSemester(
        Semester(
          id: 1,
          firstWeekMonday: DateTime(2026, 3, 2),
          totalWeeks: 20,
        ),
      );
      final Semester? semester = await semesterRepository.getSemester();
      expect(semester, isNotNull);
      expect(semester!.firstWeekMonday, DateTime(2026, 3, 2));
      expect(semester.totalWeeks, 20);
    });

    test('重复保存只有一行（REPLACE）', () async {
      const int id = 1;
      await semesterRepository.saveSemester(
        Semester(
          id: id,
          firstWeekMonday: DateTime(2026, 3, 2),
          totalWeeks: 20,
        ),
      );
      await semesterRepository.saveSemester(
        Semester(
          id: id,
          firstWeekMonday: DateTime(2026, 9, 7),
          totalWeeks: 18,
        ),
      );
      final Semester? semester = await semesterRepository.getSemester();
      expect(semester!.firstWeekMonday, DateTime(2026, 9, 7));
      expect(semester.totalWeeks, 18);
    });
  });

  group('课程聚合根', () {
    test('新增课程 + 2 个时段，可整体读回', () async {
      final int courseId = await courseRepository.saveCourseWithSchedules(
        const Course(
          name: '高等数学',
          teacher: '张老师',
          location: 'A101',
          colorValue: 0xFF4C6FFF,
        ),
        <CourseSchedule>[
          const CourseSchedule(
            weekday: 1,
            startSlot: 1,
            endSlot: 2,
            startWeek: 1,
            endWeek: 16,
          ),
          const CourseSchedule(
            weekday: 3,
            startSlot: 3,
            endSlot: 4,
            startWeek: 1,
            endWeek: 16,
            weekType: WeekType.odd,
          ),
        ],
      );

      expect(courseId, greaterThan(0));
      final List<ScheduledEntry> entries =
          await courseRepository.getAllEntries();
      expect(entries.length, 2);
      expect(entries.first.course.name, '高等数学');
      expect(
        entries.map((ScheduledEntry entry) => entry.schedule.weekType).toSet(),
        <WeekType>{WeekType.all, WeekType.odd},
      );
    });

    test('更新课程时整体替换时段，不产生重复', () async {
      final int courseId = await courseRepository.saveCourseWithSchedules(
        const Course(name: '大学英语'),
        <CourseSchedule>[
          const CourseSchedule(
            weekday: 2,
            startSlot: 1,
            endSlot: 2,
            startWeek: 1,
            endWeek: 16,
          ),
        ],
      );

      await courseRepository.saveCourseWithSchedules(
        Course(id: courseId, name: '大学英语（改）'),
        <CourseSchedule>[
          const CourseSchedule(
            weekday: 4,
            startSlot: 5,
            endSlot: 6,
            startWeek: 1,
            endWeek: 8,
          ),
        ],
      );

      final List<CourseSchedule> schedules =
          await courseRepository.getSchedulesByCourse(courseId);
      expect(schedules.length, 1);
      expect(schedules.first.weekday, 4);
      final Course? course = await courseRepository.getCourse(courseId);
      expect(course?.name, '大学英语（改）');
    });

    test('删除课程级联删除时段（依赖 PRAGMA foreign_keys=ON）', () async {
      final int courseId = await courseRepository.saveCourseWithSchedules(
        const Course(name: '体育'),
        <CourseSchedule>[
          const CourseSchedule(
            weekday: 5,
            startSlot: 7,
            endSlot: 8,
            startWeek: 1,
            endWeek: 16,
          ),
        ],
      );
      expect((await courseRepository.getAllSchedules()).length, 1);
      await courseRepository.deleteCourse(courseId);
      expect(await courseRepository.getAllSchedules(), isEmpty);
    });

    test('clearAll 清空课程与时段', () async {
      await courseRepository.saveCourseWithSchedules(
        const Course(name: '物理'),
        <CourseSchedule>[
          const CourseSchedule(
            weekday: 1,
            startSlot: 1,
            endSlot: 2,
            startWeek: 1,
            endWeek: 16,
          ),
        ],
      );
      await courseRepository.clearAll();
      expect(await courseRepository.getAllCourses(), isEmpty);
      expect(await courseRepository.getAllSchedules(), isEmpty);
    });
  });

  group('节次表整表替换', () {
    test('replaceAll 后只剩新数据，且 id 自增正常', () async {
      await timeSlotRepository.replaceAll(<TimeSlot>[
        const TimeSlot(slotIndex: 1, startMinute: 480, endMinute: 525),
        const TimeSlot(slotIndex: 2, startMinute: 535, endMinute: 580),
      ]);
      final List<TimeSlot> slots = await timeSlotRepository.getAll();
      expect(slots.length, 2);
      expect(slots.first.startMinute, 480);
      expect(slots.first.startLabel, '08:00');
      expect(slots.last.rangeLabel, '08:55-09:40');
    });
  });
}
