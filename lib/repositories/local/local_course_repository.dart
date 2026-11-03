import 'package:sqflite/sqflite.dart';

import '../../core/constants/db_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/logger.dart';
import '../../domain/models/course.dart';
import '../../domain/models/course_schedule.dart';
import '../../domain/models/scheduled_entry.dart';
import '../course_repository.dart';
import 'mappers.dart';

/// 本地 sqflite 实现：只做 CRUD 与行 <-> 模型映射，不做业务校验。
class LocalCourseRepository implements CourseRepository {
  LocalCourseRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<Course>> getAllCourses() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DbConstants.tableCourse,
      orderBy: '${DbConstants.colCreatedAt} DESC',
    );
    return rows.map(Mappers.courseFromRow).toList();
  }

  @override
  Future<Course?> getCourse(int courseId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DbConstants.tableCourse,
      where: '${DbConstants.colId} = ?',
      whereArgs: <Object?>[courseId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Mappers.courseFromRow(rows.first);
  }

  @override
  Future<List<CourseSchedule>> getSchedulesByCourse(int courseId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DbConstants.tableCourseSchedule,
      where: '${DbConstants.colCourseId} = ?',
      whereArgs: <Object?>[courseId],
      orderBy: '${DbConstants.colWeekday}, ${DbConstants.colStartSlot}',
    );
    return rows.map(Mappers.scheduleFromRow).toList();
  }

  @override
  Future<List<CourseSchedule>> getAllSchedules() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DbConstants.tableCourseSchedule,
      orderBy: '${DbConstants.colWeekday}, ${DbConstants.colStartSlot}',
    );
    return rows.map(Mappers.scheduleFromRow).toList();
  }

  @override
  Future<List<ScheduledEntry>> getAllEntries() async {
    final List<Course> courses = await getAllCourses();
    final List<CourseSchedule> schedules = await getAllSchedules();
    final Map<int, Course> byId = <int, Course>{
      for (final Course course in courses)
        if (course.id != null) course.id!: course,
    };
    final List<ScheduledEntry> entries = <ScheduledEntry>[];
    for (final CourseSchedule schedule in schedules) {
      final Course? course = byId[schedule.courseId];
      if (course == null) {
        continue;
      }
      entries.add(ScheduledEntry(course, schedule));
    }
    return entries;
  }

  @override
  Future<int> saveCourseWithSchedules(
    Course course,
    List<CourseSchedule> schedules,
  ) async {
    final Database db = await _appDatabase.database;
    return db.transaction<int>((Transaction txn) async {
      int courseId;
      if (course.id == null) {
        courseId = await txn.insert(
          DbConstants.tableCourse,
          Mappers.courseToRow(course, includeId: false),
        );
      } else {
        courseId = course.id!;
        await txn.update(
          DbConstants.tableCourse,
          Mappers.courseToRow(course),
          where: '${DbConstants.colId} = ?',
          whereArgs: <Object?>[courseId],
        );
      }

      await txn.delete(
        DbConstants.tableCourseSchedule,
        where: '${DbConstants.colCourseId} = ?',
        whereArgs: <Object?>[courseId],
      );

      final Batch batch = txn.batch();
      for (final CourseSchedule schedule in schedules) {
        batch.insert(
          DbConstants.tableCourseSchedule,
          Mappers.scheduleToRow(schedule, courseId: courseId, includeId: false),
        );
      }
      await batch.commit(noResult: true);

      Logger.debug('保存课程 $courseId，时段 ${schedules.length} 条');
      return courseId;
    });
  }

  @override
  Future<void> deleteCourse(int courseId) async {
    final Database db = await _appDatabase.database;
    await db.delete(
      DbConstants.tableCourse,
      where: '${DbConstants.colId} = ?',
      whereArgs: <Object?>[courseId],
    );
  }

  @override
  Future<void> clearAll() async {
    final Database db = await _appDatabase.database;
    await db.transaction<void>((Transaction txn) async {
      await txn.delete(DbConstants.tableCourseSchedule);
      await txn.delete(DbConstants.tableCourse);
    });
  }
}
