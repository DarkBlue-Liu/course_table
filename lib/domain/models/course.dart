import '../../core/constants/app_constants.dart';

/// 课程实体（持久化模型）。颜色存 int（ARGB），不 import dart:ui。
class Course {
  const Course({
    this.id,
    required this.name,
    this.teacher = '',
    this.location = '',
    this.colorValue = AppConstants.defaultCourseColorValue,
    this.note = '',
    this.createdAt,
  });

  final int? id;
  final String name;
  final String teacher;
  final String location;

  /// ARGB int，取值见 AppColors.coursePalette。
  final int colorValue;
  final String note;
  final DateTime? createdAt;

  Course copyWith({
    int? id,
    String? name,
    String? teacher,
    String? location,
    int? colorValue,
    String? note,
    DateTime? createdAt,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      colorValue: colorValue ?? this.colorValue,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 兼容默认构造：未指定颜色时取配色板首色。
  static Course draft({String name = ''}) => Course(
        name: name,
        colorValue: AppConstants.defaultCourseColorValue,
      );

  @override
  String toString() => 'Course($id, $name)';
}
