abstract class AnimeDataSource {
  Future<Map<String, dynamic>> topAnime({int page = 1});

  Future<Map<String, dynamic>> searchAnime(
    String query, {
    int page = 1,
    int limit = 12,
  });

  Future<Map<String, dynamic>> animeDetails(int id);

  Future<Map<String, dynamic>> animeEpisodes(
    int id, {
    int page = 1,
    int limit = 24,
  });

  /// Upcoming/unaired titles for the sidebar's "Coming Soon" item (see
  /// docs/SETTINGS_SIDEBAR_PLAN.md, Phase 8).
  Future<Map<String, dynamic>> comingSoon({int page = 1, int limit = 24});
  Future<Map<String, dynamic>> episodeSchedule({required String day});


  /// Distinct broadcast years in the catalog, for the sidebar's "Seasons"
  /// item (see docs/SETTINGS_SIDEBAR_PLAN.md, Phase 8).
  Future<Map<String, dynamic>> seasonYears();

  /// Catalog titles for one broadcast year.
  Future<Map<String, dynamic>> seasonAnime(int year, {int page = 1, int limit = 24});
  /// Resolves a catalog/MAL ID to the canonical AniList ID used by playback.
  Future<Map<String, dynamic>> anivexaMapMal(int malId);

  /// Returns Anivexa episode/source metadata for an AniList ID.
  Future<Map<String, dynamic>> anivexaEpisodes(int anilistId);

  /// Returns stream metadata for an authorized Anivexa provider episode.
  Future<Map<String, dynamic>> anivexaWatch({
    required String provider,
    required int anilistId,
    required String audio,
    required int episode,
  });

}
