import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_state.dart';
import '../core/theme_controller.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../services/startup_preloader.dart';
import 'home_screen.dart';

/// Lightweight startup screen: no intro video and no secondary logo.
class IntroScreen extends StatefulWidget {
  final AppState state;
  final ThemeController theme;
  final RemoteConfig remoteConfig;
  final AnalyticsService analytics;

  const IntroScreen({super.key, required this.state, required this.theme, required this.remoteConfig, required this.analytics});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  bool _dataReady = false;
  bool _leaving = false;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _start();
  }

  Future<void> _start() async {
    final preloadFuture = StartupPreloader.instance.start();
    preloadFuture.whenComplete(() {
      if (!mounted) return;
      setState(() => _dataReady = true);
      _precacheImages();
    });
    _safetyTimer = Timer(const Duration(seconds: 8), () => _goHome(force: true));
  }

  Future<void> _precacheImages() async {
    if (!mounted) return;
    final urls = StartupPreloader.instance.imageUrls.take(12);
    try {
      await Future.wait(urls.map((url) => precacheImage(NetworkImage(url), context))).timeout(const Duration(seconds: 4));
    } catch (_) {}
    if (mounted) _goHome();
  }

  void _goHome({bool force = false}) {
    if (_leaving || !mounted || (!force && !_dataReady)) return;
    _leaving = true;
    _safetyTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => HomeScreen(state: widget.state, theme: widget.theme, remoteConfig: widget.remoteConfig, analytics: widget.analytics),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF05030A),
    body: Center(
      child: AnimatedScale(
        scale: _dataReady ? 1.0 : .92,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 300),
          child: Image.asset('assets/anime_leo_icon.png', width: 112, height: 112, fit: BoxFit.contain),
        ),
      ),
    ),
  );
}
