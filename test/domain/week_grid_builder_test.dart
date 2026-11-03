import 'package:course_table/domain/models/course.dart';
import 'package:course_table/domain/models/course_schedule.dart';
import 'package:course_table/domain/models/scheduled_entry.dart';
import 'package:course_table/domain/models/time_slot.dart';
import 'package:course_table/domain/models/week_type.dart';
import 'package:course_table/domain/rules/week_grid_builder.dart';
import 'package:course_table/domain/view_models/week_grid_item.dart';
import 'package:flutter_test/flutter_test.dart';

const List<TimeSlot> defaultSlots = <TimeSlot>[
  TimeSlot(slotIndex: 1, startMinute: 480, endMinute: 525),
  TimeSlot(slotIndex: 2, startMinute: 535, endMinute: 580),
  TimeSlot(slotIndex: 3, startMinute: 600, endMinute: 645),
  TimeSlot(slotIndex: 4, startMinute: 655, endMinute: 700),
  TimeSlot(slotIndex: 5, startMinute: 840, endMinute: 885),
  TimeSlot(slotIndex: 6, startMinute: 895, endMinute: 940),
];

ScheduledEntry makeEntry({
  required int courseId,
  required String name,
  int weekday = 1,
  int startSlot = 1,
  int endSlot = 2,
  int startWeek = 1,
  int endWeek = 16,
  WeekType weekType = WeekType.all,
  String location = 'A101',
  int colorValue = 0xFF4C6FFF,
}) {
  return ScheduledEntry(
    Course(
      id: courseId,
      name: name,
      location: location,
      colorValue: colorValue,
    ),
    CourseSchedule(
      courseId: courseId,
      weekday: weekday,
      startSlot: startSlot,
      endSlot: endSlot,
      startWeek: startWeek,
      endWeek: endWeek,
      weekType: weekType,
    ),
  );
}

