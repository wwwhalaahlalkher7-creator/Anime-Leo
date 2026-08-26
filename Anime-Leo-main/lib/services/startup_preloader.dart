import '../repositories/anime_repository.dart';
import '../repositories/catalog_repository.dart';

/// Starts the same data requests used by the first screen while the intro is
/// playing. Results are written to ApiCache, so HomeScreen can render from the
/// warm cache instead of starting from an empty network request.
class StartupPreloader {
  StartupPreloader._();

  static final StartupPreloader instance = StartupPreloader._();

  final AnimeRepository _animeRepository = AnimeRepository();
  final CatalogRepository _catalogRepository = CatalogRepository();

  Future<void>? _future;
  List<String> _imageUrls = const [];

  Future<void> start() {
    return _future ??= _run();
  }

  List<String> get imageUrls => _imageUrls;

  Future<void> _run() async {
    try {
      final results = await Future.wait<dynamic>([
        _animeRepository.getTopAnime(),
        _catalogRepository.getPage('manga'),
      ]);

      final anime = results.first;
      if (anime is List) {
        _imageUrls = anime
            .where((item) => item.image.toString().trim().isNotEmpty)
            .map<String>((item) => item.image.toString())
            .take(18)
            .toList(growable: false);
      }
    } catch (_) {
      // HomeScreen already has its own retry/error states. The intro must
      // never get stuck because the network is unavailable.
    }
  }
}
