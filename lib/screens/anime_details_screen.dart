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
import '../core/link_launcher.dart';
import 'player_screen.dart';
import 'downloads_screen.dart';

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
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _reload();
    _prepareArabicSynopsis();
    widget.analytics.track('anime_open', parameters: {'anime_id': widget.anime.id});
  }

  void _reload() {
    detailsFuture = repository.getDetails(widget.anime.malId ?? widget.anime.id);
    episodesFuture = repository.getEpisodes(widget.anime.malId ?? widget.anime.id);
    _primeEpisodes(episodesFuture);
  }

  void _primeEpisodes(Future<AnimeEpisodesPage> future) {
    future.then((page) {
      if (!mounted) return;
      setState(() {
        if (episodes.isEmpty) episodes.addAll(page.items);
        episodePage = page.page;
        episodesHasNext = page.hasNextPage;
        episodesError = null;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() => episodesError = 'load');
    });
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
        animeId: anime.malId ?? anime.id,
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
      episodes.clear();
      episodePage = 1;
      episodesHasNext = false;
      episodesError = null;
      _reload();
    });
  }

  Future<void> _loadMoreEpisodes() async {
    if (episodesLoadingMore || !episodesHasNext) return;
    setState(() => episodesLoadingMore = true);
    try {
      final nextPage = await repository.getEpisodes(
        widget.anime.malId ?? widget.anime.id,
        page: episodePage + 1,
      );
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
                  expandedHeight: 285,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  actions: [
                    AnimatedBuilder(
                      animation: widget.state,
                      builder: (_, __) => IconButton(
                        tooltip: widget.state.isFavorite(anime)
                            ? AppLanguage.instance.text('إزالة من المفضلة', 'Remove from favorites')
                            : AppLanguage.instance.text('المفضلة', 'Favorite'),
                        onPressed: () => widget.state.toggleFavorite(anime),
                        icon: Icon(widget.state.isFavorite(anime) ? Icons.favorite : Icons.favorite_border),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLanguage.instance.text('مشاركة', 'Share'),
                      onPressed: () => _showComingSoon(context, 'المشاركة'),
                      icon: const Icon(Icons.share_outlined),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _HeroHeader(anime: anime),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeroSummary(anime: anime),
                          const SizedBox(height: 14),
                          if (loadingDetails) const LinearProgressIndicator(minHeight: 2),
                          if (details.hasError && details.data == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: InlineNotice(
                                warning: true,
                                icon: Icons.cloud_off_outlined,
                                text: 'تعذر تحديث التفاصيل. يتم عرض البيانات المتاحة من القائمة أو الذاكرة المؤقتة.',
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (_isUpcoming(anime)) _CountdownCard(anime: anime),
                          if (_isMature(anime)) ...[
                            const SizedBox(height: 12),
                            const _WarningCard(),
                          ],
                          const SizedBox(height: 12),
                          _PrimaryActions(
                            onPlay: episodes.isNotEmpty ? () => _openEpisode(episodes.first) : null,
                            onDownload: _isCompleted(anime) ? _openFullDownload : null,
                            isFavorite: widget.state.isFavorite(anime),
                            onFavorite: () => widget.state.toggleFavorite(anime),
                          ),
                          const SizedBox(height: 10),
                          _SecondaryActions(
                            onList: () => _showComingSoon(context, 'القائمة'),
                            onRating: () => _showComingSoon(context, 'التقييم'),
                            onBackgrounds: () => _showComingSoon(context, 'الخلفيات'),
                            onReviews: () => _showComingSoon(context, 'المراجعات'),
                            onComments: () => _showComingSoon(context, 'التعليقات'),
                          ),
                          const SizedBox(height: 12),
                          _MalCard(anime: anime),
                          const SizedBox(height: 16),
                          _InfoCard(anime: anime),
                          if (anime.synopsis?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: AppLanguage.instance.text('القصة', 'Synopsis'),
                              child: _SynopsisSection(
                                englishText: anime.synopsis!,
                                arabicText: _arabicSynopsis,
                                arabicLoading: _arabicTranslationLoading,
                                showFull: _showFullSynopsis,
                                onToggleFull: () => setState(() => _showFullSynopsis = !_showFullSynopsis),
                              ),
                            ),
                          ],
                          if (anime.genres.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: AppLanguage.instance.text('التصنيفات', 'Genres'),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: anime.genres.take(12).map((genre) => _Tag(_displayGenre(genre))).toList(),
                              ),
                            ),
                          ],
                          if (anime.trailerUrl != null) ...[
                            const SizedBox(height: 12),
                            _TrailerCard(anime: anime),
                          ],
                          if (widget.remoteConfig.ads) ...[
                            const SizedBox(height: 12),
                            AdSlot(enabled: widget.remoteConfig.ads),
                          ],
                          const SizedBox(height: 14),
                          _DetailsTabs(
                            selected: _selectedTab,
                            onChanged: (value) => setState(() => _selectedTab = value),
                          ),
                          const SizedBox(height: 14),
                          _buildTabContent(anime),
                          const SizedBox(height: 18),
                          _EpisodesSection(
                            episodes: episodes,
                            episodesHasNext: episodesHasNext,
                            episodesLoadingMore: episodesLoadingMore,
                            episodesError: episodesError,
                            onLoadMore: _loadMoreEpisodes,
                            onEpisode: _openEpisode,
                            onDownload: (episode) async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => DownloadsScreen(anime: anime, episodes: [episode], downloadWholeAnime: true)));
                            },
                          ),
                          const SizedBox(height: 36),
                        ],
                      ),
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

  Widget _buildTabContent(Anime anime) {
    if (_selectedTab == 0) return _CharacterSection(characters: anime.characters);
    if (_selectedTab == 1) return _RelatedSection(relations: anime.relations);
    return _RecommendationsSection(items: anime.recommendations);
  }

  bool _isUpcoming(Anime anime) {
    final from = DateTime.tryParse(anime.airedFrom ?? '');
    final status = (anime.status ?? '').toLowerCase();
    if (from != null && from.isAfter(DateTime.now())) return true;
    return status.contains('currently') && anime.broadcastDay != null && anime.broadcastTime != null;
  }

  bool _isMature(Anime anime) {
    final rating = (anime.rating ?? '').toLowerCase();
    return rating.contains('r - 17') || rating.contains('rx') || rating.contains('18');
  }

  bool _isCompleted(Anime anime) {
    if ((anime.type ?? '').toLowerCase() == 'movie') return true;
    final status = (anime.status ?? '').toLowerCase();
    return status.contains('finished') || status.contains('complete');
  }

  Future<void> _openFullDownload() async {
    final all = <Map<String, dynamic>>[];
    var page = 1;
    var hasNext = true;
    while (hasNext) {
      final result = await repository.getEpisodes(widget.anime.malId ?? widget.anime.id, page: page, limit: 24);
      all.addAll(result.items);
      hasNext = result.hasNextPage;
      page++;
      if (page > 100) break;
    }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DownloadsScreen(
      anime: widget.anime,
      episodes: all,
      downloadWholeAnime: true,
    )));
  }

  void _openEpisode(Map<String, dynamic> episode) async {
    final number = (episode['mal_id'] as num?)?.toInt() ?? (episode['episode'] as num?)?.toInt() ?? 0;
    if (number <= 0) return;
    final numbers = episodes
        .map((e) => (e['mal_id'] as num?)?.toInt() ?? (e['episode'] as num?)?.toInt() ?? 0)
        .where((n) => n > 0)
        .toList();
    final index = numbers.indexOf(number);
    final previous = index > 0 ? numbers[index - 1] : null;
    final next = index >= 0 && index + 1 < numbers.length ? numbers[index + 1] : null;
    widget.state.rememberEpisode(widget.anime, number);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
      anime: widget.anime,
      episodeNumber: number,
      previousEpisodeNumber: previous,
      nextEpisodeNumber: next,
    )));
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — قريبًا')));
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
}

