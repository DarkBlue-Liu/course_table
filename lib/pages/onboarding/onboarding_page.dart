import 'package:flutter/material.dart';
import '../settings/semester_settings_page.dart';

/// 首次引导与学期设置共用日期和周数编辑流程。
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const SemesterSettingsPage(isOnboarding: true);
}
