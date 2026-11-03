import '../../core/constants/db_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/models/course.dart';
import '../../domain/models/course_schedule.dart';
import '../../domain/models/semester.dart';
import '../../domain/models/time_slot.dart';
import '../../domain/models/week_type.dart';

/// 模型 <-> 数据行的唯一映射处。Repository 内部使用，不对外暴露。
class Mappers {
  const Mappers._();

  // ---------------- semester ----------------
  static Map<String, Object?> semesterToRow(Semester semester) {
    return <String, Object?>{
      DbConstants.colId: semester.id ?? 1,
      DbConstants.colFirstWeekMonday:
          AppDateUtils.toIsoDate(semester.firstWeekMonday),
      DbConstants.colTotalWeeks: semester.totalWeeks,
      DbConstants.colStartDate: semester.startDate == null
          ? null
          : AppDateUtils.toIsoDate(semester.startDate!),
      DbConstants.colHolidayStartDate: semester.holidayStartDate == null
          ? null
          : AppDateUtils.toIsoDate(semester.holidayStartDate!),
      DbConstants.colAutoWeeks: semester.autoWeeks ? 1 : 0,
      DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
    };
  }

  static Semester semesterFromRow(Map<String, Object?> row) {
    return Semester(
      id: row[DbConstants.colId] as int?,
      firstWeekMonday: AppDateUtils.parseIsoDate(
        row[DbConstants.colFirstWeekMonday] as String,
      ),
      totalWeeks: row[DbConstants.colTotalWeeks] as int,
      startDate:
          DateTime.tryParse(row[DbConstants.colStartDate] as String? ?? ''),
      holidayStartDate: DateTime.tryParse(
          row[DbConstants.colHolidayStartDate] as String? ?? ''),
      autoWeeks: row[DbConstants.colAutoWeeks] != 0,
    );
  }

  // ---------------- time_slot ----------------
  static Map<String, Object?> timeSlotToRow(TimeSlot slot,
      {bool includeId = true}) {
    return <String, Object?>{
      if (includeId && slot.id != null) DbConstants.colId: slot.id,
      DbConstants.colSlotIndex: slot.slotIndex,
      DbConstants.colStartMinute: slot.startMinute,
      DbConstants.colEndMinute: slot.endMinute,
    };
  }

  static TimeSlot timeSlotFromRow(Map<String, Object?> row) {
    return TimeSlot(
      id: row[DbConstants.colId] as int?,
      slotIndex: row[DbConstants.colSlotIndex] as int,
      startMinute: row[DbConstants.colStartMinute] as int,
      endMinute: row[DbConstants.colEndMinute] as int,
    );
  }

  // ---------------- course ----------------
  static Map<String, Object?> courseToRow(Course course,
      {bool includeId = true}) {
    return <String, Object?>{
      if (includeId && course.id != null) DbConstants.colId: course.id,
      DbConstants.colName: course.name,
      DbConstants.colTeacher: course.teacher,
      DbConstants.colLocation: course.location,
      DbConstants.colColor: course.colorValue,
      DbConstants.colNote: course.note,
      DbConstants.colCreatedAt:
          (course.createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  static Course courseFromRow(Map<String, Object?> row) {
    return Course(
      id: row[DbConstants.colId] as int?,
      name: row[DbConstants.colName] as String? ?? '',
      teacher: row[DbConstants.colTeacher] as String? ?? '',
      location: row[DbConstants.colLocation] as String? ?? '',
      colorValue: row[DbConstants.colColor] as int? ?? 0,
      note: row[DbConstants.colNote] as String? ?? '',
      createdAt:
          DateTime.tryParse(row[DbConstants.colCreatedAt] as String? ?? ''),
    );
  }

  // ---------------- course_schedule ----------------
  static Map<String, Object?> scheduleToRow(
    CourseSchedule schedule, {
    required int courseId,
    bool includeId = true,
  }) {
    return <String, Object?>{
      if (includeId && schedule.id != null) DbConstants.colId: schedule.id,
      DbConstants.colCourseId: courseId,
      DbConstants.colWeekday: schedule.weekday,
      DbConstants.colStartSlot: schedule.startSlot,
      DbConstants.colEndSlot: schedule.endSlot,
      DbConstants.colStartWeek: schedule.startWeek,
      DbConstants.colEndWeek: schedule.endWeek,
      DbConstants.colWeekType: schedule.weekType.value,
    };
  }

  static CourseSchedule scheduleFromRow(Map<String, Object?> row) {
    return CourseSchedule(
      id: row[DbConstants.colId] as int?,
      courseId: row[DbConstants.colCourseId] as int,
      weekday: row[DbConstants.colWeekday] as int,
      startSlot: row[DbConstants.colStartSlot] as int,
      endSlot: row[DbConstants.colEndSlot] as int,
      startWeek: row[DbConstants.colStartWeek] as int,
      endWeek: row[DbConstants.colEndWeek] as int,
      weekType: WeekType.fromValue(
        row[DbConstants.colWeekType] as int? ?? WeekType.all.value,
      ),
    );
  }
}