class _HeroHeader extends StatelessWidget {
  final Anime anime;
  const _HeroHeader({required this.anime});

  @override
  Widget build(BuildContext context) {
    final image = anime.backgroundImageUrl?.trim().isNotEmpty == true ? anime.backgroundImageUrl! : anime.image;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedAnimeImage(url: image, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: .18), Colors.black.withValues(alpha: .35), Colors.black.withValues(alpha: .95)],
              stops: const [0, .45, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSummary extends StatelessWidget {
  final Anime anime;
  const _HeroSummary({required this.anime});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 136,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(width: 92, height: 136, child: CachedAnimeImage(url: anime.image, fit: BoxFit.cover)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLanguage.instance.isArabic && anime.titleAr?.trim().isNotEmpty == true ? anime.titleAr!.trim() : anime.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(anime.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (anime.year != null) _Tag('${anime.seasonYear ?? anime.year}'),
                    if (anime.status != null) _Tag(_statusLabel(anime.status!)),
                    if (anime.episodes != null) _Tag('${anime.episodes} حلقة'),
                    if (anime.type != null) _Tag(anime.type!),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String value) {
    final v = value.toLowerCase();
    if (v.contains('finished')) return 'مكتمل';
    if (v.contains('currently')) return 'مستمر';
    if (v.contains('not yet')) return 'قادم';
    return value;
  }
}

class _CountdownCard extends StatelessWidget {
  final Anime anime;
  const _CountdownCard({required this.anime});

  @override
  Widget build(BuildContext context) {
    final remaining = _nextBroadcast(anime);
    final days = remaining == null ? 0 : remaining.inDays;
    final hours = remaining == null ? 0 : remaining.inHours.remainder(24);
    final minutes = remaining == null ? 0 : remaining.inMinutes.remainder(60);
    return _SurfaceCard(
      child: Column(children: [
        Text('حلقة جديدة بعد (وقت تقريبي) :', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Row(children: [
          _TimeBox(value: minutes, label: 'دقيقة'),
          const SizedBox(width: 10),
          _TimeBox(value: hours, label: 'ساعة'),
          const SizedBox(width: 10),
          _TimeBox(value: days, label: 'يوم'),
        ]),
        if (anime.broadcastDay != null || anime.broadcastTime != null) ...[
          const SizedBox(height: 8),
          Text('${anime.broadcastDay ?? ''} ${anime.broadcastTime ?? ''}'.trim(), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ]),
    );
  }

  static Duration? _nextBroadcast(Anime anime) {
    final day = (anime.broadcastDay ?? '').toLowerCase();
    final time = anime.broadcastTime ?? '';
    final weekday = const {
      'monday': DateTime.monday, 'tuesday': DateTime.tuesday, 'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday, 'friday': DateTime.friday, 'saturday': DateTime.saturday, 'sunday': DateTime.sunday,
    }[day];
    if (weekday == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time);
    final hour = int.tryParse(match?.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match?.group(2) ?? '') ?? 0;
    final now = DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    var deltaDays = (weekday - now.weekday) % 7;
    if (deltaDays == 0 && !candidate.isAfter(now)) deltaDays = 7;
    candidate = candidate.add(Duration(days: deltaDays));
    return candidate.difference(now);
  }
}

class _TimeBox extends StatelessWidget {
  final int value;
  final String label;
  const _TimeBox({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]),
  ));
}

class _WarningCard extends StatelessWidget {
  const _WarningCard();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(color: const Color(0xFFD92F25), borderRadius: BorderRadius.circular(16)),
    child: const Text('تنبيه: قد يحتوي هذا الأنمي على محتوى للبالغين أو العنف الشديد أو الدم، وقد لا يكون مناسبًا للمشاهدين القُصّر.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, height: 1.5, fontWeight: FontWeight.w600)),
  );
}

class _PrimaryActions extends StatelessWidget {
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final bool isFavorite;
  final VoidCallback onFavorite;
  const _PrimaryActions({required this.onPlay, required this.onDownload, required this.isFavorite, required this.onFavorite});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: FilledButton.icon(onPressed: onPlay, icon: const Icon(Icons.play_arrow_rounded), label: const Text('المشاهدة'))),
    const SizedBox(width: 10),
    Expanded(child: OutlinedButton.icon(onPressed: onDownload, icon: const Icon(Icons.download_outlined), label: const Text('التحميل'))),
  ]);
}

class _SecondaryActions extends StatelessWidget {
  final VoidCallback onList, onRating, onBackgrounds, onReviews, onComments;
  const _SecondaryActions({required this.onList, required this.onRating, required this.onBackgrounds, required this.onReviews, required this.onComments});
  @override
  Widget build(BuildContext context) => _SurfaceCard(
    padding: EdgeInsets.zero,
    child: Column(children: [
      Row(children: [
        _ActionCell(icon: Icons.favorite_border, label: 'المفضلة', onTap: onList),
        _ActionCell(icon: Icons.playlist_add, label: 'أضف لقائمتك', onTap: onList),
        _ActionCell(icon: Icons.star_border, label: 'أضف تقييمك', onTap: onRating),
      ]),
      Row(children: [
        _ActionCell(icon: Icons.image_outlined, label: 'خلفيات', onTap: onBackgrounds),
        _ActionCell(icon: Icons.rate_review_outlined, label: 'مراجعات', onTap: onReviews),
        _ActionCell(icon: Icons.comment_outlined, label: 'تعليقات', onTap: onComments),
      ]),
    ]),
  );
}

class _ActionCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionCell({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3), child: Column(children: [Icon(icon, size: 22), const SizedBox(height: 5), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10))]))));
}

