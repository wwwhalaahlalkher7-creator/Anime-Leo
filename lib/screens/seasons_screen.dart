import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/app_language.dart';
import '../models/anime.dart';
import '../repositories/anime_repository.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../widgets/anime_card.dart';
import '../widgets/ui_states.dart';

/// Real screen for the sidebar's "Seasons" item (see
/// docs/SETTINGS_SIDEBAR_PLAN.md, Phase 8). The catalog only stores a
/// broadcast `year` (no quarter/season string), so this groups by year: a
/// row of year chips at the top, and a paginated grid of that year's titles
/// below — same grid shape as [SearchScreen]/[UpcomingAnimeScreen].
class SeasonsScreen extends StatefulWidget {
  final AppState state;
  final AnalyticsService analytics;
  const SeasonsScreen({super.key, required this.state, required this.analytics});

  @override
  State<SeasonsScreen> createState() => _SeasonsScreenState();
}

class _SeasonsScreenState extends State<SeasonsScreen> {
  final scrollController = ScrollController();
  final repository = AnimeRepository();
  int requestToken = 0;

  List<SeasonYear> years = [];
  bool loadingYears = true;
  String? yearsError;

  int? selectedYear;
  final List<Anime> results = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasNextPage = false;
  String? error;
  int page = 0;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    _loadYears();
  }

  Future<void> _loadYears() async {
    setState(() {
      loadingYears = true;
      yearsError = null;
    });
    try {
      final list = await repository.getSeasonYears();
      if (!mounted) return;
      setState(() {
        years = list;
        loadingYears = false;
        if (list.isNotEmpty) {
          selectedYear = list.first.year;
        }
      });
      if (selectedYear != null) _loadPage(1);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        yearsError = e.toString();
        loadingYears = false;
      });
    }
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    if (scrollController.position.pixels > scrollController.position.maxScrollExtent - 500 &&
        !loading &&
        !loadingMore &&
        hasNextPage) {
      _loadPage(page + 1, append: true);
    }
  }

  void _selectYear(int year) {
    if (year == selectedYear) return;
    setState(() {
      selectedYear = year;
      results.clear();
      page = 0;
      hasNextPage = false;
    });
    _loadPage(1);
  }

  Future<void> _loadPage(int targetPage, {bool append = false}) async {
    final year = selectedYear;
    if (year == null) return;
    final token = ++requestToken;
    if (append) {
      setState(() => loadingMore = true);
    } else {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final response = await repository.getSeasonAnime(year, page: targetPage);
      if (!mounted || token != requestToken) return;
      setState(() {
        if (append) {
          final existing = results.map((e) => e.id).toSet();
          results.addAll(response.items.where((e) => !existing.contains(e.id)));
        } else {
          results
            ..clear()
            ..addAll(response.items);
        }
        page = response.page;
        hasNextPage = response.hasNextPage;
        loading = false;
        loadingMore = false;
      });
    } catch (e) {
      if (!mounted || token != requestToken) return;
      setState(() {
        error = e.toString();
        loading = false;
        loadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    requestToken++;
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppLanguage.instance.text('المواسم', 'Seasons'))),
      body: Builder(
        builder: (_) {
          if (loadingYears) return const LoadingGrid();
          if (yearsError != null && years.isEmpty) {
            return UiStateCard(
              icon: Icons.cloud_queue,
              title: AppLanguage.instance.text('تعذر تحميل المواسم', 'Couldn\'t load seasons'),
              message: yearsError!,
              actionLabel: AppLanguage.instance.text('إعادة المحاولة', 'Retry'),
              onAction: _loadYears,
            );
          }
          if (years.isEmpty) {
            return UiStateCard(
              icon: Icons.calendar_view_month_outlined,
              title: AppLanguage.instance.text('لا توجد بيانات مواسم بعد', 'No season data yet'),
              message: AppLanguage.instance.text(
                'سيظهر هنا تصنيف الأنمي حسب سنة العرض فور توفره.',
                'Anime grouped by broadcast year will show up here once available.',
              ),
              compact: true,
            );
          }

          return Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: years.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final y = years[i];
                    final selected = y.year == selectedYear;
                    return ChoiceChip(
                      label: Text('${y.year} (${y.count})'),
                      selected: selected,
                      selectedColor: cs.primary.withValues(alpha: .22),
                      onSelected: (_) => _selectYear(y.year),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _resultsBody()),
            ],
          );
        },
      ),
    );
  }

  Widget _resultsBody() {
    final hasResults = results.isNotEmpty;
    if (loading && !hasResults) return const LoadingGrid();
    if (error != null && !hasResults) {
      final degraded = error!.contains('مؤقت') || error!.contains('الخادم');
      return UiStateCard(
        icon: degraded ? Icons.cloud_queue : Icons.calendar_view_month_outlined,
        title: degraded
            ? AppLanguage.instance.text('الخدمة غير متاحة مؤقتًا', 'Service temporarily unavailable')
            : AppLanguage.instance.text('تعذر تحميل القائمة', 'Couldn\'t load the list'),
        message: degraded
            ? AppLanguage.instance.text('تحقق من الاتصال وحاول مرة أخرى.', 'Check your connection and try again.')
            : error!,
        actionLabel: AppLanguage.instance.text('إعادة المحاولة', 'Retry'),
        onAction: () => _loadPage(1),
      );
    }
    if (results.isEmpty) {
      return UiStateCard(
        icon: Icons.calendar_view_month_outlined,
        title: AppLanguage.instance.text('لا توجد عناوين لهذه السنة', 'Nothing for this year'),
        message: AppLanguage.instance.text('جرّب سنة أخرى من الأعلى.', 'Try another year above.'),
        compact: true,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPage(1),
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  if (i >= results.length) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  return AnimeCard(
                    anime: results[i],
                    state: widget.state,
                    remoteConfig: RemoteConfig.disabled,
                    analytics: widget.analytics,
                  );
                },
                childCount: results.length + (loadingMore ? 3 : 0),
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: .52,
                crossAxisSpacing: 10,
                mainAxisSpacing: 18,
              ),
            ),
          ),
          if (!hasNextPage && !loadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: Center(
                  child: Text(
                    AppLanguage.instance.text('انتهت القائمة.', 'End of list.'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
