/// 路由名常量，集中管理，避免散落的字符串。
class RouteNames {
  const RouteNames._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String courseEdit = '/course/edit';
  static const String courseDetail = '/course/detail';
  static const String semesterSettings = '/settings/semester';
  static const String timeSlotSettings = '/settings/time-slots';
  static const String reminderSettings = '/settings/reminder';
  static const String backup = '/settings/backup';
}

/// Preferences 键名。
class PrefKeys {
  const PrefKeys._();

  static const String onboardingDone = 'onboarding_done';
  static const String themeMode = 'theme_mode';
  static const String reminderEnabled = 'reminder_enabled';
  static const String reminderLeadMinutes = 'reminder_lead_minutes';
}
