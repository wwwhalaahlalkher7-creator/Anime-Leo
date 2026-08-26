import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_state.dart';
import '../core/app_language.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../models/anime.dart';
import '../screens/anime_details_screen.dart';

class AnimeCard extends StatelessWidget {
  final Anime anime;
  final AppState state;
  final RemoteConfig? remoteConfig;
  final AnalyticsService? analytics;
  final double width;

  const AnimeCard({
    super.key,
    required this.anime,
    required this.state,
    this.remoteConfig,
    this.analytics,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnimeDetailsScreen(
              anime: anime,
              state: state,
              remoteConfig: remoteConfig ?? RemoteConfig.disabled,
              analytics: analytics ?? NoOpAnalyticsService(),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: anime.image,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: AnimatedBuilder(
                      animation: state,
                      builder: (_, __) => DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: state.isFavorite(anime) ? AppLanguage.instance.text('إزالة من المفضلة', 'Remove from favorites') : AppLanguage.instance.text('إضافة إلى المفضلة', 'Add to favorites'),
                          onPressed: () => state.toggleFavorite(anime),
                          icon: Icon(
                            state.isFavorite(anime)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: state.isFavorite(anime)
                                ? Colors.redAccent
                                : Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: Center(
                child: Text(
                  anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, height: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '⭐ ${anime.score ?? '—'}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
