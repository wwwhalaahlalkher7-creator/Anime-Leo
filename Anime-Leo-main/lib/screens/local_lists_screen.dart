import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/app_language.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../widgets/anime_card.dart';
import '../widgets/cached_anime_image.dart';
import '../widgets/ui_states.dart';
import 'anime_details_screen.dart';

class LocalHistoryScreen extends StatelessWidget {
  final AppState state;
  final AnalyticsService analytics;
  const LocalHistoryScreen({super.key, required this.state, required this.analytics});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (_, __) {
          final items = state.history;
          return Scaffold(
            appBar: AppBar(title: Text(AppLanguage.instance.text('سجل المشاهدة', 'Watch History'))),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(AppLanguage.instance.text('واصل الحلقات التي بدأت بها.', 'Continue the episodes you started.')),
                const SizedBox(height: 20),
                if (items.isEmpty)
                  UiStateCard(icon: Icons.history_toggle_off, title: AppLanguage.instance.text('سجل المشاهدة فارغ', 'Watch history is empty'), message: AppLanguage.instance.text('عند فتح حلقة سيظهر الأنمي هنا.', 'Anime will appear here when you open an episode.'), compact: true)
                else
                  ...items.map((item) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: SizedBox(width: 48, height: 68, child: CachedAnimeImage(url: item.anime.image, borderRadius: BorderRadius.circular(8))),
                          title: Text(item.anime.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('الحلقة ${item.episode}'),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => state.removeHistory(item.anime.id)),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: item.anime, state: state, remoteConfig: RemoteConfig.disabled, analytics: analytics))),
                        ),
                      )),
                if (items.isNotEmpty) TextButton.icon(onPressed: state.clearHistory, icon: const Icon(Icons.delete_sweep_outlined), label: Text(AppLanguage.instance.text('مسح السجل', 'Clear history'))),
              ],
            ),
          );
        },
      );
}

class LocalFavoritesScreen extends StatelessWidget {
  final AppState state;
  final AnalyticsService analytics;
  const LocalFavoritesScreen({super.key, required this.state, required this.analytics});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (_, __) {
          final items = state.favorites;
          return Scaffold(
            appBar: AppBar(title: Text(AppLanguage.instance.text('المفضلة', 'Favorites'))),
            body: items.isEmpty
                ? ListView(padding: const EdgeInsets.all(20), children: [UiStateCard(icon: Icons.favorite_border, title: AppLanguage.instance.text('المفضلة فارغة', 'Favorites are empty'), message: AppLanguage.instance.text('اضغط على القلب في بطاقة أي أنمي لإضافته هنا.', 'Tap the heart on any anime card to add it here.'), compact: true)])
                : GridView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: items.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: .52, crossAxisSpacing: 10, mainAxisSpacing: 18),
                    itemBuilder: (_, i) => AnimeCard(anime: items[i], state: state, remoteConfig: RemoteConfig.disabled, analytics: analytics),
                  ),
          );
        },
      );
}
