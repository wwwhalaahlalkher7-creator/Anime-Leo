import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/app_language.dart';
import '../models/anime.dart';
import '../repositories/anime_repository.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../services/translation_service.dart';
import '../widgets/ad_slot.dart';
import '../widgets/cached_anime_image.dart';
import '../widgets/ui_states.dart';
import 'player_screen.dart';
import '../core/link_launcher.dart';

class AnimeDetailsScreen extends StatefulWidget {
  final Anime anime;
  final AppState state;
  final RemoteConfig remoteConfig;
  final AnalyticsService analytics;

  const AnimeDetailsScreen({
    super.key,
    required this.anime,
    required this.state,
    required this.remoteConfig,
    required this.analytics,
  });

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  final repository = AnimeRepository();
  late Future<Anime> detailsFuture;
  late Future<AnimeEpisodesPage> episodesFuture;
  final List<Map<String, dynamic>> episodes = [];
  int episodePage = 1;
  bool episodesLoadingMore = false;
  bool episodesHasNext = false;
  String? episodesError;
  bool _showFullSynopsis = false;
  String? _arabicSynopsis;
  bool _arabicTranslationLoading = false;
  bool _arabicAttempted = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _prepareArabicSynopsis();
    widget.analytics.track('anime_open', parameters: {'anime_id': widget.anime.id});
  }

  void _reload() {
    detailsFuture = repository.getDetails(widget.anime.id);
    episodesFuture = repository.getEpisodes(widget.anime.id);
  }

  Future<void> _prepareArabicSynopsis() async {
    if (!AppLanguage.instance.isArabic || _arabicAttempted) return;
    _arabicAttempted = true;
    if (mounted) setState(() => _arabicTranslationLoading = true);
    try {
      final anime = await detailsFuture;
      final source = anime.synopsis?.trim() ?? '';
      if (source.isEmpty) {
        if (mounted) setState(() => _arabicTranslationLoading = false);
        return;
      }
      final translated = await TranslationService.instance.toArabic(
        animeId: anime.id,
        text: source,
      );
      if (!mounted) return;
      setState(() {
        _arabicTranslationLoading = false;
        _arabicSynopsis = translated?.trim().isNotEmpty == true ? translated!.trim() : null;
      });
    } catch (_) {
      if (mounted) setState(() => _arabicTranslationLoading = false);
    }
  }

  Future<void> _retryAll() async {
    setState(() {
      _reload();
      episodes.clear();
      episodePage = 1;
      episodesHasNext = false;
      episodesError = null;
    });
  }

  Future<void> _loadMoreEpisodes() async {
    if (episodesLoadingMore || !episodesHasNext) return;
    setState(() => episodesLoadingMore = true);
    try {
      final nextPage = await repository.getEpisodes(widget.anime.id, page: episodePage + 1);
      if (!mounted) return;
      setState(() {
        episodePage = nextPage.page;
        episodes.addAll(nextPage.items);
        episodesHasNext = nextPage.hasNextPage;
        episodesLoadingMore = false;
        episodesError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        episodesLoadingMore = false;
        episodesError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Anime>(
      future: detailsFuture,
      builder: (context, details) {
        final anime = details.data ?? widget.anime;
        final loadingDetails = details.connectionState == ConnectionState.waiting && details.data == null;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _retryAll,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  actions: [
                    AnimatedBuilder(
                      animation: widget.state,
                      builder: (_, __) => IconButton(
                        tooltip: widget.state.isFavorite(anime) ? AppLanguage.instance.text('إزالة من المفضلة', 'Remove from favorites') : AppLanguage.instance.text('إضافة إلى المفضلة', 'Add to favorites'),
                        onPressed: () => widget.state.toggleFavorite(anime),
                        icon: Icon(widget.state.isFavorite(anime) ? Icons.favorite : Icons.favorite_border),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(_displayTitle(anime), maxLines: 1, overflow: TextOverflow.ellipsis),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedAnimeImage(url: anime.image, fit: BoxFit.cover),
                        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xF205081A)]))),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (loadingDetails) const LinearProgressIndicator(minHeight: 2),
                        if (details.hasError && details.data == null)
                          InlineNotice(warning: true, icon: Icons.cloud_off_outlined, text: 'تعذر تحديث التفاصيل. يتم عرض البيانات المتاحة من القائمة أو الذاكرة المؤقتة.'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Chip('⭐ ${anime.score ?? '—'}'),
                            if (anime.year != null) _Chip('${anime.year}'),
                            if (anime.type != null) _Chip(anime.type!),
                            if (anime.episodes != null) _Chip('${anime.episodes} حلقة'),
                            if (anime.status != null) _Chip(anime.status!),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (anime.synopsis?.trim().isNotEmpty == true) ...[
                          Text(AppLanguage.instance.text('القصة', 'Synopsis'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          _SynopsisSection(
                            englishText: anime.synopsis!,
                            arabicText: _arabicSynopsis,
                            arabicLoading: _arabicTranslationLoading,
                            showFull: _showFullSynopsis,
                            onToggleFull: () => setState(() => _showFullSynopsis = !_showFullSynopsis),
                          ),
                        ] else
                          Text(AppLanguage.instance.text('لا يوجد وصف متاح.', 'No synopsis available.')),
                        if (anime.genres.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(AppLanguage.instance.text('التصنيفات', 'Genres'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 8, children: anime.genres.take(8).map((genre) => Chip(label: Text(_displayGenre(genre)))).toList()),
                        ],
                        AdSlot(enabled: widget.remoteConfig.ads),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: Text(AppLanguage.instance.text('الحلقات', 'Episodes'), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
                            if (episodes.isNotEmpty) Text('${episodes.length}${episodesHasNext ? '+' : ''}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder<AnimeEpisodesPage>(
                          future: episodesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                              return const _EpisodeLoading();
                            }
                            if (snapshot.hasData && episodes.isEmpty) {
                              episodes
                                ..clear()
                                ..addAll(snapshot.data!.items);
                              episodesHasNext = snapshot.data!.hasNextPage;
                              episodePage = snapshot.data!.page;
                            }
                            if (snapshot.hasError && episodes.isEmpty) {
                              return UiStateCard(icon: Icons.playlist_remove, title: 'تعذر تحميل الحلقات', message: 'قد تكون الحلقات غير متاحة مؤقتًا. يمكنك المحاولة مرة أخرى.', actionLabel: 'إعادة المحاولة', onAction: () => setState(() { episodesFuture = repository.getEpisodes(widget.anime.id); episodesError = null; }));
                            }
                            if (episodes.isEmpty) return UiStateCard(icon: Icons.video_library_outlined, title: AppLanguage.instance.text('لا توجد حلقات', 'No episodes'), message: 'لا توجد بيانات حلقات متاحة لهذا العنوان حاليًا.', compact: true);
                            return Column(
                              children: [
                                ...episodes.map(_episodeTile),
                                if (episodesError != null) InlineNotice(warning: true, icon: Icons.warning_amber_outlined, text: 'تعذر تحميل الصفحة التالية من الحلقات.'),
                                if (episodesHasNext)
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: episodesLoadingMore ? null : _loadMoreEpisodes,
                                      icon: episodesLoadingMore ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more),
                                      label: Text(episodesLoadingMore ? AppLanguage.instance.text('جارٍ التحميل...', 'Loading...') : AppLanguage.instance.text('تحميل المزيد', 'Load more')),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _displayTitle(Anime anime) {
    if (AppLanguage.instance.isArabic) {
      final arabic = anime.titleAr?.trim();
      if (arabic != null && arabic.isNotEmpty) return arabic;
    }
    return anime.title;
  }

  static String _displayGenre(String genre) {
    if (!AppLanguage.instance.isArabic) return genre;
    const map = <String, String>{
      'Action': 'أكشن', 'Adventure': 'مغامرة', 'Comedy': 'كوميديا', 'Drama': 'دراما',
      'Fantasy': 'فانتازيا', 'Romance': 'رومانسي', 'Sci-Fi': 'خيال علمي', 'Mystery': 'غموض',
      'Thriller': 'إثارة', 'Horror': 'رعب', 'Sports': 'رياضة', 'Supernatural': 'خارق للطبيعة',
      'Psychological': 'نفسي', 'Slice of Life': 'شريحة من الحياة', 'Historical': 'تاريخي',
      'Military': 'عسكري', 'School': 'مدرسي', 'Seinen': 'سينين', 'Shounen': 'شونين',
      'Josei': 'جوسي', 'Isekai': 'إيسيكاي', 'Mecha': 'ميكا', 'Music': 'موسيقى',
    };
    return map[genre] ?? genre;
  }

  Future<void> _showExternalSources(BuildContext context, int number, List<Map<String, dynamic>> sources) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLanguage.instance.text('مصادر المشاهدة الخارجية • الحلقة $number', 'External sources • Episode $number'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(AppLanguage.instance.text('سيتم فتح صفحة المصدر خارج التطبيق. التطبيق لا يستضيف أو يمرر الفيديو عبر خوادمه.', 'The source page will open outside the app. The app does not host or proxy the video.'), style: Theme.of(sheetContext).textTheme.bodySmall),
              const SizedBox(height: 12),
              ...sources.map((source) {
                final url = source['url']?.toString() ?? '';
                final provider = source['provider']?.toString() ?? 'External source';
                final label = source['label']?.toString().trim();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.open_in_new),
                  title: Text(label?.isNotEmpty == true ? label! : provider),
                  subtitle: Text(provider),
                  onTap: url.isEmpty ? null : () => LinkLauncher.open(sheetContext, url),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _episodeTile(Map<String, dynamic> episode) {
    final number = (episode['mal_id'] as num?)?.toInt() ?? (episode['episode'] as num?)?.toInt() ?? 0;
    final title = episode['title']?.toString().trim();
    final subtitle = episode['aired']?.toString().trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('$number')),
        title: Text(title?.isNotEmpty == true ? title! : 'الحلقة $number', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle?.isNotEmpty == true ? subtitle! : AppLanguage.instance.text('متاحة', 'Available')),
        trailing: const Icon(Icons.play_circle_outline),
        onTap: number <= 0 ? null : () async {
          widget.state.rememberEpisode(widget.anime, number);
          final sources = episode['sources'] is List
              ? (episode['sources'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : <Map<String, dynamic>>[];
          if (!context.mounted) return;
          if (sources.isNotEmpty) {
            await _showExternalSources(context, number, sources);
          } else {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(anime: widget.anime, episodeNumber: number)));
          }
        },
      ),
    );
  }
}

class _SynopsisSection extends StatelessWidget {
  final String englishText;
  final String? arabicText;
  final bool arabicLoading;
  final bool showFull;
  final VoidCallback onToggleFull;

  const _SynopsisSection({
    required this.englishText,
    required this.arabicText,
    required this.arabicLoading,
    required this.showFull,
    required this.onToggleFull,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLanguage.instance.isArabic;
    final clean = isArabic ? (arabicText?.trim() ?? '') : englishText.trim();

    // In Arabic mode the English synopsis is intentionally never shown while
    // translation is loading or unavailable.
    if (isArabic && clean.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (arabicLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('جارٍ تجهيز القصة بالعربية...'),
                ],
              ),
            )
          else
            const Text('لا تتوفر قصة باللغة العربية حاليًا.'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: Text(
            clean,
            maxLines: showFull ? null : 5,
            overflow: showFull ? TextOverflow.visible : TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(height: 1.75, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onToggleFull,
          icon: Icon(showFull ? Icons.expand_less : Icons.expand_more),
          label: Text(showFull ? 'إظهار أقل' : 'إظهار المزيد'),
        ),
      ],
    );
  }
}

class _EpisodeLoading extends StatelessWidget {
  const _EpisodeLoading();
  @override
  Widget build(BuildContext context) => Column(children: List.generate(5, (_) => const Card(child: ListTile(leading: CircleAvatar(child: SizedBox(width: 10, height: 10)), title: SizedBox(height: 12, child: LinearProgressIndicator()), subtitle: SizedBox(height: 10)))));
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );
}