class _MalCard extends StatelessWidget {
  final Anime anime;
  const _MalCard({required this.anime});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF355CB5), borderRadius: BorderRadius.circular(18)),
    child: Column(children: [
      const Text('MyAnimeList', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _MalStat(label: 'التقييم', value: anime.score?.toStringAsFixed(2) ?? '—', icon: Icons.star)),
        Expanded(child: _MalStat(label: 'الترتيب العالمي', value: anime.rank == null ? '—' : '#${anime.rank}', icon: Icons.format_list_numbered)),
        Expanded(child: _MalStat(label: 'المتابعون', value: anime.members == null ? '—' : _compact(anime.members!), icon: Icons.people_alt_outlined)),
      ]),
    ]),
  );
  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _MalStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _MalStat({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(height: 2), Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10))]);
}

class _InfoCard extends StatelessWidget {
  final Anime anime;
  const _InfoCard({required this.anime});
  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[];
    if (anime.source != null && anime.source!.isNotEmpty) rows.add(MapEntry('المصدر', anime.source!));
    if (anime.duration != null && anime.duration!.isNotEmpty) rows.add(MapEntry('مدة الحلقة', anime.duration!));
    if (anime.airedFrom != null && anime.airedFrom!.isNotEmpty) rows.add(MapEntry('عرض من', _date(anime.airedFrom!)));
    if (anime.airedTo != null && anime.airedTo!.isNotEmpty) rows.add(MapEntry('إلى', _date(anime.airedTo!)));
    if (anime.studioNames.isNotEmpty) rows.add(MapEntry('الاستوديو', anime.studioNames.join('، ')));
    if (anime.rating != null && anime.rating!.isNotEmpty) rows.add(MapEntry('التصنيف العمري', anime.rating!));
    if (rows.isEmpty) return const SizedBox.shrink();
    return _SectionCard(title: 'معلومات الأنمي', child: Column(children: rows.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 105, child: Text('${e.key} :', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant))), Expanded(child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600)))]))).toList()));
  }
  static String _date(String value) => value.length >= 10 ? value.substring(0, 10) : value;
}

