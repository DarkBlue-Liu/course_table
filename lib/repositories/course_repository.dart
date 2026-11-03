import '../domain/models/course.dart';
import '../domain/models/course_schedule.dart';
import '../domain/models/scheduled_entry.dart';

/// 课程聚合根的数据访问接口。
///
/// 为什么 CourseSchedule 不单独建 Repository：
/// Course 与 CourseSchedule 是一致性边界，必须同事务写入，
/// 一对多关系只能由聚合根（Course）统一维护。
///
/// 2.0 加云同步时，只需新增 RemoteCourseRepository / SyncingCourseRepository，
/// 上层（service / provider / page）零改动。
abstract class CourseRepository {
  /// 所有课程（按创建时间倒序）。
  Future<List<Course>> getAllCourses();

  Future<Course?> getCourse(int courseId);

  /// 某门课的所有上课时段。
  Future<List<CourseSchedule>> getSchedulesByCourse(int courseId);

  /// 所有上课时段（扁平）。
  Future<List<CourseSchedule>> getAllSchedules();

  /// 「课程 + 时段」联合列表，周视图 / 冲突检测 / 通知都吃这个。
  Future<List<ScheduledEntry>> getAllEntries();

  /// 保存课程与其全部时段，**单事务**：
  /// 新增时 insert course；更新时 update course；
  /// 时段统一「先删后批量插入」，避免增量 diff 带来的不一致。
  /// 返回课程 id。
  Future<int> saveCourseWithSchedules(
    Course course,
    List<CourseSchedule> schedules,
  );

  /// 删除课程（外键级联删除其时段）。
  Future<void> deleteCourse(int courseId);

  /// 清空全部课程与时段（备份导入用）。
  Future<void> clearAll();
}
