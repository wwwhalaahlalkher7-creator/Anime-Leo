import '../models/anime.dart';
import '../services/anime_api_service.dart';
import '../services/anime_data_source.dart';
import '../services/api_cache.dart';

class AnimePage {
  final List<Anime> items;
  final int page;
  final bool hasNextPage;

  const AnimePage({
    required this.items,
    required this.page,
    required this.hasNextPage,
  });
}


class AnimeEpisodesPage {
  final List<Map<String, dynamic>> items;
  final int page;
  final bool hasNextPage;

  const AnimeEpisodesPage({
    required this.items,
    required this.page,
    required this.hasNextPage,
  });
}

class SeasonYear {
  final int year;
  final int count;

  const SeasonYear({required this.year, required this.count});
}

class AnimeRepository {
  final AnimeDataSource api;
  final ApiCache cache;

  AnimeRepository({
    AnimeDataSource? api,
    ApiCache? cache,
  })  : api = api ?? AnimeApiService(),
        cache = cache ?? ApiCache();

  Anime _mapAnime(Map<String, dynamic> json) {
    final images = json['images'];
    final jpg = images is Map ? images['jpg'] : null;
    final rawId = json['id'] ?? json['mal_id'];

    return Anime(
      id: rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0,
      title: (json['title'] ?? 'Unknown Anime').toString(),
      image: (json['image'] ??
              json['image_url'] ??
              (jpg is Map ? jpg['large_image_url'] ?? jpg['image_url'] : null))
          ?.toString() ??
          '',
      titleAr: json['title_ar']?.toString() ?? json['titleAr']?.toString(),
      synopsis: json['synopsis']?.toString(),
      genres: (json['genres'] is List)
          ? (json['genres'] as List).map((e) => e.toString()).toList()
          : const [],
      status: json['status']?.toString(),
      score: (json['score'] as num?)?.toDouble(),
      year: (json['year'] as num?)?.toInt(),
      type: json['type']?.toString(),
      episodes: (json['episodes'] as num?)?.toInt(),
    );
  }

