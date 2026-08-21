import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime.dart';


class WatchProgress {
  final int animeId;
  final int episode;
  final int positionSeconds;
  final int durationSeconds;
  final DateTime updatedAt;
  final bool completed;

  const WatchProgress({
    required this.animeId,
    required this.episode,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAt,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
        'animeId': animeId,
        'episode': episode,
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
        'updatedAt': updatedAt.toIso8601String(),
        'completed': completed,
      };

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
        animeId: (json['animeId'] as num?)?.toInt() ?? 0,
        episode: (json['episode'] as num?)?.toInt() ?? 0,
        positionSeconds: (json['positionSeconds'] as num?)?.toInt() ?? 0,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        completed: json['completed'] as bool? ?? false,
      );
}

class StoredHistory {
  final Anime anime;
  final int episode;

  const StoredHistory({
    required this.anime,
    required this.episode,
  });

  Map<String, dynamic> toJson() => {
        'anime': anime.toJson(),
        'episode': episode,
      };

  factory StoredHistory.fromJson(Map<String, dynamic> json) => StoredHistory(
        anime: Anime.fromJson(Map<String, dynamic>.from(json['anime'] as Map)),
        episode: (json['episode'] as num?)?.toInt() ?? 0,
      );
}

/// Who receives new-episode alerts (Notifications section, Phase 4 UI).
enum EpisodeAlertScope { all, favoritesOnly, off }

/// Which player launches by default (Player section, Phase 5 UI).
enum PlayerPreference { askEveryTime, builtIn, external }

/// Settings state for [AppSettings] — see docs/SETTINGS_SIDEBAR_PLAN.md,
/// Phase 2. Account toggles aren't included: Phase 3 ships Account as a
/// placeholder only, no visibility toggles yet.
class StoredSettings {
  final EpisodeAlertScope episodeAlerts;
  final bool commentNotifications;
  final bool reviewNotifications;
  final bool newsNotifications;
  final PlayerPreference playerPreference;
  final String defaultQuality;
  final String subtitleLanguage;

  const StoredSettings({
    this.episodeAlerts = EpisodeAlertScope.all,
    this.commentNotifications = true,
    this.reviewNotifications = true,
    this.newsNotifications = true,
    this.playerPreference = PlayerPreference.askEveryTime,
    this.defaultQuality = 'auto',
    this.subtitleLanguage = 'ar',
  });

  Map<String, dynamic> toJson() => {
        'episodeAlerts': episodeAlerts.name,
        'commentNotifications': commentNotifications,
        'reviewNotifications': reviewNotifications,
        'newsNotifications': newsNotifications,
        'playerPreference': playerPreference.name,
        'defaultQuality': defaultQuality,
        'subtitleLanguage': subtitleLanguage,
      };

  factory StoredSettings.fromJson(Map<String, dynamic> json) => StoredSettings(
        episodeAlerts: EpisodeAlertScope.values.firstWhere(
          (e) => e.name == json['episodeAlerts'],
          orElse: () => EpisodeAlertScope.all,
        ),
        commentNotifications: json['commentNotifications'] as bool? ?? true,
        reviewNotifications: json['reviewNotifications'] as bool? ?? true,
        newsNotifications: json['newsNotifications'] as bool? ?? true,
        defaultQuality: json['defaultQuality']?.toString() ?? 'auto',
        subtitleLanguage: json['subtitleLanguage']?.toString() ?? 'ar',
        playerPreference: PlayerPreference.values.firstWhere(
          (e) => e.name == json['playerPreference'],
          orElse: () => PlayerPreference.askEveryTime,
        ),
      );
}

class StorageService {
  static const _favoritesKey = 'favorites_v2';
  static const _historyKey = 'history_v2';
  static const _settingsKey = 'app_settings_v2';
  static const _legacySettingsKey = 'app_settings_v1';
  static const _progressKey = 'watch_progress_v1';

  Future<SharedPreferences> get _prefs async =>
      SharedPreferences.getInstance();

  Future<List<Anime>> loadFavorites() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_favoritesKey);
    if (raw == null) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Anime.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.id != 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<StoredHistory>> loadHistory() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => StoredHistory.fromJson(Map<String, dynamic>.from(e)))
          .where((h) => h.anime.id != 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<StoredSettings> loadSettings() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_settingsKey) ?? prefs.getString(_legacySettingsKey);
    if (raw == null) return const StoredSettings();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const StoredSettings();
      return StoredSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const StoredSettings();
    }
  }

  Future<void> saveSettings(StoredSettings settings) async {
    final prefs = await _prefs;
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> saveFavorites(List<Anime> values) async {
    final prefs = await _prefs;
    await prefs.setString(
      _favoritesKey,
      jsonEncode(values.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveHistory(List<StoredHistory> values) async {
    final prefs = await _prefs;
    await prefs.setString(
      _historyKey,
      jsonEncode(values.map((e) => e.toJson()).toList()),
    );
  }

  Future<WatchProgress?> loadWatchProgress(int animeId, int episode) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_progressKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      for (final item in decoded.whereType<Map>()) {
        final progress = WatchProgress.fromJson(Map<String, dynamic>.from(item));
        if (progress.animeId == animeId && progress.episode == episode) return progress;
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveWatchProgress(WatchProgress value) async {
    final prefs = await _prefs;
    final values = <WatchProgress>[];
    final raw = prefs.getString(_progressKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          values.addAll(decoded.whereType<Map>().map((e) => WatchProgress.fromJson(Map<String, dynamic>.from(e))));
        }
      } catch (_) {}
    }
    values.removeWhere((e) => e.animeId == value.animeId && e.episode == value.episode);
    values.insert(0, value);
    if (values.length > 100) values.removeRange(100, values.length);
    await prefs.setString(_progressKey, jsonEncode(values.map((e) => e.toJson()).toList()));
  }
}
