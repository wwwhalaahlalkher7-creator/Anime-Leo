import 'package:flutter/material.dart';
import '../core/app_language.dart';
import '../core/app_state.dart';
import '../core/config.dart';
import '../core/link_launcher.dart';
import '../core/theme_controller.dart';
import '../screens/coming_soon_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/seasons_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/upcoming_anime_screen.dart';
import '../screens/local_lists_screen.dart';
import '../services/analytics_service.dart';

/// App-wide sidebar, opened from a hamburger icon (see
/// docs/SETTINGS_SIDEBAR_PLAN.md, Phase 1).
///
/// Home / Favorites / Watch History already exist as tabs on [HomeScreen],
/// so those items just switch tabs via [onSelectTab] instead of pushing a
/// duplicate screen. "Coming Soon" and "Seasons" push their real screens
/// (Phase 8). Everything else still pushes a [ComingSoonScreen] placeholder
/// until its own phase builds it out — note that's the "under development"
/// widget, not the sidebar's "Coming Soon" catalog item.
class AppDrawer extends StatelessWidget {
  final int currentTabIndex;
  final ValueChanged<int> onSelectTab;
  final ThemeController theme;
  final AppState state;
  final AnalyticsService analytics;

  const AppDrawer({
    super.key,
    required this.currentTabIndex,
    required this.onSelectTab,
    required this.theme,
    required this.state,
    required this.analytics,
  });

  void _selectTab(BuildContext context, int index) {
    Navigator.pop(context);
    onSelectTab(index);
  }

  void _openPlaceholder(
    BuildContext context, {
    required String titleAr,
    required String titleEn,
    required IconData icon,
  }) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComingSoonScreen(titleAr: titleAr, titleEn: titleEn, icon: icon),
      ),
    );
  }

  void _openComingSoon(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UpcomingAnimeScreen(state: state, analytics: analytics),
      ),
    );
  }

  void _openSeasons(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeasonsScreen(state: state, analytics: analytics),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(theme: theme)));
  }

  void _openFavorites(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => LocalFavoritesScreen(state: state, analytics: analytics)));
  }

  void _openHistory(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => LocalHistoryScreen(state: state, analytics: analytics)));
  }

  void _openTelegram(BuildContext context) {
    Navigator.pop(context);
    LinkLauncher.open(context, telegramUrl);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: cs.surface),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: cs.primary.withValues(alpha: .18),
                    child: Icon(Icons.person_outline, color: cs.primary, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      AppLanguage.instance.text('زائر', 'Guest'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            _item(
              context,
              icon: Icons.home_outlined,
              labelAr: 'الرئيسية',
              labelEn: 'Home',
              selected: currentTabIndex == 0,
              onTap: () => _selectTab(context, 0),
            ),
            _item(
              context,
              icon: Icons.video_library_outlined,
              labelAr: 'قائمة الأنمي',
              labelEn: 'Anime List',
              onTap: () => _openPlaceholder(context, titleAr: 'قائمة الأنمي', titleEn: 'Anime List', icon: Icons.video_library_outlined),
            ),
            _item(
              context,
              icon: Icons.menu_book_outlined,
              labelAr: 'قائمة المانجا',
              labelEn: 'Manga List',
              onTap: () => _openPlaceholder(context, titleAr: 'قائمة المانجا', titleEn: 'Manga List', icon: Icons.menu_book_outlined),
            ),
            _item(
              context,
              icon: Icons.calendar_view_month_outlined,
              labelAr: 'المواسم',
              labelEn: 'Seasons',
              onTap: () => _openSeasons(context),
            ),
            _item(
              context,
              icon: Icons.leaderboard_outlined,
              labelAr: 'الإحصائيات العالمية',
              labelEn: 'Global Stats',
              onTap: () => _openPlaceholder(context, titleAr: 'الإحصائيات العالمية', titleEn: 'Global Stats', icon: Icons.leaderboard_outlined),
            ),
            _item(
              context,
              icon: Icons.upcoming_outlined,
              labelAr: 'قادم قريبًا',
              labelEn: 'Coming Soon',
              onTap: () => _openComingSoon(context),
            ),
            const Divider(height: 1),
            _item(
              context,
              icon: Icons.playlist_add_check_outlined,
              labelAr: 'قائمتي',
              labelEn: 'My List',
              onTap: () => _openPlaceholder(context, titleAr: 'قائمتي', titleEn: 'My List', icon: Icons.playlist_add_check_outlined),
            ),
            _item(
              context,
              icon: Icons.favorite_outline,
              labelAr: 'المفضلة',
              labelEn: 'Favorites',
              onTap: () => _openFavorites(context),
            ),
            _item(
              context,
              icon: Icons.history_outlined,
              labelAr: 'سجل المشاهدة',
              labelEn: 'Watch History',
              onTap: () => _openHistory(context),
            ),
            _item(
              context,
              icon: Icons.download_outlined,
              labelAr: 'التنزيلات',
              labelEn: 'Downloads',
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen())); },
            ),
            const Divider(height: 1),
            _item(
              context,
              icon: Icons.groups_outlined,
              labelAr: 'الشخصيات',
              labelEn: 'Characters',
              onTap: () => _openPlaceholder(context, titleAr: 'الشخصيات', titleEn: 'Characters', icon: Icons.groups_outlined),
            ),
            _item(
              context,
              icon: Icons.event_note_outlined,
              labelAr: 'جدول الحلقات',
              labelEn: 'Episode Schedule',
              onTap: () => _openPlaceholder(context, titleAr: 'جدول الحلقات', titleEn: 'Episode Schedule', icon: Icons.event_note_outlined),
            ),
            _item(
              context,
              icon: Icons.newspaper_outlined,
              labelAr: 'الأخبار',
              labelEn: 'News',
              onTap: () => _openPlaceholder(context, titleAr: 'الأخبار', titleEn: 'News', icon: Icons.newspaper_outlined),
            ),
            _item(
              context,
              icon: Icons.telegram_outlined,
              labelAr: 'تيليجرام',
              labelEn: 'Telegram',
              onTap: () => _openTelegram(context),
            ),
            const Divider(height: 1),
            _item(
              context,
              icon: Icons.settings_outlined,
              labelAr: 'الإعدادات',
              labelEn: 'Settings',
              onTap: () => _openSettings(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String labelAr,
    required String labelEn,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? cs.primary : null),
      title: Text(
        AppLanguage.instance.text(labelAr, labelEn),
        style: TextStyle(
          color: selected ? cs.primary : null,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}
