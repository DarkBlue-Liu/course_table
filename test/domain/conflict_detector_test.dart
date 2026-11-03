import 'package:course_table/domain/models/conflict.dart';
import 'package:course_table/domain/models/course.dart';
import 'package:course_table/domain/models/course_schedule.dart';
import 'package:course_table/domain/models/scheduled_entry.dart';
import 'package:course_table/domain/models/week_type.dart';
import 'package:course_table/domain/rules/conflict_detector.dart';
import 'package:flutter_test/flutter_test.dart';

CourseSchedule schedule({
  int? courseId,
  int weekday = 1,
  int startSlot = 1,
  int endSlot = 2,
  int startWeek = 1,
  int endWeek = 16,
  WeekType weekType = WeekType.all,
}) {
  return CourseSchedule(
    courseId: courseId ?? 0,
    weekday: weekday,
    startSlot: startSlot,
    endSlot: endSlot,
    startWeek: startWeek,
    endWeek: endWeek,
    weekType: weekType,
  );
}

ScheduledEntry entry({
  required int courseId,
  required String name,
  required CourseSchedule schedule,
}) {
  return ScheduledEntry(
    Course(id: courseId, name: name, colorValue: 0xFF4C6FFF),
    schedule.copyWith(courseId: courseId),
  );
}

void main() {
  group('schedulesConflict 基础判定', () {
    test('同一天、同节次、同周次 → 冲突', () {
      expect(
        ConflictDetector.schedulesConflict(schedule(), schedule()),
        isTrue,
      );
    });

    test('不同天 → 不冲突', () {
      expect(
        ConflictDetector.schedulesConflict(
          schedule(weekday: 1),
          schedule(weekday: 2),
        ),
        isFalse,
      );
    });

    test('节次不相交 → 不冲突', () {
      expect(
        ConflictDetector.schedulesConflict(
          schedule(startSlot: 1, endSlot: 2),
          schedule(startSlot: 3, endSlot: 4),
        ),
        isFalse,
      );
    });

    test('节次部分重叠 → 冲突', () {
      expect(
        ConflictDetector.schedulesConflict(
          schedule(startSlot: 1, endSlot: 3),
          schedule(startSlot: 2, endSlot: 4),
        ),
        isTrue,
      );
    });

    test('完全不同周次区间 → 不冲突', () {
      expect(
        ConflictDetector.schedulesConflict(
          schedule(startWeek: 1, endWeek: 8),
          schedule(startWeek: 9, endWeek: 16),
        ),
        isFalse,
      );
    });

    test('单周 vs 双周 → 不冲突', () {
      expect(
        ConflictDetector.schedulesConflict(
          schedule(weekType: WeekType.odd),
          schedule(weekType: WeekType.even),
        ),
        isFalse,
      );
    });
  });

  group('detect 与已有课程的比较', () {
    final List<ScheduledEntry> existing = <ScheduledEntry>[
      entry(
        courseId: 1,
        name: '高等数学',
        schedule: schedule(courseId: 1, weekday: 1, startSlot: 1, endSlot: 2),
      ),
      entry(
        courseId: 2,
        name: '大学英语',
        schedule: schedule(courseId: 2, weekday: 3, startSlot: 3, endSlot: 4),
      ),
    ];

    test('命中已有课程返回冲突详情', () {
      final List<Conflict> conflicts = ConflictDetector.detect(
        candidateSchedules: <CourseSchedule>[
          schedule(weekday: 1, startSlot: 2, endSlot: 2),
        ],
        existing: existing,
      );
      expect(conflicts.length, 1);
      expect(conflicts.first.courseName, '高等数学');
      expect(conflicts.first.courseId, 1);
      // Conflict 携带的是「已有课程」的时段，这里是 1-2 节
      expect(conflicts.first.slotText, '第1-2节');
    });

    test('不冲突时返回空列表', () {
      final List<Conflict> conflicts = ConflictDetector.detect(
        candidateSchedules: <CourseSchedule>[
          schedule(weekday: 2, startSlot: 1, endSlot: 2),
        ],
        existing: existing,
      );
      expect(conflicts, isEmpty);
    });

    test('编辑同一门课不会与自己冲突', () {
      final List<Conflict> conflicts = ConflictDetector.detect(
        candidateSchedules: <CourseSchedule>[
          schedule(weekday: 1, startSlot: 1, endSlot: 2),
        ],
        candidateCourseId: 1,
        existing: existing,
      );
      expect(conflicts, isEmpty);
    });

    test('候选多个时段时全部检测', () {
      final List<Conflict> conflicts = ConflictDetector.detect(
        candidateSchedules: <CourseSchedule>[
          schedule(weekday: 1, startSlot: 1, endSlot: 2),
          schedule(weekday: 3, startSlot: 4, endSlot: 4),
          schedule(weekday: 5, startSlot: 1, endSlot: 2),
        ],
        existing: existing,
      );
      expect(conflicts.length, 2);
      expect(
        conflicts.map((Conflict c) => c.courseName).toSet(),
        <String>{'高等数学', '大学英语'},
      );
    });

    test('hasConflict 便捷方法', () {
      expect(
        ConflictDetector.hasConflict(
          candidate: schedule(weekday: 3, startSlot: 3, endSlot: 3),
          existing: existing,
        ),
        isTrue,
      );
    });
  });

  group('Conflict 文案', () {
    test('description 包含课程名、星期、节次、周次', () {
      final Conflict conflict = Conflict(
        courseId: 1,
        courseName: '高等数学',
        schedule: schedule(
          courseId: 1,
          weekday: 1,
          startSlot: 3,
          endSlot: 4,
          startWeek: 1,
          endWeek: 16,
          weekType: WeekType.odd,
        ),
      );
      expect(conflict.description, contains('高等数学'));
      expect(conflict.description, contains('周一'));
      expect(conflict.description, contains('第3-4节'));
      expect(conflict.description, contains('单周'));
    });
  });
}
