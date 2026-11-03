import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import '../domain/models/semester.dart';
import '../domain/rules/week_calculator.dart';
import '../repositories/semester_repository.dart';

/// 学期配置状态。1.0 只有一份学期。
class SemesterProvider extends ChangeNotifier {
  SemesterProvider({
    required SemesterRepository repository,
    this.onChanged,
  }) : _repository = repository;

  final SemesterRepository _repository;

  /// 学期变化后回调（用于重排通知），由 main.dart 注入。
  Future<void> Function()? onChanged;

  Semester? _semester;
  bool _loading = true;

  Semester? get semester => _semester;

  bool get isLoading => _loading;

  bool get hasSemester => _semester != null;

  int get totalWeeks => _semester?.totalWeeks ?? AppConstants.defaultTotalWeeks;

  bool get isBeforeSemester {
    final Semester? semester = _semester;
    if (semester == null) {
      return false;
    }
    return WeekCalculator.isBeforeSemester(
      firstWeekMonday: semester.firstWeekMonday,
      today: DateTime.now(),
    );
  }

  bool get isAfterSemester {
    final Semester? semester = _semester;
    if (semester == null) {
      return false;
    }
    return WeekCalculator.isAfterSemester(
      firstWeekMonday: semester.firstWeekMonday,
      today: DateTime.now(),
      totalWeeks: semester.totalWeeks,
    );
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _semester = await _repository.getSemester();
    } catch (error, stackTrace) {
      Logger.error('读取学期失败', error, stackTrace);
      _semester = null;
    }
    _loading = false;
    notifyListeners();
  }

  /// 保存学期。[anyDate] 会先归一化成第 1 周周一。
  Future<void> saveSemester({
    required DateTime anyDate,
    required int totalWeeks,
    DateTime? holidayStartDate,
    bool autoWeeks = false,
  }) async {
    final int weeks = autoWeeks && holidayStartDate != null
        ? WeekCalculator.inferTotalWeeks(
            startDate: anyDate, holidayStartDate: holidayStartDate)
        : totalWeeks;
    if (holidayStartDate != null &&
        !holidayStartDate
            .isAfter(DateTime(anyDate.year, anyDate.month, anyDate.day))) {
      throw ArgumentError('放假日期必须晚于开学日期');
    }
    if (weeks < AppConstants.minTotalWeeks ||
        weeks > AppConstants.maxTotalWeeks) {
      throw ArgumentError('学期总周数需在 1–30 周之间，可切换为手动设置');
    }
    final int clamped = weeks
        .clamp(AppConstants.minTotalWeeks, AppConstants.maxTotalWeeks)
        .toInt();
    final Semester semester = Semester(
      id: 1,
      firstWeekMonday: WeekCalculator.normalizeStart(anyDate),
      totalWeeks: clamped,
      startDate: DateTime(anyDate.year, anyDate.month, anyDate.day),
      holidayStartDate: holidayStartDate,
      autoWeeks: autoWeeks,
    );
    await _repository.saveSemester(semester);
    _semester = semester;
    notifyListeners();
    await onChanged?.call();
  }

  /// 只改总周数，保留开学日期。
  Future<void> updateTotalWeeks(int totalWeeks) async {
    final Semester? current = _semester;
    if (current == null) {
      return;
    }
    await saveSemester(
      anyDate: current.startDate ?? current.firstWeekMonday,
      holidayStartDate: current.holidayStartDate,
      autoWeeks: false,
      totalWeeks: totalWeeks,
    );
  }
}
