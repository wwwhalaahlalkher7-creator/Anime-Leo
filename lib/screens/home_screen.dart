import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme_controller.dart';
import '../core/app_language.dart';
import '../services/backend_service.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../services/monitoring_service.dart';
import '../models/anime.dart';
import '../repositories/anime_repository.dart';
import '../repositories/catalog_repository.dart';
import '../models/catalog_item.dart';
import '../widgets/ad_slot.dart';
import '../widgets/anime_card.dart';
import '../widgets/cached_anime_image.dart';
import '../widgets/ui_states.dart';
import '../widgets/app_drawer.dart';
import '../widgets/catalog_card.dart';
import '../widgets/anime_leo_brand.dart';
import 'anime_details_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppState state;
  final ThemeController theme;
  final RemoteConfig remoteConfig;
  final AnalyticsService analytics;

  const HomeScreen({
    super.key,
    required this.state,
    required this.theme,
    required this.remoteConfig,
    required this.analytics,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final repository = AnimeRepository();
  final catalogRepository = CatalogRepository();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int selected = 0;
  late Future<List<Anime>> futureAnime;
  late Future<CatalogPage> futureManga;
  late final BackendService _backend;

  @override
  void initState() {
    super.initState();
    futureAnime = repository.getTopAnime();
    futureManga = catalogRepository.getPage('manga');
    _backend = BackendService();
  }

  Future<void> retry() async {
    setState(() => futureAnime = repository.getTopAnime(forceRefresh: true));
    await futureAnime;
  }

  void _openDetails(Anime anime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimeDetailsScreen(
          anime: anime,
          state: widget.state,
          remoteConfig: widget.remoteConfig,
          analytics: widget.analytics,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _home(),
      _catalogSection(kind: 'manga', titleAr: 'المانجا والمانهوا', titleEn: 'Manga & Manhwa', icon: Icons.menu_book_outlined, future: futureManga),
      _AnimationCatalogSection(repository: catalogRepository, header: _header()),
    ];
    return AnimatedBuilder(
      animation: Listenable.merge([widget.state, widget.theme, AppLanguage.instance]),
      builder: (_, __) => Scaffold(
        key: _scaffoldKey,
        drawer: AppDrawer(
          currentTabIndex: selected,
          onSelectTab: (i) => setState(() => selected = i),
          theme: widget.theme,
          state: widget.state,
          analytics: widget.analytics,
        ),
        body: SafeArea(child: pages[selected]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) => setState(() => selected = i),
          destinations: [
            NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: AppLanguage.instance.text('الأنمي', 'Anime')),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: AppLanguage.instance.text('المانجا', 'Manga')),
            NavigationDestination(icon: Icon(Icons.movie_filter_outlined), selectedIcon: Icon(Icons.movie_filter), label: AppLanguage.instance.text('الرسوم', 'Animation')),
          ],
        ),
      ),
    );
  }

  Widget _home() {
    return FutureBuilder<List<Anime>>(
      future: futureAnime,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _loadingHome();
        if (snapshot.hasError) {
          return UiStateCard(
            icon: Icons.cloud_off_rounded,
            title: 'تعذر تحميل الأنمي',
            message: 'يمكنك المحاولة مرة أخرى. إذا انقطع الاتصال سيحاول التطبيق الاستفادة من البيانات المخزنة محليًا.',
            actionLabel: 'إعادة المحاولة',
            onAction: () => retry(),
          );
        }

        final anime = snapshot.data ?? const <Anime>[];
        if (anime.isEmpty) {
          return UiStateCard(
            icon: Icons.inventory_2_outlined,
            title: 'لا توجد بيانات حاليًا',
            message: 'لم تصل نتائج من الخادم بعد. اسحب للأسفل لتحديث الصفحة.',
            actionLabel: 'تحديث',
            onAction: () => retry(),
          );
        }

        final hero = anime.first;
        final popular = anime.skip(1).toList();
        return RefreshIndicator(
          onRefresh: retry,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(pinned: true, delegate: _PinnedHeaderDelegate(child: _header(), extent: 92)),
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 4), child: _hero(hero))),
              SliverToBoxAdapter(child: AdSlot(enabled: widget.remoteConfig.ads)),
              SliverToBoxAdapter(child: _SectionTitle(AppLanguage.instance.text('الأعلى تقييمًا', 'Top Rated'))),
              if (popular.isEmpty)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد عناصر إضافية للعرض.')))
              else
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 248,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: popular.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => AnimeCard(anime: popular[i], width: 138, state: widget.state, remoteConfig: widget.remoteConfig, analytics: widget.analytics),
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: _SectionTitle(AppLanguage.instance.text('المزيد', 'More'))),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => AnimeCard(anime: anime[i], state: widget.state, remoteConfig: widget.remoteConfig, analytics: widget.analytics),
                    childCount: anime.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: .52,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 18,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _catalogSection({
    required String kind,
    required String titleAr,
    required String titleEn,
    required IconData icon,
    required Future<CatalogPage> future,
  }) {
    return FutureBuilder<CatalogPage>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return CustomScrollView(
            slivers: [
              SliverPersistentHeader(pinned: true, delegate: _PinnedHeaderDelegate(child: _header(), extent: 92)),
              SliverToBoxAdapter(child: _SectionTitle(AppLanguage.instance.text(titleAr, titleEn))),
              const SliverToBoxAdapter(child: SizedBox(height: 248, child: LoadingGrid(count: 6))),
            ],
          );
        }
        if (snapshot.hasError && snapshot.data == null) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(pinned: true, delegate: _PinnedHeaderDelegate(child: _header(), extent: 92)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: UiStateCard(
                    icon: icon,
                    title: AppLanguage.instance.text(
                      'تعذر تحميل $titleAr',
                      'Could not load $titleEn',
                    ),
                    message: AppLanguage.instance.text(
                      'سيتم استخدام البيانات المخزنة إن وجدت. تحقق من إعداد مصدر القسم ثم أعد المحاولة.',
                      'Cached data will be used when available. Check the provider configuration and retry.',
                    ),
                    actionLabel: AppLanguage.instance.text('إعادة المحاولة', 'Retry'),
                    onAction: () => setState(() {
                      if (kind == 'manga') {
                        futureManga = catalogRepository.getPage('manga', forceRefresh: true);
                      } else {
                      }
                    }),
                  ),
                ),
              ),
            ],
          );
        }

        final items = snapshot.data?.items ?? const <CatalogItem>[];
        return RefreshIndicator(
          onRefresh: () async {
            final refreshed = catalogRepository.getPage(kind, forceRefresh: true);
            setState(() {
              if (kind == 'manga') {
                futureManga = refreshed;
              } else {
              }
            });
            await refreshed;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(pinned: true, delegate: _PinnedHeaderDelegate(child: _header(), extent: 92)),
              SliverToBoxAdapter(child: _SectionTitle(AppLanguage.instance.text(titleAr, titleEn))),
              if (items.isEmpty)
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(20), child: UiStateCard(icon: icon, title: AppLanguage.instance.text('لا توجد بيانات', 'No data'), message: AppLanguage.instance.text('لا توجد عناوين عربية متاحة من المصدر حاليًا.', 'No Arabic titles are currently available from the provider.'), compact: true)))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((_, i) => CatalogCard(item: items[i]), childCount: items.length),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: .52, crossAxisSpacing: 10, mainAxisSpacing: 18),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: AppLanguage.instance.text('القائمة', 'Menu'),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimeLeoWordmark(width: 112, height: 32),
                const SizedBox(height: 2),
                Text(AppLanguage.instance.text('ماذا ستشاهد اليوم؟', 'What will you watch today?'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: AppLanguage.instance.text('البحث', 'Search'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(state: widget.state, analytics: widget.analytics))),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
    );
  }

  Widget _loadingHome() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPersistentHeader(pinned: true, delegate: _PinnedHeaderDelegate(child: _header(), extent: 92)),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Container(height: 215, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(22))))),
        SliverToBoxAdapter(child: _SectionTitle(AppLanguage.instance.text('الأعلى تقييمًا', 'Top Rated'))),
        const SliverToBoxAdapter(child: SizedBox(height: 248, child: LoadingGrid(count: 4))),
      ],
    );
  }

  Widget _hero(Anime anime) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openDetails(anime),
      child: SizedBox(
        height: 215,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedAnimeImage(url: anime.image, fit: BoxFit.cover, borderRadius: BorderRadius.circular(22)),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE605081A)]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLanguage.instance.text('اختيار اليوم', 'Pick of the day'), style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 5),
                        Text(anime.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 6),
                        Text('⭐ ${anime.score ?? '—'}  •  ${anime.year ?? '—'}', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: () => _openDetails(anime), child: const Icon(Icons.arrow_forward_rounded)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _backend.dispose();
    catalogRepository.dispose();
    super.dispose();
  }
}