class _TrailerCard extends StatelessWidget {
  final Anime anime;
  const _TrailerCard({required this.anime});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => LinkLauncher.open(context, anime.trailerUrl!),
    borderRadius: BorderRadius.circular(18),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(width: double.infinity, height: 170, child: anime.trailerImageUrl != null ? CachedAnimeImage(url: anime.trailerImageUrl!, fit: BoxFit.cover) : CachedAnimeImage(url: anime.image, fit: BoxFit.cover)),
        Container(width: double.infinity, height: 170, color: Colors.black.withValues(alpha: .42)),
        const Column(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(Icons.play_arrow, color: Colors.black, size: 32)), SizedBox(height: 8), Text('العرض الدعائي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17))]),
      ]),
    ),
  );
}

class _DetailsTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _DetailsTabs({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => _SurfaceCard(padding: EdgeInsets.zero, child: Row(children: [
    _Tab(label: 'الشخصيات', selected: selected == 0, onTap: () => onChanged(0)),
    _Tab(label: 'ذات صلة', selected: selected == 1, onTap: () => onChanged(1)),
    _Tab(label: 'أنميات مشابهة', selected: selected == 2, onTap: () => onChanged(2)),
  ]));
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))), child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800)))));
}

class _CharacterSection extends StatelessWidget {
  final List<AnimeCharacter> characters;
  const _CharacterSection({required this.characters});
  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) return const _EmptyFeature(title: 'الشخصيات', message: 'بيانات الشخصيات غير متاحة حاليًا.');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('الشخصيات الرئيسية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      SizedBox(height: 156, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: characters.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, i) {
        final c = characters[i];
        return SizedBox(width: 108, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: c.imageUrl?.isNotEmpty == true ? CachedAnimeImage(url: c.imageUrl!, fit: BoxFit.cover) : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.person, size: 36)))),
          const SizedBox(height: 6), Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (c.role != null) Text(c.role!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]));
      })),
    ]);
  }
}