void main() {
  group('按周过滤', () {
    final List<ScheduledEntry> entries = <ScheduledEntry>[
      makeEntry(courseId: 1, name: '全周课', startWeek: 1, endWeek: 16),
      makeEntry(
        courseId: 2,
        name: '单周课',
        weekday: 2,
        startWeek: 1,
        endWeek: 16,
        weekType: WeekType.odd,
      ),
      makeEntry(
        courseId: 3,
        name: '双周课',
        weekday: 3,
        startWeek: 1,
        endWeek: 16,
        weekType: WeekType.even,
      ),
      makeEntry(
        courseId: 4,
        name: '后半学期课',
        weekday: 4,
        startWeek: 9,
        endWeek: 16,
      ),
    ];

    test('第 1 周：全周 + 单周可见，双周/后半学期不可见', () {
      final List<WeekGridItem> items = WeekGridBuilder.build(
        week: 1,
        entries: entries,
        timeSlots: defaultSlots,
      );
      expect(
        items.map((WeekGridItem item) => item.name).toSet(),
        <String>{'全周课', '单周课'},
      );
    });

    test('第 2 周：全周 + 双周可见', () {
      final List<WeekGridItem> items = WeekGridBuilder.build(
        week: 2,
        entries: entries,
        timeSlots: defaultSlots,
      );
      expect(
        items.map((WeekGridItem item) => item.name).toSet(),
        <String>{'全周课', '双周课'},
      );
    });

    test('第 10 周：后半学期课出现', () {
      final List<WeekGridItem> items = WeekGridBuilder.build(
        week: 10,
        entries: entries,
        timeSlots: defaultSlots,
      );
      expect(
        items.map((WeekGridItem item) => item.name).toSet(),
        contains('后半学期课'),
      );
    });

    test('第 17 周：全部不可见', () {
      final List<WeekGridItem> items = WeekGridBuilder.build(
        week: 17,
        entries: entries,
        timeSlots: defaultSlots,
      );
      expect(items, isEmpty);
    });
  });

  group('跨节次合并', () {
    test('3-4 节的课生成一个块，span 为 2', () {
      final List<WeekGridItem> items = WeekGridBuilder.build(
        week: 1,
        entries: <ScheduledEntry>[
          makeEntry(
            courseId: 1,
            name: '物理',
            startSlot: 3,
            endSlot: 4,
          ),
        ],
        timeSlots: defaultSlots,
      );
      expect(items.length, 1);
      expect(items.first.startSlot, 3);
      expect(items.first.endSlot, 4);
      expect(items.first.slotSpan, 2);
    });

    test('超出节次表上限的部分被裁剪', () {
      final List<WeekGridItem> items = WeekGridBuilder.build(
        week: 1,
        entries: <ScheduledEntry>[
          makeEntry(
            courseId: 1,
            name: '晚课',
            startSlot: 5,
            endSlot: 8,
          ),
        ],
        timeSlots: defaultSlots,
      );
      expect(items.length, 1);
      expect(items.first.endSlot, 6);
    });
  });

  group('同格重叠分列（lane）', () {
    test('两门课完全重叠：laneCount 为 2，lane 分别为 0/1', () {
      final List<WeekGridItem> items = WeekGridBuilder.build(
        week: 1,
        entries: <ScheduledEntry>[
          makeEntry(courseId: 1, name: '数学', startSlot: 1, endSlot: 2),
          makeEntry(courseId: 2, name: '英语', startSlot: 1, endSlot: 2),
        ],
        timeSlots: defaultSlots,
      );
      expect(items.length, 2);
      for (final WeekGridItem item in items) {
        expect(item.laneCount, 2);
      }
      expect(
        items.map((WeekGridItem item) => item.lane).toSet(),
        <int>{0, 1},
      );
    });

    test('部分重叠也分列', () {
      final List<WeekGridItem> items = WeekGridBuilder.build(
        week: 1,
        entries: <ScheduledEntry>[
          makeEntry(courseId: 1, name: '数学', startSlot: 1, endSlot: 3),
          makeEntry(courseId: 2, name: '英语', startSlot: 2, endSlot: 4),
        ],
        timeSlots: defaultSlots,
      );
      expect(items.length, 2);
      expect(
        items.map((WeekGridItem item) => item.laneCount).toSet(),
        <int>{2},
      );
    });

    test('不重叠的课在同一列，laneCount 为 1', () {
      final List<WeekGridItem> items = WeekGridBuilder.build(
        week: 1,
        entries: <ScheduledEntry>[
          makeEntry(courseId: 1, name: '数学', startSlot: 1, endSlot: 2),
          makeEntry(courseId: 2, name: '英语', startSlot: 3, endSlot: 4),
        ],
        timeSlots: defaultSlots,
      );
      expect(items.length, 2);
      for (final WeekGridItem item in items) {
        expect(item.lane, 0);
        expect(item.laneCount, 1);
      }
    });
  });

  group('buildForDay', () {
    test('只返回指定星期的课，并按节次排序', () {
      final List<WeekGridItem> items = WeekGridBuilder.buildForDay(
        week: 1,
        weekday: 1,
        entries: <ScheduledEntry>[
          makeEntry(
              courseId: 1, name: '数学', weekday: 1, startSlot: 3, endSlot: 4),
          makeEntry(
              courseId: 2, name: '英语', weekday: 2, startSlot: 1, endSlot: 2),
          makeEntry(
              courseId: 3, name: '体育', weekday: 1, startSlot: 1, endSlot: 2),
        ],
        timeSlots: defaultSlots,
      );
      expect(items.length, 2);
      expect(items.first.name, '体育');
      expect(items.last.name, '数学');
    });

    test('周日（7）也能正确取到', () {
      final List<WeekGridItem> items = WeekGridBuilder.buildForDay(
        week: 1,
        weekday: 7,
        entries: <ScheduledEntry>[
          makeEntry(courseId: 1, name: '补习', weekday: 7),
        ],
        timeSlots: defaultSlots,
      );
      expect(items.length, 1);
      expect(items.first.name, '补习');
    });
  });

  group('异常数据兜底', () {
    test('节次倒置的脏数据被跳过', () {
      final List<WeekGridItem> items = WeekGridBuilder.build(
        week: 1,
        entries: <ScheduledEntry>[
          makeEntry(courseId: 1, name: '脏数据', startSlot: 5, endSlot: 2),
        ],
        timeSlots: defaultSlots,
      );
      expect(items, isEmpty);
    });

    test('星期越界的脏数据被跳过', () {
      final List<WeekGridItem> items = WeekGridBuilder.build(
        week: 1,
        entries: <ScheduledEntry>[
          makeEntry(courseId: 1, name: '脏数据', weekday: 9),
        ],
        timeSlots: defaultSlots,
      );
      expect(items, isEmpty);
    });
  });
}
