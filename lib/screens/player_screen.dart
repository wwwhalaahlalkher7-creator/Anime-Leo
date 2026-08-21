import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../core/app_language.dart';
import '../core/app_settings.dart';
import '../models/anime.dart';
import '../services/video_provider.dart';
import '../services/storage_service.dart';
import '../core/link_launcher.dart';
import '../widgets/ad_slot.dart';

class PlayerScreen extends StatefulWidget {
  final Anime anime;
  final int episodeNumber;
  final int? previousEpisodeNumber;
  final int? nextEpisodeNumber;
  final VideoProvider? videoProvider;
  final String? localFilePath;

  const PlayerScreen({
    super.key,
    required this.anime,
    required this.episodeNumber,
    this.previousEpisodeNumber,
    this.nextEpisodeNumber,
    this.videoProvider,
    this.localFilePath,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;
  const _SubtitleCue(this.start, this.end, this.text);

  bool contains(Duration position) => position >= start && position <= end;
}

class _PlayerScreenState extends State<PlayerScreen> {
  PlayerPreference? _sessionChoice;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  VideoAsset? _asset;
  List<VideoAsset> _availableAssets = const [];
  int _selectedSource = 0;
  Object? _error;
  bool _loading = true;
  final StorageService _storage = StorageService();
  Duration _lastSavedPosition = Duration.zero;
  bool _progressLoaded = false;
  List<_SubtitleCue> _subtitleCues = const [];
  String? _activeSubtitle;
  Timer? _subtitleTimer;
  Timer? _nextTimer;
  int _nextCountdown = 5;
  bool _autoNextStarted = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    _cancelNextTimer();
    setState(() {
      _loading = true;
      _error = null;
      _subtitleCues = const [];
      _activeSubtitle = null;
      _autoNextStarted = false;
    });
    final primaryColor = Theme.of(context).colorScheme.primary;

    try {
      if (widget.localFilePath != null && File(widget.localFilePath!).existsSync()) {
        final asset = VideoAsset(streamUrl: 'file://${widget.localFilePath}', provider: 'offline');
        await _initializeLocalController(widget.localFilePath!, primaryColor);
        if (!mounted) return;
        setState(() { _asset = asset; _availableAssets = [asset]; _loading = false; });
        return;
      }
      final provider = widget.videoProvider ?? BackendVideoProvider();
      final assets = await provider.getEpisodeVideos(
        animeId: widget.anime.malId ?? widget.anime.id,
        episodeNumber: widget.episodeNumber,
      );
      if (!mounted) return;
      final asset = assets.isEmpty ? null : _selectAsset(assets);
      if (asset == null || asset.streamUrl.trim().isEmpty) {
        setState(() {
          _asset = null;
          _availableAssets = assets;
          _loading = false;
        });
        return;
      }
      await _initializeController(asset, primaryColor, restoreProgress: true);
      if (!mounted) return;
      setState(() {
        _availableAssets = assets;
        _selectedSource = assets.contains(asset) ? assets.indexOf(asset) : 0;
        _asset = asset;
        _loading = false;
      });
      await _loadPreferredSubtitle(asset);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _initializeLocalController(String path, Color primaryColor) async {
    final oldController = _videoController;
    final oldChewie = _chewieController;
    _videoController = null;
    _chewieController = null;
    oldChewie?.dispose();
    await oldController?.dispose();
    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    _progressLoaded = true;
    _lastSavedPosition = Duration.zero;
    controller.addListener(_onVideoChanged);
    final chewie = ChewieController(
      videoPlayerController: controller,
      autoPlay: true, looping: false, allowFullScreen: true, allowPlaybackSpeedChanging: true, showControls: true,
      materialProgressColors: ChewieProgressColors(playedColor: primaryColor, handleColor: primaryColor),
    );
    _videoController = controller;
    _chewieController = chewie;
  }

  Future<void> _initializeController(
    VideoAsset asset,
    Color primaryColor, {
    required bool restoreProgress,
  }) async {
    final uri = Uri.tryParse(asset.streamUrl);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const FormatException('Invalid video URL');
    }
    final oldController = _videoController;
    final oldChewie = _chewieController;
    _videoController = null;
    _chewieController = null;
    oldChewie?.dispose();
    await oldController?.dispose();

    final controller = VideoPlayerController.networkUrl(uri);
    try {
      await controller.initialize();
      if (restoreProgress) {
        final saved = await _storage.loadWatchProgress(widget.anime.id, widget.episodeNumber);
        if (saved != null && saved.positionSeconds > 5 && !saved.completed) {
          final target = Duration(seconds: saved.positionSeconds);
          if (target < controller.value.duration) await controller.seekTo(target);
        }
      }
      _progressLoaded = true;
      _lastSavedPosition = Duration.zero;
      controller.addListener(_onVideoChanged);
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: primaryColor,
          handleColor: primaryColor,
        ),
      );
      if (!mounted) {
        chewie.dispose();
        await controller.dispose();
        return;
      }
      _videoController = controller;
      _chewieController = chewie;
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  VideoAsset _selectAsset(List<VideoAsset> assets) {
    final quality = AppSettings.instance.defaultQuality.toLowerCase();
    if (quality == 'auto') return assets.first;
    for (final asset in assets) {
      for (final q in asset.qualities) {
        if (q.label.toLowerCase().contains(quality)) {
          return VideoAsset(
            streamUrl: q.url,
            provider: asset.provider,
            subtitles: asset.subtitles,
            qualities: asset.qualities,
            mimeType: asset.mimeType,
          );
        }
      }
    }
    return assets.first;
  }

  VideoAsset _applyQuality(VideoAsset asset, String quality) {
    if (quality == 'auto') return asset;
    for (final q in asset.qualities) {
      if (q.label.toLowerCase().contains(quality.toLowerCase())) {
        return VideoAsset(
          streamUrl: q.url,
          provider: asset.provider,
          subtitles: asset.subtitles,
          qualities: asset.qualities,
          mimeType: asset.mimeType,
        );
      }
    }
    return asset;
  }

  Future<void> _selectSource(VideoAsset rawAsset, int index) async {
    final asset = _applyQuality(rawAsset, AppSettings.instance.defaultQuality);
    try {
      setState(() => _loading = true);
      await _initializeController(asset, Theme.of(context).colorScheme.primary, restoreProgress: false);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _asset = asset;
        _selectedSource = index;
        _error = null;
      });
      await _loadPreferredSubtitle(asset);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadPreferredSubtitle(VideoAsset asset) async {
    _subtitleTimer?.cancel();
    final preferred = AppSettings.instance.subtitleLanguage.toLowerCase();
    VideoSubtitle? selected;
    for (final sub in asset.subtitles) {
      final lang = sub.language.toLowerCase();
      if (lang == preferred || lang.startsWith('$preferred-') || lang.startsWith(preferred)) {
        selected = sub;
        break;
      }
    }
    selected ??= asset.subtitles.isNotEmpty ? asset.subtitles.first : null;
    if (selected == null) return;
    try {
      final response = await http.get(Uri.parse(selected.url)).timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final cues = _parseSubtitle(response.body);
      if (!mounted) return;
      setState(() => _subtitleCues = cues);
      _subtitleTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;
        final position = _videoController!.value.position;
        String? active;
        for (final cue in _subtitleCues) {
          if (cue.contains(position)) {
            active = cue.text;
            break;
          }
        }
        if (active != _activeSubtitle && mounted) setState(() => _activeSubtitle = active);
      });
    } catch (_) {
      // Subtitles are optional; playback must continue if the subtitle URL fails.
    }
  }