class _AnimationCatalogSection extends StatefulWidget {
  final CatalogRepository repository;
  final Widget header;

  const _AnimationCatalogSection({
    required this.repository,
    required this.header,
  });

  @override
  State<_AnimationCatalogSection> createState() => _AnimationCatalogSectionState();
}

class _AnimationCatalogSectionState extends State<_AnimationCatalogSection> {
  static const categories = <String, (String, String)>{
    'popular': ('الأكثر شعبية', 'Popular'),
    'anime': ('أنمي ياباني', 'Japanese Anime'),
    'global': ('رسوم عالمية', 'Global Animation'),
    'top_rated': ('الأعلى تقييمًا', 'Top Rated'),
    'latest': ('الأحدث', 'Latest'),
  };

  String category = 'popular';
  final List<CatalogItem> items = [];
  int page = 1;
  bool hasNext = true;
  bool loading = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (loading) return;
    if (!reset && !hasNext) return;

    setState(() {
      loading = true;
      error = null;
      if (reset) {
        page = 1;
        hasNext = true;
        items.clear();
      }
    });

    try {
      final result = await widget.repository.getPage(
        'animation',
        page: reset ? 1 : page + 1,
        limit: 24,
        category: category,
        forceRefresh: reset,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          items
            ..clear()
            ..addAll(result.items);
          page = 1;
        } else {
          final ids = items.map((e) => e.id).toSet();
          items.addAll(result.items.where((e) => ids.add(e.id)));
          page += 1;
        }
        hasNext = result.hasNextPage;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e;
      });
    }
  }

  void _selectCategory(String value) {
    if (value == category) return;
    setState(() => category = value);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final language = AppLanguage.instance;
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHeaderDelegate(child: widget.header, extent: 92),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                language.text('الرسوم المتحركة', 'Animation'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final key = categories.keys.elementAt(index);
                  final labels = categories[key]!;
                  return ChoiceChip(
                    selected: category == key,
                    label: Text(language.text(labels.$1, labels.$2)),
                    onSelected: (_) => _selectCategory(key),
                  );
                },
              ),
            ),
          ),
          if (error != null && items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: UiStateCard(
                  icon: Icons.movie_filter_outlined,
                  title: language.text('تعذر تحميل الرسوم المتحركة', 'Could not load animation'),
                  message: language.text(
                    'تحقق من اتصال المصدر ثم أعد المحاولة.',
                    'Check the provider connection and retry.',
                  ),
                  actionLabel: language.text('إعادة المحاولة', 'Retry'),
                  onAction: () => _load(reset: true),
                ),
              ),
            )
          else if (items.isEmpty && loading)
            const SliverToBoxAdapter(child: SizedBox(height: 360, child: LoadingGrid(count: 8)))
          else if (items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: UiStateCard(
                  icon: Icons.movie_filter_outlined,
                  title: language.text('لا توجد نتائج', 'No results'),
                  message: language.text(
                    'لا توجد عناوين في هذا التصنيف حاليًا.',
                    'No titles are currently available in this category.',
                  ),
                  compact: true,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => CatalogCard(item: items[i]),
                  childCount: items.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: .52,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 18,
                ),
              ),
            ),
          if (error != null && items.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  language.text('تعذر تحميل المزيد حاليًا.', 'Could not load more right now.'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (hasNext && items.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : () => _load(reset: false),
                    icon: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(
                      loading
                          ? language.text('جارٍ التحميل...', 'Loading...')
                          : language.text('تحميل المزيد', 'Load more'),
                    ),
                  ),
                ),
              ),
            )
          else if (items.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Text(
                  language.text('تم عرض كل النتائج المتاحة حاليًا.', 'All currently available results are shown.'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          if (loading && items.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Text(
                language.text(
                  'المصدر: TMDB • العناوين الخارجية بالإنجليزية في التطبيق.',
                  'Source: TMDB • External catalog titles are shown in English.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _MonitoringCard extends StatefulWidget {
  const _MonitoringCard();

  @override
  State<_MonitoringCard> createState() => _MonitoringCardState();
}

class _MonitoringCardState extends State<_MonitoringCard> {
  MonitoringSnapshot get snapshot => MonitoringService.instance.snapshot;

  Future<void> _clear() async {
    await MonitoringService.instance.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.monitor_heart_outlined, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(AppLanguage.instance.text('المراقبة المحلية', 'Local monitoring'), style: TextStyle(fontWeight: FontWeight.w800))),
              IconButton(onPressed: _clear, tooltip: AppLanguage.instance.text('مسح بيانات المراقبة', 'Clear monitoring data'), icon: const Icon(Icons.delete_sweep_outlined)),
            ]),
            const SizedBox(height: 8),
            Text(AppLanguage.instance.text('تشخيص محلي فقط — لا يتم إرسال Analytics أو بيانات مراقبة للخادم.', 'Local diagnostics only — no analytics or monitoring data is sent to the server.'), style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _Metric(label: AppLanguage.instance.text('طلبات API', 'API requests'), value: '${s.requests}'),
                _Metric(label: AppLanguage.instance.text('نجاح', 'Success'), value: '${s.successes}'),
                _Metric(label: AppLanguage.instance.text('فشل', 'Failures'), value: '${s.failures}'),
                _Metric(label: 'Degraded', value: '${s.degraded}'),
                _Metric(label: AppLanguage.instance.text('متوسط الزمن', 'Average latency'), value: '${s.averageLatencyMs} ms'),
                _Metric(label: 'Health checks', value: '${s.healthChecks} / ${s.healthFailures} فشل'),
              ],
            ),
            if (s.lastPath != null) ...[
              const SizedBox(height: 12),
              Text(AppLanguage.instance.text('آخر طلب: ${s.lastPath}', 'Last request: ${s.lastPath}'), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (s.lastStatusCode != null) Text('HTTP ${s.lastStatusCode}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 130,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
    child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
  );
}


class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double extent;
  const _PinnedHeaderDelegate({required this.child, required this.extent});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) => oldDelegate.extent != extent || oldDelegate.child != child;
}