  List<Anime> _list(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => _mapAnime(Map<String, dynamic>.from(e)))
        .where((a) => a.id != 0)
        .toList();
  }

  bool _hasNext(Map<String, dynamic> response) {
    final pagination = response['pagination'];
    return pagination is Map && pagination['has_next_page'] == true;
  }

  Future<List<Anime>> getTopAnime({bool forceRefresh = false}) async {
    const key = 'top_anime_v4';

    if (!forceRefresh) {
      final cached = await cache.read(
        key,
        maxAge: const Duration(minutes: 15),
      );
      if (cached != null) return _list(cached);
    }

    try {
      // Load several pages so the home catalog is no longer limited to a
      // handful of seeded rows. The backend caches/upserts provider results.
      final combined = <Map<String, dynamic>>[];
      var hasNext = true;
      for (var page = 1; page <= 6 && hasNext; page++) {
        try {
          final response = await api.topAnime(page: page);
          combined.addAll(_list(response).map((a) => a.toJson()));
          hasNext = _hasNext(response);
        } catch (_) {
          break;
        }
      }
      // Remove duplicate IDs while preserving ranking order.
      final seenIds = <int>{};
      final unique = combined.where((item) {
        final id = (item['id'] as num?)?.toInt() ?? 0;
        return id != 0 && seenIds.add(id);
      }).toList();

      final merged = <String, dynamic>{
        'data': unique,
        'pagination': {'has_next_page': false, 'current_page': 1},
      };
      await cache.write(key, merged);
      return _list(merged);
    } catch (error) {
      final stale = await cache.read(
        key,
        maxAge: const Duration(days: 7),
      );
      if (stale != null) return _list(stale);
      rethrow;
    }
  }

  Future<AnimePage> search(
    String query, {
    int page = 1,
    int limit = 12,
  }) async {
    final normalized = query.trim().toLowerCase();
    final key = 'search_${Uri.encodeComponent(normalized)}_${page}_$limit';

    final cached = await cache.read(
      key,
      maxAge: const Duration(minutes: 15),
    );
    if (cached != null) {
      return AnimePage(
        items: _list(cached),
        page: page,
        hasNextPage: _hasNext(cached),
      );
    }

    try {
      final response = await api.searchAnime(
        normalized,
        page: page,
        limit: limit,
      );
      await cache.write(key, response);
      return AnimePage(
        items: _list(response),
        page: page,
        hasNextPage: _hasNext(response),
      );
    } catch (_) {
      final stale = await cache.read(
        key,
        maxAge: const Duration(days: 7),
      );
      if (stale != null) {
        return AnimePage(
          items: _list(stale),
          page: page,
          hasNextPage: _hasNext(stale),
        );
      }
      rethrow;
    }
  }

  Future<AnimePage> getComingSoon({int page = 1, int limit = 24}) async {
    final key = 'coming_soon_${page}_$limit';
    final cached = await cache.read(key, maxAge: const Duration(minutes: 30));
    if (cached != null) {
      return AnimePage(
        items: _list(cached),
        page: page,
        hasNextPage: _hasNext(cached),
      );
    }

    try {
      final response = await api.comingSoon(page: page, limit: limit);
      await cache.write(key, response);
      return AnimePage(
        items: _list(response),
        page: page,
        hasNextPage: _hasNext(response),
      );
    } catch (_) {
      final stale = await cache.read(key, maxAge: const Duration(days: 7));
      if (stale != null) {
        return AnimePage(
          items: _list(stale),
          page: page,
          hasNextPage: _hasNext(stale),
        );
      }
      rethrow;
    }
  }

  List<SeasonYear> _seasonYears(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => SeasonYear(
              year: (e['year'] as num?)?.toInt() ?? 0,
              count: (e['count'] as num?)?.toInt() ?? 0,
            ))
        .where((s) => s.year != 0)
        .toList();
  }

  Future<List<SeasonYear>> getSeasonYears({bool forceRefresh = false}) async {
    const key = 'season_years_v1';
    if (!forceRefresh) {
      final cached = await cache.read(key, maxAge: const Duration(hours: 6));
      if (cached != null) return _seasonYears(cached);
    }
    try {
      final response = await api.seasonYears();
      await cache.write(key, response);
      return _seasonYears(response);
    } catch (_) {
      final stale = await cache.read(key, maxAge: const Duration(days: 7));
      if (stale != null) return _seasonYears(stale);
      rethrow;
    }
  }

  Future<AnimePage> getSeasonAnime(int year, {int page = 1, int limit = 24}) async {
    final key = 'season_${year}_${page}_$limit';
    final cached = await cache.read(key, maxAge: const Duration(hours: 6));
    if (cached != null) {
      return AnimePage(
        items: _list(cached),
        page: page,
        hasNextPage: _hasNext(cached),
      );
    }

    try {
      final response = await api.seasonAnime(year, page: page, limit: limit);
      await cache.write(key, response);
      return AnimePage(
        items: _list(response),
        page: page,
        hasNextPage: _hasNext(response),
      );
    } catch (_) {
      final stale = await cache.read(key, maxAge: const Duration(days: 7));
      if (stale != null) {
        return AnimePage(
          items: _list(stale),
          page: page,
          hasNextPage: _hasNext(stale),
        );
      }
      rethrow;
    }
  }

  Future<Anime> getDetails(int id) async {    final key = 'details_$id';
    final cached = await cache.read(
      key,
      maxAge: const Duration(hours: 12),
    );

    try {
      final response = await api.animeDetails(id);
      final data = response['data'];

      if (data is! Map) {
        throw const AnimeApiException('تعذر قراءة تفاصيل الأنمي.');
      }

      final mapped = Map<String, dynamic>.from(data);
      await cache.write(key, mapped);
      return _mapAnime(mapped);
    } catch (error) {
      if (cached != null) return _mapAnime(cached);
      rethrow;
    }
  }

  Future<AnimeEpisodesPage> getEpisodes(
    int id, {
    int page = 1,
    int limit = 24,
  }) async {
    final key = 'episodes_${id}_$page';
    final cached = await cache.read(
      key,
      maxAge: const Duration(hours: 6),
    );

    AnimeEpisodesPage fromResponse(Map<String, dynamic> response) {
      final data = response['data'];
      final items = data is List
          ? data.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      final pagination = response['pagination'];
      final hasNext = pagination is Map && pagination['has_next_page'] == true;
      return AnimeEpisodesPage(items: items, page: page, hasNextPage: hasNext);
    }

    if (cached != null) return fromResponse(cached);

    try {
      final response = await api.animeEpisodes(id, page: page, limit: limit);
      await cache.write(key, response);
      return fromResponse(response);
    } catch (_) {
      final stale = await cache.read(key, maxAge: const Duration(days: 7));
      if (stale != null) return fromResponse(stale);
      rethrow;
    }
  }

}
