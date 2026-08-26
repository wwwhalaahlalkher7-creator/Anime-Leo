import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/app_language.dart';
import '../models/anime.dart';
import '../repositories/anime_repository.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../widgets/anime_card.dart';
import '../widgets/ui_states.dart';

/// Real screen for the sidebar's "Coming Soon" item — upcoming/unaired
/// titles (see docs/SETTINGS_SIDEBAR_PLAN.md, Phase 8). A paginated,
/// database-backed view over the existing catalog, styled the same as
/// [SearchScreen]'s result grid.
class UpcomingAnimeScreen extends StatefulWidget {
  final AppState state;
  final AnalyticsService analytics;
  const UpcomingAnimeScreen({super.key, required this.state, required this.analytics});

  @override
  State<UpcomingAnimeScreen> createState() => _UpcomingAnimeScreenState();
}

class _UpcomingAnimeScreenState extends State<UpcomingAnimeScreen> {
  final scrollController = ScrollController();
  final repository = AnimeRepository();
  int requestToken = 0;
  final List<Anime> results = [];
  bool loading = true;
  bool loadingMore = false;
  bool hasNextPage = false;
  bool refreshing = false;
  String? error;
  int page = 0;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    _loadPage(1);
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

  Future<void> _loadPage(int targetPage, {bool append = false}) async {
    final token = ++requestToken;
    if (append) {
      setState(() => loadingMore = true);
    } else {
      setState(() {
        loading = true;
        refreshing = results.isNotEmpty;
        error = null;
      });
    }

    try {
      final response = await repository.getComingSoon(page: targetPage);
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
        refreshing = false;
      });
    } catch (e) {
      if (!mounted || token != requestToken) return;
      setState(() {
        error = e.toString();
        loading = false;
        loadingMore = false;
        refreshing = false;
      });
    }
  }

  Future<void> _refresh() => _loadPage(1);

  @override
  void dispose() {
    requestToken++;
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = results.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(AppLanguage.instance.text('قادم قريبًا', 'Coming Soon'))),
      body: Builder(
        builder: (_) {
          if (loading && !hasResults) return const LoadingGrid();
          if (error != null && !hasResults) {
            final degraded = error!.contains('مؤقت') || error!.contains('الخادم');
            return UiStateCard(
              icon: degraded ? Icons.cloud_queue : Icons.upcoming_outlined,
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
              icon: Icons.upcoming_outlined,
              title: AppLanguage.instance.text('لا توجد عناوين قادمة حاليًا', 'Nothing upcoming right now'),
              message: AppLanguage.instance.text(
                'سيظهر هنا كل أنمي لم يُعرض بعد فور توفر بياناته.',
                'Titles that haven\'t aired yet will show up here as soon as they\'re catalogued.',
              ),
              compact: true,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (refreshing) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
                if (error != null)
                  SliverToBoxAdapter(
                    child: InlineNotice(
                      warning: true,
                      icon: Icons.cloud_off_outlined,
                      text: AppLanguage.instance.text(
                        'تعذر تحديث القائمة. يتم عرض ما توفر مخزنًا مؤقتًا.',
                        'Couldn\'t refresh the list. Showing cached results when available.',
                      ),
                    ),
                  ),
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
        },
      ),
    );
  }
}
