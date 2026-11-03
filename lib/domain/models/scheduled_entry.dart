import 'course.dart';
import 'course_schedule.dart';

/// 一条「课程 + 上课时段」的联合视图。
/// 冲突检测、周视图构建、通知排程都吃这个结构，避免各自 join。
class ScheduledEntry {
  const ScheduledEntry(this.course, this.schedule);

  final Course course;
  final CourseSchedule schedule;

  @override
  String toString() => 'ScheduledEntry(${course.name}, ${schedule.summary})';
}
