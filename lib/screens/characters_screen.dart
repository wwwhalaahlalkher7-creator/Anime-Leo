import 'package:flutter/material.dart';
import '../core/app_language.dart';
import '../core/app_state.dart';
import '../models/character.dart';
import '../repositories/anime_repository.dart';
import '../services/analytics_service.dart';
import '../widgets/cached_anime_image.dart';
import '../widgets/ui_states.dart';
import 'character_details_screen.dart';

class CharactersScreen extends StatefulWidget {
  final AppState state;
  final AnalyticsService analytics;
  const CharactersScreen({super.key, required this.state, required this.analytics});

  @override
  State<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends State<CharactersScreen> {
  final repository = AnimeRepository();
  final scrollController = ScrollController();
  final List<PopularCharacter> results = [];
  bool loading = true;
  bool loadingMore = false;
  bool hasNext = false;
  int page = 1;
  String? error;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    _load(1);
  }

  void _onScroll() {
    if (!scrollController.hasClients || loading || loadingMore || !hasNext) return;
    if (scrollController.position.pixels > scrollController.position.maxScrollExtent - 500) _load(page + 1, append: true);
  }

  Future<void> _load(int target, {bool append = false}) async {
    if (append) {
      setState(() => loadingMore = true);
    } else {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final response = await repository.getPopularCharacters(page: target);
      if (!mounted) return;
      setState(() {
        if (!append) results.clear();
        final existing = results.map((e) => e.id).toSet();
        results.addAll(response.where((e) => !existing.contains(e.id)));
        page = target;
        hasNext = response.length >= 24;
        loading = false;
        loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; loadingMore = false; error = e.toString(); });
    }
  }

  @override
  void dispose() { scrollController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLanguage.instance.text('الشخصيات الأكثر شعبية', 'Most Popular Characters'))),
      body: Builder(builder: (_) {
        if (loading && results.isEmpty) return const LoadingGrid();
        if (error != null && results.isEmpty) {
          return UiStateCard(icon: Icons.groups_outlined, title: AppLanguage.instance.text('تعذر تحميل الشخصيات', 'Couldn\'t load characters'), message: error!, actionLabel: AppLanguage.instance.text('إعادة المحاولة', 'Retry'), onAction: () => _load(1));
        }
        if (results.isEmpty) return UiStateCard(icon: Icons.groups_outlined, title: AppLanguage.instance.text('لا توجد شخصيات', 'No characters'), message: AppLanguage.instance.text('لا تتوفر بيانات الشخصيات حاليًا.', 'Character data is not available right now.'), compact: true);
        return RefreshIndicator(
          onRefresh: () => _load(1),
          child: GridView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: results.length + (loadingMore ? 3 : 0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 12, childAspectRatio: .62),
            itemBuilder: (_, i) {
              if (i >= results.length) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              final character = results[i];
              return _CharacterCard(character: character, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CharacterDetailsScreen(characterId: character.id, state: widget.state, analytics: widget.analytics))));
            },
          ),
        );
      }),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final PopularCharacter character;
  final VoidCallback onTap;
  const _CharacterCard({required this.character, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(fit: StackFit.expand, children: [
        CachedAnimeImage(url: character.imageUrl, fit: BoxFit.cover),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: .88)]))),
        Positioned(top: 7, right: 7, child: _Badge(icon: Icons.favorite, text: _formatCount(character.favorites))),
        Positioned(left: 9, right: 9, bottom: 9, child: Text(character.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, height: 1.05))),
      ]),
    ),
  );
}

class _Badge extends StatelessWidget {
  final IconData icon; final String text;
  const _Badge({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: Colors.black.withValues(alpha: .48), borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(width: 3), Icon(icon, color: Colors.white, size: 14)])));
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 100000 ? 0 : 1)}K';
  return '$value';
}
