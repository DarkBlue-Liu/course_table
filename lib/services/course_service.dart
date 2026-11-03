import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import '../core/utils/time_utils.dart';
import '../domain/models/conflict.dart';
import '../domain/models/course.dart';
import '../domain/models/course_schedule.dart';
import '../domain/models/semester.dart';
import '../domain/models/time_slot.dart';
import '../domain/models/scheduled_entry.dart';
import '../domain/rules/conflict_detector.dart';
import '../repositories/course_repository.dart';
import '../repositories/semester_repository.dart';

enum SaveStatus {
  /// 保存成功。
  saved,

  /// 存在冲突，未写入；UI 应弹确认框后以 force=true 重试。
  conflict,

  /// 校验不通过，未写入。
  invalid,
}

/// 保存结果。UI 只依据 status 决定下一步，不解析异常。
class SaveResult {
  const SaveResult._({
    required this.status,
    this.courseId,
    this.conflicts = const <Conflict>[],
    this.error,
  });

  factory SaveResult.saved(int courseId) => SaveResult._(
        status: SaveStatus.saved,
        courseId: courseId,
      );

  factory SaveResult.conflict(List<Conflict> conflicts) => SaveResult._(
        status: SaveStatus.conflict,
        conflicts: conflicts,
      );

  factory SaveResult.invalid(String message) => SaveResult._(
        status: SaveStatus.invalid,
        error: message,
      );

  final SaveStatus status;
  final int? courseId;
  final List<Conflict> conflicts;
  final String? error;

  bool get isSaved => status == SaveStatus.saved;

  bool get hasConflict => status == SaveStatus.conflict;
}

/// 课程业务编排：校验 -> 冲突检测 -> 事务写库。
/// 通知重排在 Provider 层触发（需要当前提醒设置），此处不涉及。
class CourseService {
  CourseService({
    required CourseRepository courseRepository,
    required SemesterRepository semesterRepository,
  })  : _courseRepository = courseRepository,
        _semesterRepository = semesterRepository;

  final CourseRepository _courseRepository;
  final SemesterRepository _semesterRepository;

  /// 保存课程。冲突时默认不写入（[force] = false）。
  Future<SaveResult> saveCourse({
    required Course course,
    required List<CourseSchedule> schedules,
    bool force = false,
  }) async {
    final Semester? semester = await _semesterRepository.getSemester();
    final String? invalid = validate(
      course: course,
      schedules: schedules,
      semester: semester,
    );
    if (invalid != null) {
      return SaveResult.invalid(invalid);
    }

    if (!force) {
      final List<Conflict> conflicts = await detectConflicts(
        course: course,
        schedules: schedules,
      );
      if (conflicts.isNotEmpty) {
        return SaveResult.conflict(conflicts);
      }
    }

    final int courseId = await _courseRepository.saveCourseWithSchedules(
      course,
      schedules,
    );
    Logger.debug('保存课程成功 id=$courseId');
    return SaveResult.saved(courseId);
  }

  Future<List<Conflict>> detectConflicts({
    required Course course,
    required List<CourseSchedule> schedules,
  }) async {
    final List<ScheduledEntry> existing =
        await _courseRepository.getAllEntries();
    return ConflictDetector.detect(
      candidateSchedules: schedules,
      candidateCourseId: course.id,
      existing: existing,
    );
  }

  Future<void> deleteCourse(int courseId) async {
    await _courseRepository.deleteCourse(courseId);
    Logger.debug('删除课程 id=$courseId');
  }

  /// 表单校验规则集中在这里，UI 只展示返回的文案。
  static String? validate({
    required Course course,
    required List<CourseSchedule> schedules,
    required Semester? semester,
  }) {
    if (course.name.trim().isEmpty) {
      return '课程名称不能为空';
    }
    if (course.name.trim().length > AppConstants.maxCourseNameLength) {
      return '课程名称不能超过 ${AppConstants.maxCourseNameLength} 个字';
    }
    if (course.note.length > AppConstants.maxNoteLength) {
      return '备注不能超过 ${AppConstants.maxNoteLength} 个字';
    }
    if (schedules.isEmpty) {
      return '至少添加一个上课时段';
    }

    final int totalWeeks =
        semester?.totalWeeks ?? AppConstants.defaultTotalWeeks;
    for (int i = 0; i < schedules.length; i++) {
      final CourseSchedule schedule = schedules[i];
      final String prefix = '第 ${i + 1} 个时段：';
      if (schedule.weekday < 1 || schedule.weekday > 7) {
        return '$prefix星期设置不正确';
      }
      if (schedule.startSlot < 1 || schedule.endSlot < 1) {
        return '$prefix节次设置不正确';
      }
      if (schedule.startSlot > schedule.endSlot) {
        return '$prefix起始节次不能晚于结束节次';
      }
      if (schedule.startWeek < 1 || schedule.endWeek < 1) {
        return '$prefix周次设置不正确';
      }
      if (schedule.startWeek > schedule.endWeek) {
        return '$prefix起始周不能晚于结束周';
      }
      if (schedule.endWeek > totalWeeks) {
        return '$prefix周次超出学期总周数（$totalWeeks 周），请先在设置中调整';
      }
    }
    return null;
  }

  /// 时间轴校验（设置页保存节次表时用）。
  static String? validateTimeSlots(List<TimeSlot> slots) {
    for (final TimeSlot slot in slots) {
      if (!TimeUtils.isValidRange(slot.startMinute, slot.endMinute)) {
        return '第 ${slot.slotIndex} 节时间不正确（开始必须早于结束）';
      }
    }
    return null;
  }
}
