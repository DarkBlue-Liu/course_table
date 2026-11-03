import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/routes.dart';

/// 应用级设置：主题模式、提醒开关、提前分钟数。全部落 shared_preferences。
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  bool _reminderEnabled = true;
  int _leadMinutes = AppConstants.defaultReminderLeadMinutes;

  /// 提醒相关设置变化后触发通知重排，由 main.dart 注入。
  Future<void> Function()? onReminderSettingsChanged;

  ThemeMode get themeMode => _themeMode;

  bool get reminderEnabled => _reminderEnabled;

  int get leadMinutes => _leadMinutes;

  String get themeModeLabel {
    switch (_themeMode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
    }
  }

  void _load() {
    final String? themeName = _prefs.getString(PrefKeys.themeMode);
    if (themeName != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (ThemeMode mode) => mode.name == themeName,
        orElse: () => ThemeMode.system,
      );
    }
    _reminderEnabled = _prefs.getBool(PrefKeys.reminderEnabled) ?? true;
    _leadMinutes = _prefs.getInt(PrefKeys.reminderLeadMinutes) ??
        AppConstants.defaultReminderLeadMinutes;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(PrefKeys.themeMode, mode.name);
  }

  Future<void> setReminderEnabled(bool enabled) async {
    if (_reminderEnabled == enabled) {
      return;
    }
    _reminderEnabled = enabled;
    notifyListeners();
    await _prefs.setBool(PrefKeys.reminderEnabled, enabled);
    await onReminderSettingsChanged?.call();
  }

  Future<void> setLeadMinutes(int minutes) async {
    if (_leadMinutes == minutes) {
      return;
    }
    _leadMinutes = minutes;
    notifyListeners();
    await _prefs.setInt(PrefKeys.reminderLeadMinutes, minutes);
    await onReminderSettingsChanged?.call();
  }

  static Future<void> markOnboardingDone(SharedPreferences prefs) =>
      prefs.setBool(PrefKeys.onboardingDone, true);

  static bool isOnboardingDone(SharedPreferences prefs) =>
      prefs.getBool(PrefKeys.onboardingDone) ?? false;
}
