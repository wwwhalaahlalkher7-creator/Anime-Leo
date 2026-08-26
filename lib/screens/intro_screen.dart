import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/app_state.dart';
import '../core/theme_controller.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../services/startup_preloader.dart';
import 'home_screen.dart';

class IntroScreen extends StatefulWidget {
  final AppState state;
  final ThemeController theme;
  final RemoteConfig remoteConfig;
  final AnalyticsService analytics;

  const IntroScreen({
    super.key,
    required this.state,
    required this.theme,
    required this.remoteConfig,
    required this.analytics,
  });

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _dataReady = false;
  bool _showLogo = false;
  bool _videoFinished = false;
  bool _logoHoldComplete = false;
  bool _leaving = false;
  Timer? _safetyTimer;
  Timer? _logoHoldTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _start();
  }

  Future<void> _start() async {
    final controller = VideoPlayerController.asset('assets/intro/anime_leo_intro.mp4');
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0.0);
      if (!mounted) return;
      setState(() => _videoReady = true);
      await controller.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _videoReady = false;
          _videoFinished = true;
          _logoHoldComplete = true;
        });
      }
    }

    final preloadFuture = StartupPreloader.instance.start();
    preloadFuture.whenComplete(() {
      if (mounted) setState(() => _dataReady = true);
      _precacheImages();
    });

    // Never leave the user on the intro forever if a provider is unavailable.
    _safetyTimer = Timer(const Duration(seconds: 12), () => _goHome(force: true));

    controller.addListener(_onVideoChanged);
  }

  Future<void> _precacheImages() async {
    if (!mounted) return;
    final urls = StartupPreloader.instance.imageUrls.take(12);
    try {
      await Future.wait(
        urls.map((url) => precacheImage(NetworkImage(url), context)),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {
      // Individual image failures must not block startup.
    }
    if (mounted) {
      _goHome();
    }
  }

  void _onVideoChanged() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final remaining = controller.value.duration - controller.value.position;
    final shouldShowLogo = remaining <= const Duration(milliseconds: 1200);
    if (shouldShowLogo != _showLogo && mounted) {
      setState(() => _showLogo = shouldShowLogo);
    }
    if (controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      if (!_videoFinished && mounted) {
        setState(() => _videoFinished = true);
        _logoHoldTimer?.cancel();
        _logoHoldTimer = Timer(const Duration(milliseconds: 750), () {
          if (mounted) {
            setState(() => _logoHoldComplete = true);
            _goHome();
          }
        });
      }
      _goHome();
    }
  }

  void _goHome({bool force = false}) {
    if (_leaving || !mounted) return;

    // Normal navigation waits for both sides of startup: the full intro video
    // and the warm home-data cache. The safety timeout can bypass this only
    // when a provider or the video itself is stuck.
    if (!force && (!_videoFinished || !_dataReady || !_logoHoldComplete)) return;

    _leaving = true;
    _safetyTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => HomeScreen(
          state: widget.state,
          theme: widget.theme,
          remoteConfig: widget.remoteConfig,
          analytics: widget.analytics,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _logoHoldTimer?.cancel();
    _controller?.removeListener(_onVideoChanged);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final showFallback = !_videoReady || controller == null;

    return Scaffold(
      backgroundColor: const Color(0xFF05030A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!showFallback)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else
            const ColoredBox(color: Color(0xFF05030A)),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _videoReady ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 250),
              child: Center(
                child: Image.asset(
                  'assets/anime_leo_icon.png',
                  width: 112,
                  height: 112,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showLogo ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 350),
              child: Center(
                child: AnimatedScale(
                  scale: _showLogo ? 1.0 : 0.88,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 270,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xD905030A),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x993B14FF),
                          blurRadius: 36,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/anime_leo_logo.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_videoReady && !_dataReady)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
