import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_language.dart';

/// Thin wrapper around `url_launcher`, used by the sidebar's Telegram item
/// and the Settings > Other section (Phase 7, see
/// docs/SETTINGS_SIDEBAR_PLAN.md). An unconfigured (empty) URL is treated as
/// "not set up yet" instead of attempting — and failing — a broken launch.
class LinkLauncher {
  LinkLauncher._();

  static Future<void> open(BuildContext context, String url) async {
    if (url.isEmpty) {
      _notify(context, AppLanguage.instance.text('هذا الرابط غير مُعدّ بعد.', 'This link isn\'t set up yet.'));
      return;
    }
    final uri = Uri.tryParse(url);
    final launchable = uri != null && await canLaunchUrl(uri);
    if (!context.mounted) return;
    if (!launchable) {
      _notify(context, AppLanguage.instance.text('تعذّر فتح الرابط.', 'Couldn\'t open the link.'));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> openEmail(BuildContext context, String email) async {
    if (email.isEmpty) {
      _notify(context, AppLanguage.instance.text('البريد الإلكتروني غير مُعدّ بعد.', 'The contact email isn\'t set up yet.'));
      return;
    }
    final uri = Uri(scheme: 'mailto', path: email);
    final launchable = await canLaunchUrl(uri);
    if (!context.mounted) return;
    if (!launchable) {
      _notify(context, AppLanguage.instance.text('تعذّر فتح تطبيق البريد.', 'Couldn\'t open a mail app.'));
      return;
    }
    await launchUrl(uri);
  }

  static void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
