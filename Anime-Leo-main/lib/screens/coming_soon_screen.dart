import 'package:flutter/material.dart';
import '../core/app_language.dart';
import '../widgets/ui_states.dart';

/// Generic placeholder for sidebar destinations that don't have a real
/// screen/backend yet (see docs/SETTINGS_SIDEBAR_PLAN.md, Phase 8).
/// Keeps navigation from dead-ending while each item's real screen is built.
class ComingSoonScreen extends StatelessWidget {
  final String titleAr;
  final String titleEn;
  final IconData icon;

  const ComingSoonScreen({
    super.key,
    required this.titleAr,
    required this.titleEn,
    this.icon = Icons.hourglass_top_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final title = AppLanguage.instance.text(titleAr, titleEn);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: UiStateCard(
        icon: icon,
        title: title,
        message: AppLanguage.instance.text(
          'هذا القسم قيد التطوير وسيتوفر في تحديث قادم.',
          'This section is under development and will be available in a future update.',
        ),
      ),
    );
  }
}