class _RelatedSection extends StatelessWidget {
  final List<AnimeRelation> relations;
  const _RelatedSection({required this.relations});
  @override
  Widget build(BuildContext context) {
    if (relations.isEmpty) return const _EmptyFeature(title: 'ذات صلة', message: 'لا توجد أعمال مرتبطة متاحة حاليًا.');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: relations.map((group) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(group.relation, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 7), ...group.entries.take(6).map((entry) => Card(child: ListTile(leading: const Icon(Icons.movie_outlined), title: Text(entry.title), subtitle: Text(entry.type ?? 'Anime'), trailing: const Icon(Icons.chevron_left))))]))).toList());
  }
}

class _RecommendationsSection extends StatelessWidget {
  final List<AnimeRecommendation> items;
  const _RecommendationsSection({required this.items});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyFeature(title: 'أنميات مشابهة', message: 'ستظهر الاقتراحات عندما يوفر مزود البيانات هذه المعلومات.');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('أنميات مشابهة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      SizedBox(height: 190, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, i) {
        final item = items[i];
        return SizedBox(width: 118, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: item.imageUrl?.isNotEmpty == true ? CachedAnimeImage(url: item.imageUrl!, fit: BoxFit.cover) : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.movie_outlined)))),
          const SizedBox(height: 6), Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]));
      })),
    ]);
  }
}

class _EpisodesSection extends StatelessWidget {
  final List<Map<String, dynamic>> episodes;
  final bool episodesHasNext;
  final bool episodesLoadingMore;
  final String? episodesError;
  final VoidCallback onLoadMore;
  final ValueChanged<Map<String, dynamic>> onEpisode;
  final ValueChanged<Map<String, dynamic>> onDownload;
  const _EpisodesSection({required this.episodes, required this.episodesHasNext, required this.episodesLoadingMore, required this.episodesError, required this.onLoadMore, required this.onEpisode, required this.onDownload});
  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      if (episodesError != null) return UiStateCard(icon: Icons.playlist_remove, title: 'تعذر تحميل الحلقات', message: 'قد تكون الحلقات غير متاحة مؤقتًا. يمكنك سحب الشاشة للمحاولة مرة أخرى.', compact: true);
      return const _EpisodeLoading();
    }
    return _SectionCard(title: 'الحلقات', trailing: Text('${episodes.length}${episodesHasNext ? '+' : ''}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)), child: Column(children: [
      ...episodes.map((episode) => _EpisodeTile(episode: episode, onTap: () => onEpisode(episode), onDownload: () => onDownload(episode))),
      if (episodesError != null) const InlineNotice(warning: true, icon: Icons.warning_amber_outlined, text: 'تعذر تحميل الصفحة التالية من الحلقات.'),
      if (episodesHasNext) SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: episodesLoadingMore ? null : onLoadMore, icon: episodesLoadingMore ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more), label: Text(episodesLoadingMore ? 'جارٍ التحميل...' : 'تحميل المزيد'))),
    ]));
  }
}