  List<_SubtitleCue> _parseSubtitle(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    final cues = <_SubtitleCue>[];
    for (final block in blocks) {
      final lines = block.split('\n').map((e) => e.trimRight()).toList();
      final timingIndex = lines.indexWhere((line) => line.contains('-->'));
      if (timingIndex < 0) continue;
      final timing = lines[timingIndex].split('-->');
      if (timing.length < 2) continue;
      final start = _parseTimestamp(timing[0].trim());
      final end = _parseTimestamp(timing[1].trim().split(' ').first);
      if (start == null || end == null || end <= start) continue;
      final text = lines.skip(timingIndex + 1).join('\n').trim();
      if (text.isNotEmpty) cues.add(_SubtitleCue(start, end, _stripTags(text)));
    }
    return cues;
  }

  String _stripTags(String value) => value.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>');

  Duration? _parseTimestamp(String value) {
    final m = RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{2})[\.,](\d{3})$').firstMatch(value);
    if (m == null) return null;
    final hours = int.tryParse(m.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(m.group(2)!) ?? 0;
    final seconds = int.tryParse(m.group(3)!) ?? 0;
    final millis = int.tryParse(m.group(4)!) ?? 0;
    return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  void _onVideoChanged() {
    final controller = _videoController;
    if (controller == null || !_progressLoaded || !controller.value.isInitialized) return;
    final position = controller.value.position;
    if ((position - _lastSavedPosition).inSeconds.abs() >= 8) {
      _lastSavedPosition = position;
      _persistProgress(position, controller.value.duration);
    }
    final duration = controller.value.duration;
    if (!_autoNextStarted && widget.nextEpisodeNumber != null && duration > Duration.zero && position.inMilliseconds / duration.inMilliseconds >= .90) {
      _startAutoNext();
    }
  }

  void _startAutoNext() {
    if (_autoNextStarted || widget.nextEpisodeNumber == null) return;
    _autoNextStarted = true;
    _nextCountdown = 5;
    setState(() {});
    _nextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_nextCountdown <= 1) {
        timer.cancel();
        _openNextEpisode();
      } else {
        setState(() => _nextCountdown--);
      }
    });
  }

  void _cancelNextTimer() {
    _nextTimer?.cancel();
    _nextTimer = null;
  }

  Future<void> _openNextEpisode() async {
    final next = widget.nextEpisodeNumber;
    if (next == null || !mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          anime: widget.anime,
          episodeNumber: next,
          previousEpisodeNumber: widget.episodeNumber,
          videoProvider: widget.videoProvider,
        ),
      ),
    );
  }

  Future<void> _openEpisode(int number) async {
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          anime: widget.anime,
          episodeNumber: number,
          previousEpisodeNumber: number < widget.episodeNumber ? number - 1 : widget.episodeNumber,
          nextEpisodeNumber: number > widget.episodeNumber ? number + 1 : widget.nextEpisodeNumber,
          videoProvider: widget.videoProvider,
        ),
      ),
    );
  }

  Future<void> _persistProgress(Duration position, Duration duration) async {
    final completed = duration.inMilliseconds > 0 && position.inMilliseconds / duration.inMilliseconds >= .90;
    await _storage.saveWatchProgress(WatchProgress(
      animeId: widget.anime.malId ?? widget.anime.id,
      episode: widget.episodeNumber,
      positionSeconds: position.inSeconds,
      durationSeconds: duration.inSeconds,
      updatedAt: DateTime.now(),
      completed: completed,
    ));
  }

  @override
  void dispose() {
    _cancelNextTimer();
    _subtitleTimer?.cancel();
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      _persistProgress(controller.value.position, controller.value.duration);
      controller.removeListener(_onVideoChanged);
    }
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLanguage.instance.text('${widget.anime.title} • الحلقة ${widget.episodeNumber}', '${widget.anime.title} • Episode ${widget.episodeNumber}')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [
              _buildPlayer(),
              if (_nextTimer?.isActive == true) _buildNextOverlay(),
              const AdSlot(height: 70),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Card(child: Padding(padding: const EdgeInsets.all(18), child: _asset == null ? _unavailableContent(context) : _readyContent(context, _asset!))),
              ),
            ]),
    );
  }

  Widget _buildPlayer() {
    if (_error != null) {
      return AspectRatio(aspectRatio: 16 / 9, child: Container(color: Colors.black, alignment: Alignment.center, padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, color: Colors.white70, size: 42),
        const SizedBox(height: 12),
        const Text('تعذر تشغيل الفيديو.', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _loadVideo, icon: const Icon(Icons.refresh), label: Text(AppLanguage.instance.text('إعادة المحاولة', 'Retry'))),
      ])));
    }
    if (_chewieController == null || _videoController == null || !_videoController!.value.isInitialized) {
      return const AspectRatio(aspectRatio: 16 / 9, child: ColoredBox(color: Colors.black));
    }
    return Stack(alignment: Alignment.bottomCenter, children: [
      AspectRatio(aspectRatio: _videoController!.value.aspectRatio == 0 ? 16 / 9 : _videoController!.value.aspectRatio, child: Chewie(controller: _chewieController!)),
      if (_activeSubtitle != null && _activeSubtitle!.trim().isNotEmpty)
        Positioned(left: 18, right: 18, bottom: 44, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(color: Colors.black.withValues(alpha: .72), borderRadius: BorderRadius.circular(8)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), child: Text(_activeSubtitle!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)))))),
    ]);
  }

  Widget _buildNextOverlay() => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), child: Card(child: ListTile(leading: const Icon(Icons.skip_next), title: Text(AppLanguage.instance.text('الحلقة التالية', 'Next episode')), subtitle: Text(AppLanguage.instance.text('سيتم تشغيل الحلقة ${widget.nextEpisodeNumber} خلال $_nextCountdown ثوانٍ', 'Episode ${widget.nextEpisodeNumber} starts in $_nextCountdown seconds')), trailing: TextButton(onPressed: () { _cancelNextTimer(); setState(() => _autoNextStarted = true); }, child: Text(AppLanguage.instance.text('إلغاء', 'Cancel'))))));

  Widget _unavailableContent(BuildContext context) => Column(children: [
    const Icon(Icons.video_library_outlined, size: 36), const SizedBox(height: 12),
    Text(AppLanguage.instance.text('الفيديو غير متاح حاليًا', 'Video is currently unavailable'), style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
    const SizedBox(height: 8), Text(AppLanguage.instance.text('لا يوجد رابط فيديو صالح من مزود المحتوى المصرح به.', 'No valid video URL was returned by the authorized content provider.'), textAlign: TextAlign.center),
  ]);

  Widget _readyContent(BuildContext context, VideoAsset asset) {
    final sourceButton = _availableAssets.length > 1 ? OutlinedButton.icon(onPressed: _showSources, icon: const Icon(Icons.swap_horiz), label: Text(AppLanguage.instance.text('المصادر', 'Sources'))) : const SizedBox.shrink();
    final preference = _sessionChoice ?? AppSettings.instance.playerPreference;
    return Column(children: [
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          if (widget.previousEpisodeNumber != null) IconButton(tooltip: AppLanguage.instance.text('الحلقة السابقة', 'Previous episode'), onPressed: () => _openEpisode(widget.previousEpisodeNumber!), icon: const Icon(Icons.skip_previous)),
          sourceButton,
          if (asset.qualities.length > 1) OutlinedButton.icon(onPressed: () => _showQualities(asset), icon: const Icon(Icons.high_quality_outlined), label: Text(asset.qualities.firstWhere((q) => q.url == asset.streamUrl, orElse: () => asset.qualities.first).label)),
          if (widget.nextEpisodeNumber != null) IconButton(tooltip: AppLanguage.instance.text('الحلقة التالية', 'Next episode'), onPressed: () => _openEpisode(widget.nextEpisodeNumber!), icon: const Icon(Icons.skip_next)),
        ],
      ),
      const SizedBox(height: 8),
      Text(AppLanguage.instance.text('المصدر: ${asset.provider}', 'Source: ${asset.provider}'), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      if (asset.subtitles.isNotEmpty) Text(AppLanguage.instance.text('الترجمة: ${AppSettings.instance.subtitleLanguage.toUpperCase()}', 'Subtitle: ${AppSettings.instance.subtitleLanguage.toUpperCase()}')),
      const SizedBox(height: 8),
      if (preference == PlayerPreference.askEveryTime) Wrap(spacing: 10, children: [
        FilledButton.icon(onPressed: () => setState(() => _sessionChoice = PlayerPreference.builtIn), icon: const Icon(Icons.play_circle_outline), label: Text(AppLanguage.instance.text('المشغّل المدمج', 'Built-in'))),
        OutlinedButton.icon(onPressed: () => setState(() => _sessionChoice = PlayerPreference.external), icon: const Icon(Icons.open_in_new), label: Text(AppLanguage.instance.text('مشغّل خارجي', 'External'))),
      ])
      else if (preference == PlayerPreference.external) FilledButton.icon(onPressed: () => LinkLauncher.openVideoExternal(context, asset.streamUrl), icon: const Icon(Icons.open_in_new), label: Text(AppLanguage.instance.text('فتح في مشغل خارجي', 'Open externally')))
      else const Icon(Icons.verified_outlined),
    ]);
  }

  Future<void> _showQualities(VideoAsset asset) async {
    final options = asset.qualities.where((q) => q.url.isNotEmpty).toList();
    if (options.length < 2 || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLanguage.instance.text('جودة الفيديو', 'Video quality'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            ...options.map((quality) => ListTile(
              leading: Icon(quality.url == asset.streamUrl
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(quality.label.isEmpty ? 'Auto' : quality.label),
              onTap: () async {
                Navigator.pop(context);
                await _selectQuality(asset, quality);
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _selectQuality(VideoAsset asset, VideoQuality quality) async {
    final selected = VideoAsset(
      streamUrl: quality.url,
      provider: asset.provider,
      subtitles: asset.subtitles,
      qualities: asset.qualities,
      mimeType: asset.mimeType,
    );
    try {
      setState(() => _loading = true);
      await _initializeController(
        selected,
        Theme.of(context).colorScheme.primary,
        restoreProgress: false,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _asset = selected;
        _error = null;
      });
      await _loadPreferredSubtitle(selected);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _showSources() async {
    if (_availableAssets.length < 2 || !mounted) return;
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.all(16), child: Text(AppLanguage.instance.text('مصادر المشاهدة', 'Video sources'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
      ..._availableAssets.asMap().entries.map((entry) {
        final i = entry.key; final asset = entry.value;
        return ListTile(leading: Icon(i == _selectedSource ? Icons.radio_button_checked : Icons.radio_button_off), title: Text(asset.provider), subtitle: Text(AppLanguage.instance.text('مترجم • Sub', 'Subtitled • Sub')), onTap: () async { Navigator.pop(context); await _selectSource(asset, i); });
      }),
    ])));
  }
}
