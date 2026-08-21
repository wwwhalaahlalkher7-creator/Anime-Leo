import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_language.dart';
import '../core/app_settings.dart';
import '../core/config.dart';
import '../core/link_launcher.dart';
import '../core/theme_controller.dart';
import 'about_screen.dart';
import 'coming_soon_screen.dart';
import 'disclaimer_screen.dart';
import 'privacy_policy_screen.dart';

/// Full Settings screen, reachable from the sidebar.
///
/// Section status (see docs/SETTINGS_SIDEBAR_PLAN.md):
/// - Account: placeholder only — Phase 3 decided no edit-profile UI, no
///   visibility toggles, no auth until local-profile vs. real backend
///   accounts is decided.
/// - Notifications: real toggles, wired to [AppSettings] (Phase 4). Actually
///   delivering push notifications still needs a notification pipeline that
///   doesn't exist in this codebase yet.
/// - Player: real picker, wired to [AppSettings] (Phase 5). Launching a true
///   external player still needs an Android intent/plugin dependency.
/// - General: appearance now supports system/light/dark, wired to
///   [ThemeController] (Phase 6).
/// - Other: still a placeholder — links land in Phase 7.
class SettingsScreen extends StatelessWidget {
  final ThemeController theme;

  const SettingsScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([theme, AppSettings.instance, AppLanguage.instance]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(AppLanguage.instance.text('الإعدادات', 'Settings')),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(icon: Icons.person_outline, titleAr: 'الحساب', titleEn: 'Account'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(AppLanguage.instance.text('إدارة الحساب', 'Manage account')),
                subtitle: Text(AppLanguage.instance.text('قريبًا', 'Coming soon')),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ComingSoonScreen(
                      titleAr: 'الحساب',
                      titleEn: 'Account',
                      icon: Icons.person_outline,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _SectionHeader(icon: Icons.notifications_outlined, titleAr: 'الإشعارات', titleEn: 'Notifications'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(AppLanguage.instance.text('تنبيهات الحلقات الجديدة', 'New-episode alerts')),
                    subtitle: Text(AppLanguage.instance.text(
                      'من يستلم إشعارًا عند صدور حلقة جديدة.',
                      'Who gets notified when a new episode airs.',
                    )),
                  ),
                  RadioGroup<EpisodeAlertScope>(
                    groupValue: AppSettings.instance.episodeAlerts,
                    onChanged: (v) {
                      if (v != null) {
                        AppSettings.instance.setEpisodeAlerts(v);
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<EpisodeAlertScope>(
                          value: EpisodeAlertScope.all,
                          title: Text(AppLanguage.instance.text('الكل', 'All')),
                        ),
                        RadioListTile<EpisodeAlertScope>(
                          value: EpisodeAlertScope.favoritesOnly,
                          title: Text(AppLanguage.instance.text('المفضلة فقط', 'Favorites only')),
                        ),
                        RadioListTile<EpisodeAlertScope>(
                          value: EpisodeAlertScope.off,
                          title: Text(AppLanguage.instance.text('إيقاف', 'Off')),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(AppLanguage.instance.text('إشعارات التعليقات', 'Comment notifications')),
                    value: AppSettings.instance.commentNotifications,
                    onChanged: AppSettings.instance.setCommentNotifications,
                  ),
                  SwitchListTile(
                    title: Text(AppLanguage.instance.text('إشعارات التقييمات', 'Review notifications')),
                    value: AppSettings.instance.reviewNotifications,
                    onChanged: AppSettings.instance.setReviewNotifications,
                  ),
                  SwitchListTile(
                    title: Text(AppLanguage.instance.text('إشعارات الأخبار', 'News notifications')),
                    value: AppSettings.instance.newsNotifications,
                    onChanged: AppSettings.instance.setNewsNotifications,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _Note(AppLanguage.instance.text(
              'هذه المفاتيح تتحكم بما تريد استلامه فقط. إرسال الإشعارات الفعلي يحتاج بنية تنبيهات (مثل FCM) غير مضافة بعد.',
              'These toggles only control what you\'d receive. Actually delivering notifications needs a push pipeline (e.g. FCM) that isn\'t wired up yet.',
            )),
            const SizedBox(height: 24),

            _SectionHeader(icon: Icons.play_circle_outline, titleAr: 'المشغّل', titleEn: 'Player'),
            Card(
              child: Column(
                children: [
                  RadioGroup<PlayerPreference>(
                    groupValue: AppSettings.instance.playerPreference,
                    onChanged: (v) {
                      if (v != null) {
                        AppSettings.instance.setPlayerPreference(v);
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<PlayerPreference>(
                          value: PlayerPreference.askEveryTime,
                          title: Text(AppLanguage.instance.text('اسأل في كل مرة', 'Ask every time')),
                        ),
                        RadioListTile<PlayerPreference>(
                          value: PlayerPreference.builtIn,
                          title: Text(AppLanguage.instance.text('المشغّل المدمج السريع', 'Built-in fast player')),
                        ),
                        RadioListTile<PlayerPreference>(
                          value: PlayerPreference.external,
                          title: Text(AppLanguage.instance.text('مشغّل خارجي', 'External player')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _Note(AppLanguage.instance.text(
              'فتح مشغّل خارجي فعليًا يحتاج إضافة اعتمادية Android intent لاحقًا؛ هذا التفضيل محفوظ ومطبّق داخل شاشة التشغيل حاليًا.',
              'Actually launching an external player still needs an Android intent dependency; this preference is saved and applied inside the player screen for now.',
            )),
            const SizedBox(height: 24),

            _SectionHeader(icon: Icons.high_quality_outlined, titleAr: 'جودة وترجمة المشغل', titleEn: 'Player quality & subtitles'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(AppLanguage.instance.text('الجودة الافتراضية', 'Default quality')),
                    subtitle: Text(AppSettings.instance.defaultQuality.toUpperCase()),
                    trailing: DropdownButton<String>(
                      value: AppSettings.instance.defaultQuality,
                      items: const [
                        DropdownMenuItem(value: 'auto', child: Text('Auto')),
                        DropdownMenuItem(value: '1080p', child: Text('1080p')),
                        DropdownMenuItem(value: '720p', child: Text('720p')),
                        DropdownMenuItem(value: '480p', child: Text('480p')),
                      ],
                      onChanged: (v) { if (v != null) AppSettings.instance.setDefaultQuality(v); },
                    ),
                  ),
                  ListTile(
                    title: Text(AppLanguage.instance.text('الترجمة المفضلة', 'Preferred subtitles')),
                    trailing: DropdownButton<String>(
                      value: AppSettings.instance.subtitleLanguage,
                      items: const [
                        DropdownMenuItem(value: 'ar', child: Text('العربية')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                      ],
                      onChanged: (v) { if (v != null) AppSettings.instance.setSubtitleLanguage(v); },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _SectionHeader(icon: Icons.tune_outlined, titleAr: 'عام', titleEn: 'General'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(AppLanguage.instance.text('المظهر', 'Appearance')),
                  ),
                  RadioGroup<ThemeMode>(
                    groupValue: theme.mode,
                    onChanged: (v) {
                      if (v != null) {
                        theme.setMode(v);
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.system,
                          title: Text(AppLanguage.instance.text('حسب النظام', 'System')),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          title: Text(AppLanguage.instance.text('فاتح', 'Light')),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          title: Text(AppLanguage.instance.text('داكن', 'Dark')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _SectionHeader(icon: Icons.info_outline, titleAr: 'أخرى', titleEn: 'Other'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.public_outlined),
                    title: Text(AppLanguage.instance.text('الموقع الرسمي', 'Official website')),
                    onTap: () => LinkLauncher.open(context, officialWebsiteUrl),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: Text(AppLanguage.instance.text('تواصل معنا', 'Contact us')),
                    onTap: () => _showContactSheet(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.ios_share_outlined),
                    title: Text(AppLanguage.instance.text('مشاركة التطبيق', 'Share app')),
                    onTap: () => _shareApp(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(AppLanguage.instance.text('إخلاء المسؤولية', 'Disclaimer')),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DisclaimerScreen())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(AppLanguage.instance.text('سياسة الخصوصية', 'Privacy policy')),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(AppLanguage.instance.text('عن التطبيق', 'About app')),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareApp() {
    final link = officialWebsiteUrl.isEmpty ? appName : '$appName — $officialWebsiteUrl';
    SharePlus.instance.share(ShareParams(text: link));
  }

  void _showContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(AppLanguage.instance.text('البريد الإلكتروني', 'Email')),
              onTap: () {
                Navigator.pop(sheetContext);
                LinkLauncher.openEmail(context, contactEmail);
              },
            ),
            ListTile(
              leading: const Icon(Icons.telegram_outlined),
              title: Text(AppLanguage.instance.text('تيليجرام', 'Telegram')),
              onTap: () {
                Navigator.pop(sheetContext);
                LinkLauncher.open(context, telegramUrl);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String titleAr;
  final String titleEn;

  const _SectionHeader({required this.icon, required this.titleAr, required this.titleEn});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            AppLanguage.instance.text(titleAr, titleEn),
            style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(text, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.5)),
    );
  }
}
