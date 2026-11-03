import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../domain/models/semester.dart';
import '../domain/rules/week_calculator.dart';
import 'semester_provider.dart';

/// 周次状态：区分「真实的当前周」与「当前展示的周」。
///
/// - currentWeek 每次由开学日期现算，**不入库**；
/// - displayedWeek 在用户手动切换前恒等于 currentWeek，因此天然不会过期，
///   也不需要监听学期变化去"同步一个存下来的值"。
class WeekProvider extends ChangeNotifier {
  WeekProvider(this._semesterProvider);

  final SemesterProvider _semesterProvider;

  /// 用户手动选择的周次；为 null 表示自动跟随当前周。
  int? _manualWeek;

  Semester? get _semester => _semesterProvider.semester;

  int get totalWeeks => _semester?.totalWeeks ?? AppConstants.defaultTotalWeeks;

  /// 今天真实处于第几周（钳制在 1..总周数）。
  int get currentWeek {
    final Semester? semester = _semester;
    if (semester == null) {
      return 1;
    }
    return WeekCalculator.currentWeek(
      firstWeekMonday: semester.firstWeekMonday,
      today: DateTime.now(),
      totalWeeks: semester.totalWeeks,
    );
  }

  /// 当前展示的周次：用户手动切过就用手的，否则等于当前周。
  int get displayedWeek {
    final int? manual = _manualWeek;
    if (manual == null) {
      return currentWeek;
    }
    return manual.clamp(1, totalWeeks).toInt();
  }

  bool get hasUserSwitched => _manualWeek != null;

  bool get isShowingCurrentWeek => displayedWeek == currentWeek;

  void goToWeek(int week) {
    _manualWeek = week.clamp(1, totalWeeks).toInt();
    notifyListeners();
  }

  void nextWeek() => goToWeek(displayedWeek + 1);

  void previousWeek() => goToWeek(displayedWeek - 1);

  /// 回到当前周，并恢复「自动跟随」。
  void locateCurrentWeek() {
    _manualWeek = null;
    notifyListeners();
  }

  /// 跨天/跨周后刷新（从后台恢复、页面重新可见时调用）。
  /// 只有自动跟随模式下才可能真正发生变化。
  void refreshCurrentWeek() {
    if (_manualWeek != null) {
      return;
    }
    notifyListeners();
  }
}
