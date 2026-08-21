import 'package:flutter/material.dart';
import 'core/app_state.dart';
import 'core/app_theme.dart';
import 'core/config.dart';
import 'services/remote_config_service.dart';
import 'services/analytics_service.dart';
import 'services/monitoring_service.dart';
import 'core/theme_controller.dart';
import 'core/app_language.dart';
import 'core/app_settings.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final theme = ThemeController();
  await theme.load();
  final language = AppLanguage.instance;
  await language.load();
  await AppSettings.instance.load();

  final state = AppState();
  await state.load();
  await MonitoringService.instance.initialize();

  // Remote configuration is fail-safe: a failed request returns all features disabled.
  final remoteConfigService = RemoteConfigService();
  final fetchedConfig = await remoteConfigService.fetch();
  // Ads/analytics remain disabled by the current release policy. Video is
  // controlled by backend configuration and must only be enabled for an
  // authorized provider.
  final remoteConfig = fetchedConfig.copyWith(ads: false, analytics: false);

  final analytics = remoteConfig.analytics
      ? RemoteAnalyticsService()
      : NoOpAnalyticsService();
  await analytics.initialize();
  await analytics.track('app_open');

  runApp(
    AnimePlatformApp(
      theme: theme,
      language: language,
      state: state,
      remoteConfig: remoteConfig,
      analytics: analytics,
    ),
  );
}

class AnimePlatformApp extends StatelessWidget {
  final ThemeController theme;
  final AppLanguage language;
  final AppState state;
  final RemoteConfig remoteConfig;
  final AnalyticsService analytics;

  const AnimePlatformApp({
    super.key,
    required this.theme,
    required this.language,
    required this.state,
    required this.remoteConfig,
    required this.analytics,
  });

  ThemeData _theme(Brightness brightness) => buildAppTheme(brightness);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([theme, language]),
      builder: (_, __) => MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        themeMode: theme.mode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        builder: (context, child) => Directionality(
          textDirection: language.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        ),
        home: HomeScreen(
          state: state,
          theme: theme,
          remoteConfig: remoteConfig,
          analytics: analytics,
        ),
      ),
    );
  }
}
