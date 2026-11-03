import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import 'course_service.dart';
import '../domain/models/course.dart';
import '../domain/models/course_schedule.dart';
import '../domain/models/semester.dart';
import '../domain/models/time_slot.dart';
import '../domain/models/week_type.dart';
import '../domain/rules/week_calculator.dart';
import '../repositories/course_repository.dart';
import '../repositories/semester_repository.dart';
import '../repositories/time_slot_repository.dart';

/// 备份/恢复：纯本地数据的 JSON 导出与导入。
///
/// 1.0 的意义：数据只在本机，换机/清数据就会全丢，必须有一条退路。
/// 注意：跨三个 Repository 导入不是单个事务，导入中途失败可能留下部分数据，
/// 所以导入前会先做完整解析与校验，尽最大可能一次成功。
class BackupService {
  BackupService({
    required CourseRepository courseRepository,
    required SemesterRepository semesterRepository,
    required TimeSlotRepository timeSlotRepository,
  })  : _courseRepository = courseRepository,
        _semesterRepository = semesterRepository,
        _timeSlotRepository = timeSlotRepository;

  final CourseRepository _courseRepository;
  final SemesterRepository _semesterRepository;
  final TimeSlotRepository _timeSlotRepository;

  static const int formatVersion = 1;

  Future<String> exportJson() async {
    final Semester? semester = await _semesterRepository.getSemester();
    final List<TimeSlot> slots = await _timeSlotRepository.getAll();
    final List<Course> courses = await _courseRepository.getAllCourses();

    final List<Map<String, Object?>> courseJson = <Map<String, Object?>>[];
    for (final Course course in courses) {
      final List<CourseSchedule> schedules =
          await _courseRepository.getSchedulesByCourse(course.id!);
      courseJson.add(<String, Object?>{
        'name': course.name,
        'teacher': course.teacher,
        'location': course.location,
        'color': course.colorValue,
        'note': course.note,
        'createdAt': (course.createdAt ?? DateTime.now()).toIso8601String(),
        'schedules': schedules
            .map((CourseSchedule s) => <String, Object?>{
                  'weekday': s.weekday,
                  'startSlot': s.startSlot,
                  'endSlot': s.endSlot,
                  'startWeek': s.startWeek,
                  'endWeek': s.endWeek,
                  'weekType': s.weekType.value,
                })
            .toList(),
      });
    }

    final Map<String, Object?> data = <String, Object?>{
      'format': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'semester': semester == null
          ? null
          : <String, Object?>{
              'firstWeekMonday': _isoDate(semester.firstWeekMonday),
              'totalWeeks': semester.totalWeeks,
              'startDate': semester.startDate == null
                  ? null
                  : _isoDate(semester.startDate!),
              'holidayStartDate': semester.holidayStartDate == null
                  ? null
                  : _isoDate(semester.holidayStartDate!),
              'autoWeeks': semester.autoWeeks,
            },
      'timeSlots': slots
          .map((TimeSlot slot) => <String, Object?>{
                'slotIndex': slot.slotIndex,
                'startMinute': slot.startMinute,
                'endMinute': slot.endMinute,
              })
          .toList(),
      'courses': courseJson,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 导出到应用私有文档目录，返回文件路径。
  Future<File> exportToFile() async {
    final String content = await exportJson();
    final Directory dir = await getApplicationDocumentsDirectory();
    final String stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    final File file = File('${dir.path}/course_table_backup_$stamp.json');
    await file.writeAsString(content);
    Logger.debug('导出备份: ${file.path}');
    return file;
  }

  /// 从文件导入，返回导入的课程数量。
  Future<int> importFromFile(String path) async {
    final String content = await File(path).readAsString();
    return importJson(content);
  }

  /// 从 JSON 字符串导入（覆盖现有数据）。
  Future<int> importJson(String content) async {
    final Object? decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('备份文件不是合法的 JSON 对象');
    }
    final Map<String, Object?> data = decoded.cast<String, Object?>();
    final int format = data['format'] as int? ?? 0;
    if (format != formatVersion) {
      throw const FormatException('备份文件版本不支持');
    }

    // 先完整解析，确认格式没问题再动库。
    final Semester? semester = _parseSemester(data['semester']);
    final List<TimeSlot> slots = _parseTimeSlots(data['timeSlots']);
    if (data['courses'] is! List) {
      throw const FormatException('备份文件缺少课程列表');
    }
    final List<Object?> rawCourses = data['courses'] as List<Object?>;

    if (semester == null) {
      throw const FormatException('备份文件缺少学期信息');
    }
    if (slots.isEmpty) {
      throw const FormatException('备份文件缺少节次时间表');
    }

    if (semester.totalWeeks < AppConstants.minTotalWeeks ||
        semester.totalWeeks > AppConstants.maxTotalWeeks ||
        semester.firstWeekMonday.weekday != DateTime.monday) {
      throw const FormatException('学期日期或总周数不正确');
    }
    final String? slotError = CourseService.validateTimeSlots(slots);
    if (slotError != null) {
      throw FormatException(slotError);
    }
    for (int i = 0; i < slots.length; i++) {
      if (slots[i].slotIndex != i + 1) {
        throw const FormatException('节次序号必须从 1 开始连续且不重复');
      }
    }
    final List<({Course course, List<CourseSchedule> schedules})> parsed =
        <({Course course, List<CourseSchedule> schedules})>[];

    for (final Object? rawCourse in rawCourses) {
      if (rawCourse is! Map) {
        throw const FormatException('课程格式不正确');
      }
      final Map<String, Object?> courseMap = rawCourse.cast<String, Object?>();
      final Course course = Course(
        name: courseMap['name'] as String? ?? '',
        teacher: courseMap['teacher'] as String? ?? '',
        location: courseMap['location'] as String? ?? '',
        colorValue: courseMap['color'] as int? ?? 0,
        note: courseMap['note'] as String? ?? '',
        createdAt: DateTime.tryParse(courseMap['createdAt'] as String? ?? ''),
      );
      final List<Object?> rawSchedules =
          (courseMap['schedules'] as List<Object?>?) ?? const <Object?>[];
      final List<CourseSchedule> schedules = <CourseSchedule>[];
      for (final Object? rawSchedule in rawSchedules) {
        if (rawSchedule is! Map) {
          throw const FormatException('上课时段格式不正确');
        }
        final Map<String, Object?> item = rawSchedule.cast<String, Object?>();
        for (final String key in <String>[
          'weekday',
          'startSlot',
          'endSlot',
          'startWeek',
          'endWeek',
        ]) {
          if (item[key] is! int) {
            throw FormatException('上课时段缺少有效字段：$key');
          }
        }
        if (!<int>[0, 1, 2].contains(item['weekType'])) {
          throw const FormatException('单双周设置不正确');
        }
        schedules.add(
          CourseSchedule(
            weekday: item['weekday'] as int? ?? 1,
            startSlot: item['startSlot'] as int? ?? 1,
            endSlot: item['endSlot'] as int? ?? 1,
            startWeek: item['startWeek'] as int? ?? 1,
            endWeek: item['endWeek'] as int? ?? 1,
            weekType: WeekType.fromValue(item['weekType'] as int? ?? 0),
          ),
        );
      }
      final String? error = CourseService.validate(
        course: course,
        schedules: schedules,
        semester: semester,
      );
      if (error != null) {
        throw FormatException(error);
      }
      if (schedules.any((CourseSchedule s) => s.endSlot > slots.length)) {
        throw const FormatException('课程节次超出节次时间表');
      }
      parsed.add((course: course, schedules: schedules));
    }

    await _courseRepository.clearAll();
    await _semesterRepository.saveSemester(semester);
    await _timeSlotRepository.replaceAll(slots);
    for (final item in parsed) {
      await _courseRepository.saveCourseWithSchedules(
          item.course, item.schedules);
    }

    Logger.debug('导入完成，课程 ${rawCourses.length} 门');
    return rawCourses.length;
  }

  Semester? _parseSemester(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, Object?> map = raw.cast<String, Object?>();
    final String? date = map['firstWeekMonday'] as String?;
    if (date == null) {
      return null;
    }
    final DateTime monday = DateTime.parse(date);
    final DateTime? start = map['startDate'] == null
        ? null
        : DateTime.parse(map['startDate'] as String);
    final DateTime? holiday = map['holidayStartDate'] == null
        ? null
        : DateTime.parse(map['holidayStartDate'] as String);
    if (start != null && WeekCalculator.normalizeStart(start) != monday) {
      throw const FormatException('开学日期与第 1 周不一致');
    }
    if (holiday != null && !holiday.isAfter(start ?? monday)) {
      throw const FormatException('放假日期必须晚于开学日期');
    }
    final bool auto = map['autoWeeks'] as bool? ?? false;
    if (auto &&
        holiday != null &&
        WeekCalculator.inferTotalWeeks(
                startDate: start ?? monday, holidayStartDate: holiday) !=
            map['totalWeeks']) {
      throw const FormatException('自动周数与学期日期不一致');
    }
    return Semester(
      id: 1,
      firstWeekMonday: monday,
      startDate: start,
      holidayStartDate: holiday,
      autoWeeks: auto,
      totalWeeks: map['totalWeeks'] as int? ?? 20,
    );
  }

  List<TimeSlot> _parseTimeSlots(Object? raw) {
    if (raw is! List) {
      return <TimeSlot>[];
    }
    final List<TimeSlot> slots = <TimeSlot>[];
    for (final Object? item in raw) {
      if (item is! Map) {
        throw const FormatException('节次格式不正确');
      }
      final Map<String, Object?> map = item.cast<String, Object?>();
      slots.add(
        TimeSlot(
          slotIndex: map['slotIndex'] as int? ?? slots.length + 1,
          startMinute: map['startMinute'] as int? ?? 0,
          endMinute: map['endMinute'] as int? ?? 0,
        ),
      );
    }
    slots.sort((TimeSlot a, TimeSlot b) => a.slotIndex.compareTo(b.slotIndex));
    return slots;
  }

  String _isoDate(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