class _EpisodeTile extends StatelessWidget {
  final Map<String, dynamic> episode;
  final VoidCallback onTap, onDownload;
  const _EpisodeTile({required this.episode, required this.onTap, required this.onDownload});
  @override
  Widget build(BuildContext context) {
    final number = (episode['mal_id'] as num?)?.toInt() ?? (episode['episode'] as num?)?.toInt() ?? 0;
    final title = episode['title']?.toString().trim();
    final subtitle = episode['aired']?.toString().trim();
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(child: Text('$number')),
      title: Text(title?.isNotEmpty == true ? title! : 'الحلقة $number', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle?.isNotEmpty == true ? subtitle! : 'متاحة'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(tooltip: 'تنزيل الحلقة', icon: const Icon(Icons.download_outlined), onPressed: number <= 0 ? null : onDownload), const Icon(Icons.play_circle_outline)],),
      onTap: number <= 0 ? null : onTap,
    ));
  }
}

class _SynopsisSection extends StatelessWidget {
  final String englishText;
  final String? arabicText;
  final bool arabicLoading;
  final bool showFull;
  final VoidCallback onToggleFull;
  const _SynopsisSection({required this.englishText, required this.arabicText, required this.arabicLoading, required this.showFull, required this.onToggleFull});
  @override
  Widget build(BuildContext context) {
    final isArabic = AppLanguage.instance.isArabic;
    final clean = isArabic ? (arabicText?.trim() ?? '') : englishText.trim();
    if (isArabic && clean.isEmpty) return arabicLoading ? const Row(mainAxisAlignment: MainAxisAlignment.end, children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('جارٍ تجهيز القصة بالعربية...')]) : const Text('لا تتوفر قصة باللغة العربية حاليًا.');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedSize(duration: const Duration(milliseconds: 220), child: Text(clean, maxLines: showFull ? null : 5, overflow: showFull ? TextOverflow.visible : TextOverflow.ellipsis, textAlign: isArabic ? TextAlign.right : TextAlign.left, style: TextStyle(height: 1.75, color: Theme.of(context).colorScheme.onSurfaceVariant))),
      const SizedBox(height: 6),
      TextButton.icon(onPressed: onToggleFull, icon: Icon(showFull ? Icons.expand_less : Icons.expand_more), label: Text(showFull ? 'إظهار أقل' : 'إظهار المزيد')),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) => _SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), if (trailing != null) trailing!]), const SizedBox(height: 10), child]));
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _SurfaceCard({required this.child, this.padding});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding ?? const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .05))));
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));
}

class _EmptyFeature extends StatelessWidget {
  final String title, message;
  const _EmptyFeature({required this.title, required this.message});
  @override
  Widget build(BuildContext context) => _SurfaceCard(child: Column(children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]));
}

class _EpisodeLoading extends StatelessWidget {
  const _EpisodeLoading();
  @override
  Widget build(BuildContext context) => Column(children: List.generate(4, (_) => const Card(child: ListTile(leading: CircleAvatar(child: SizedBox(width: 10, height: 10)), title: SizedBox(height: 12, child: LinearProgressIndicator()), subtitle: SizedBox(height: 10)))));
}
