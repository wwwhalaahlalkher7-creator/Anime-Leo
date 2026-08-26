import 'package:flutter/material.dart';
import '../models/anime.dart';
import '../core/app_language.dart';
import '../core/app_settings.dart';
import '../widgets/ad_slot.dart';
import '../services/video_provider.dart';

class PlayerScreen extends StatefulWidget {
  final Anime anime;
  final int episodeNumber;
  final VideoProvider videoProvider;

  const PlayerScreen({
    super.key,
    required this.anime,
    required this.episodeNumber,
    this.videoProvider = const NoOpVideoProvider(),
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Only used when the Settings > Player preference is "ask every time" —
  // the choice is per-visit, not persisted (see docs/SETTINGS_SIDEBAR_PLAN.md,
  // Phase 5).
  PlayerPreference? _sessionChoice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLanguage.instance.text('${widget.anime.title} • الحلقة ${widget.episodeNumber}', '${widget.anime.title} • Episode ${widget.episodeNumber}')),
      ),
      body: FutureBuilder<VideoAsset?>(
        future: widget.videoProvider.getEpisodeVideo(animeId: widget.anime.id, episodeNumber: widget.episodeNumber),
        builder: (context, snapshot) {
          final asset = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Icon(
                    asset == null ? Icons.lock_outline_rounded : Icons.play_circle_outline_rounded,
                    size: 80,
                    color: Colors.white38,
                  ),
                ),
              ),
              const AdSlot(height: 70),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: asset == null ? _unavailableContent(context) : _readyContent(context, asset),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _unavailableContent(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.verified_user_outlined, size: 36),
        const SizedBox(height: 12),
        Text(
          AppLanguage.instance.text('الفيديو غير متاح حاليًا', 'Video is currently unavailable'),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          AppLanguage.instance.text(
            'تم تجهيز بنية الفيديو القانونية. لن يتم استخدام أو تشغيل مصادر غير مصرح بها. عند ربط مزود مرخص، سيظهر الفيديو هنا تلقائيًا.',
            'The legal video architecture is ready. Unauthorized sources will not be used. A licensed provider will appear here when connected.',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
      ],
    );
  }

  /// Respects the Settings > Player preference (Phase 5). Built-in playback
  /// works today; external playback still needs an Android intent/plugin
  /// dependency, so it's surfaced but not actually launched yet.
  Widget _readyContent(BuildContext context, VideoAsset asset) {
    final preference = _sessionChoice ?? AppSettings.instance.playerPreference;

    if (preference == PlayerPreference.askEveryTime && _sessionChoice == null) {
      return Column(
        children: [
          Icon(Icons.play_arrow_rounded, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            AppLanguage.instance.text('كيف تريد المشاهدة؟', 'How would you like to watch?'),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => setState(() => _sessionChoice = PlayerPreference.builtIn),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(AppLanguage.instance.text('المشغّل المدمج', 'Built-in player')),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _sessionChoice = PlayerPreference.external),
                icon: const Icon(Icons.open_in_new),
                label: Text(AppLanguage.instance.text('مشغّل خارجي', 'External player')),
              ),
            ],
          ),
        ],
      );
    }

    if (preference == PlayerPreference.external) {
      return Column(
        children: [
          Icon(Icons.open_in_new, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            AppLanguage.instance.text('مشغّل خارجي', 'External player'),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLanguage.instance.text(
              'المصدر: ${asset.provider}. فتح مشغّل خارجي مثل MX Player تلقائيًا يحتاج إضافة اعتمادية Android intent لاحقًا؛ هذه الخطوة غير مفعّلة بعد.',
              'Source: ${asset.provider}. Automatically opening an external player like MX Player needs an Android intent dependency added later; this step isn\'t wired up yet.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
      );
    }

    return Column(
      children: [
        const Icon(Icons.play_arrow_rounded, size: 36),
        const SizedBox(height: 12),
        Text(
          AppLanguage.instance.text('مصدر فيديو مصرح به جاهز للتشغيل', 'An authorized video source is ready'),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          AppLanguage.instance.text('المصدر: ${asset.provider}', 'Source: ${asset.provider}'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
      ],
    );
  }
}

