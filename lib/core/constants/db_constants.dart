/// 数据库表名、列名与建表 SQL 的唯一来源。
/// 任何地方不得硬编码表名/列名字符串。
class DbConstants {
  const DbConstants._();

  static const String databaseName = 'course_table.db';
  static const int databaseVersion = 2;

  // ---------- 表名 ----------
  static const String tableSemester = 'semester';
  static const String tableTimeSlot = 'time_slot';
  static const String tableCourse = 'course';
  static const String tableCourseSchedule = 'course_schedule';

  // ---------- 公共列 ----------
  static const String colId = 'id';

  // ---------- semester ----------
  static const String colFirstWeekMonday = 'first_week_monday';
  static const String colStartDate = 'start_date';
  static const String colHolidayStartDate = 'holiday_start_date';
  static const String colAutoWeeks = 'auto_weeks';
  static const String colTotalWeeks = 'total_weeks';
  static const String colUpdatedAt = 'updated_at';

  // ---------- time_slot ----------
  static const String colSlotIndex = 'slot_index';
  static const String colStartMinute = 'start_minute';
  static const String colEndMinute = 'end_minute';

  // ---------- course ----------
  static const String colName = 'name';
  static const String colTeacher = 'teacher';
  static const String colLocation = 'location';
  static const String colColor = 'color';
  static const String colNote = 'note';
  static const String colCreatedAt = 'created_at';

  // ---------- course_schedule ----------
  static const String colCourseId = 'course_id';
  static const String colWeekday = 'weekday';
  static const String colStartSlot = 'start_slot';
  static const String colEndSlot = 'end_slot';
  static const String colStartWeek = 'start_week';
  static const String colEndWeek = 'end_week';
  static const String colWeekType = 'week_type';

  // ---------- 建表 SQL ----------
  static const String createSemesterTable = '''
CREATE TABLE $tableSemester (
  $colId INTEGER PRIMARY KEY,
  $colFirstWeekMonday TEXT NOT NULL,
  $colTotalWeeks INTEGER NOT NULL,
  $colStartDate TEXT,
  $colHolidayStartDate TEXT,
  $colAutoWeeks INTEGER NOT NULL DEFAULT 1,
  $colUpdatedAt TEXT NOT NULL
)''';

  static const String createTimeSlotTable = '''
CREATE TABLE $tableTimeSlot (
  $colId INTEGER PRIMARY KEY AUTOINCREMENT,
  $colSlotIndex INTEGER NOT NULL UNIQUE,
  $colStartMinute INTEGER NOT NULL,
  $colEndMinute INTEGER NOT NULL
)''';

  static const String createCourseTable = '''
CREATE TABLE $tableCourse (
  $colId INTEGER PRIMARY KEY AUTOINCREMENT,
  $colName TEXT NOT NULL,
  $colTeacher TEXT NOT NULL DEFAULT '',
  $colLocation TEXT NOT NULL DEFAULT '',
  $colColor INTEGER NOT NULL,
  $colNote TEXT NOT NULL DEFAULT '',
  $colCreatedAt TEXT NOT NULL
)''';

  static const String createCourseScheduleTable = '''
CREATE TABLE $tableCourseSchedule (
  $colId INTEGER PRIMARY KEY AUTOINCREMENT,
  $colCourseId INTEGER NOT NULL,
  $colWeekday INTEGER NOT NULL,
  $colStartSlot INTEGER NOT NULL,
  $colEndSlot INTEGER NOT NULL,
  $colStartWeek INTEGER NOT NULL,
  $colEndWeek INTEGER NOT NULL,
  $colWeekType INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY ($colCourseId) REFERENCES $tableCourse($colId) ON DELETE CASCADE
)''';

  static const String createCourseScheduleIndex =
      'CREATE INDEX idx_course_schedule_course ON $tableCourseSchedule($colCourseId)';

  static const String createCourseScheduleSlotIndex =
      'CREATE INDEX idx_course_schedule_slot ON $tableCourseSchedule($colWeekday, $colStartSlot)';

  /// onCreate 时按顺序执行。
  static const List<String> createStatements = <String>[
    createSemesterTable,
    createTimeSlotTable,
    createCourseTable,
    createCourseScheduleTable,
    createCourseScheduleIndex,
    createCourseScheduleSlotIndex,
  ];
}
