import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/app_language.dart';
import '../models/anime.dart';
import '../repositories/anime_repository.dart';
import '../widgets/anime_card.dart';
import '../widgets/ui_states.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../widgets/anime_leo_brand.dart';

class SearchScreen extends StatefulWidget {
  final AppState state;
  final AnalyticsService analytics;
  const SearchScreen({super.key, required this.state, required this.analytics});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final repository = AnimeRepository();
  Timer? debounce;
  int requestToken = 0;
  final List<Anime> results = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasNextPage = false;
  bool refreshing = false;
  String? error;
  int page = 0;
  String activeQuery = '';

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    if (scrollController.position.pixels > scrollController.position.maxScrollExtent - 500 && !loading && !loadingMore && hasNextPage && activeQuery.isNotEmpty) {
      _loadPage(page + 1, append: true);
    }
  }

  void _search(String value) {
    debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        results.clear();
        activeQuery = '';
        error = null;
        loading = false;
        loadingMore = false;
        hasNextPage = false;
        page = 0;
      });
      return;
    }

    debounce = Timer(const Duration(milliseconds: 450), () {
      activeQuery = query;
      widget.analytics.track('search', parameters: {'query_length': query.length});
      _loadPage(1);
    });
  }

  Future<void> _loadPage(int targetPage, {bool append = false}) async {
    final token = ++requestToken;
    if (append) {
      setState(() => loadingMore = true);
    } else {
      setState(() {
        loading = true;
        refreshing = true;
        error = null;
        results.clear();
        page = 0;
        hasNextPage = false;
      });
    }

    try {
      final response = await repository.search(activeQuery, page: targetPage);
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

  Future<void> _refresh() async {
    if (activeQuery.isEmpty) return;
    await _loadPage(1);
  }

  @override
  void dispose() {
    debounce?.cancel();
    requestToken++;
    scrollController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = results.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Row(
          children: [
            const AnimeLeoWordmark(width: 96, height: 30),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: AppLanguage.instance.text('ابحث عن أنمي...', 'Search anime...'),
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (controller.text.isNotEmpty)
            IconButton(tooltip: AppLanguage.instance.text('مسح', 'Clear'), onPressed: () { controller.clear(); _search(''); setState(() {}); }, icon: const Icon(Icons.clear)),
        ],
      ),
      body: Builder(
        builder: (_) {
          if (loading && !hasResults) return const LoadingGrid();
          if (error != null && !hasResults) {
            final degraded = error!.contains('مؤقت') || error!.contains('الخادم');
            return UiStateCard(
              icon: degraded ? Icons.cloud_queue : Icons.search_off,
              title: degraded ? AppLanguage.instance.text('الخدمة غير متاحة مؤقتًا', 'Service temporarily unavailable') : AppLanguage.instance.text('تعذر تنفيذ البحث', 'Search failed'),
              message: degraded ? AppLanguage.instance.text('تحقق من الاتصال. إذا كانت هناك بيانات مخزنة سيحاول التطبيق استخدامها تلقائيًا.', 'Check your connection. Cached data will be used when available.') : error!,
              actionLabel: AppLanguage.instance.text('إعادة المحاولة', 'Retry'),
              onAction: () => _loadPage(1),
            );
          }
          if (activeQuery.isEmpty) return UiStateCard(icon: Icons.manage_search, title: AppLanguage.instance.text('ابدأ البحث', 'Start searching'), message: AppLanguage.instance.text('اكتب اسم الأنمي في الأعلى، وسيبدأ البحث تلقائيًا بعد توقفك عن الكتابة.', 'Type an anime name above. Search starts automatically when you pause.'), compact: true);
          if (results.isEmpty) return UiStateCard(icon: Icons.search_off, title: AppLanguage.instance.text('لا توجد نتائج', 'No results'), message: AppLanguage.instance.text('جرّب اسمًا مختلفًا أو اختصر عبارة البحث.', 'Try another name or a shorter query.'), compact: true);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (refreshing) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
                if (error != null) SliverToBoxAdapter(child: InlineNotice(warning: true, icon: Icons.cloud_off_outlined, text: AppLanguage.instance.text('تعذر تحديث النتائج الجديدة. يتم عرض ما توفر من النتائج المخزنة مؤقتًا.', 'Could not refresh results. Showing cached results when available.'))),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        if (i >= results.length) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        return AnimeCard(anime: results[i], state: widget.state, remoteConfig: RemoteConfig.disabled, analytics: widget.analytics);
                      },
                      childCount: results.length + (loadingMore ? 3 : 0),
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: .52, crossAxisSpacing: 10, mainAxisSpacing: 18),
                  ),
                ),
                if (!hasNextPage && !loadingMore)
                  SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 28), child: Center(child: Text(AppLanguage.instance.text('انتهت النتائج.', 'End of results.'), style: TextStyle(color: Colors.grey))))),
              ],
            ),
          );
        },
      ),
    );
  }
}
