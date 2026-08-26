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
import 'screens/intro_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final theme = ThemeController();
  final language = AppLanguage.instance;
  final state = AppState();

  // Start the UI immediately. Settings, local state and remote config load in
  // the background while the intro video is playing.
  runApp(
    AnimePlatformApp(
      theme: theme,
      language: language,
      state: state,
    ),
  );
}

class AnimePlatformApp extends StatefulWidget {
  final ThemeController theme;
  final AppLanguage language;
  final AppState state;

  const AnimePlatformApp({
    super.key,
    required this.theme,
    required this.language,
    required this.state,
  });

  @override
  State<AnimePlatformApp> createState() => _AnimePlatformAppState();
}

class _AnimePlatformAppState extends State<AnimePlatformApp> {
  RemoteConfig _remoteConfig = RemoteConfig.disabled;
  AnalyticsService _analytics = NoOpAnalyticsService();

  @override
  void initState() {
    super.initState();
    _bootstrapInBackground();
  }

  Future<void> _bootstrapInBackground() async {
    final remoteConfigService = RemoteConfigService();

    final results = await Future.wait<dynamic>([
      widget.theme.load(),
      widget.language.load(),
      AppSettings.instance.load(),
      widget.state.load(),
      MonitoringService.instance.initialize(),
      remoteConfigService.fetch(),
    ]);

    final fetchedConfig = results[5] as RemoteConfig;
    // Keep the existing release policy: ads/analytics/video stay disabled.
    final remoteConfig = fetchedConfig.copyWith(
      ads: false,
      analytics: false,
      video: false,
    );

    final analytics = remoteConfig.analytics
        ? RemoteAnalyticsService()
        : NoOpAnalyticsService();
    await analytics.initialize();
    await analytics.track('app_open');

    if (!mounted) return;
    setState(() {
      _remoteConfig = remoteConfig;
      _analytics = analytics;
    });
  }

  ThemeData _theme(Brightness brightness) => buildAppTheme(brightness);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.theme, widget.language]),
      builder: (_, __) => MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        themeMode: widget.theme.mode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        builder: (context, child) => Directionality(
          textDirection: widget.language.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        ),
        home: IntroScreen(
          state: widget.state,
          theme: widget.theme,
          remoteConfig: _remoteConfig,
          analytics: _analytics,
        ),
      ),
    );
  }
}
