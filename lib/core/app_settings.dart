import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

export '../services/storage_service.dart' show EpisodeAlertScope, PlayerPreference;

/// Settings that don't already have a home in [ThemeController] or
/// [AppLanguage] — Notifications and Player state for now (see
/// docs/SETTINGS_SIDEBAR_PLAN.md, Phase 2). Mirrors their singleton
/// `ChangeNotifier` + `load()` pattern and persists via [StorageService],
/// same as favorites/history.
///
/// This is the data model only. UI for these lands in later phases
/// (Notifications: Phase 4, Player: Phase 5) — nothing reads this yet.
class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  final StorageService _storage = StorageService();

  EpisodeAlertScope episodeAlerts = EpisodeAlertScope.all;
  bool commentNotifications = true;
  bool reviewNotifications = true;
  bool newsNotifications = true;
  PlayerPreference playerPreference = PlayerPreference.askEveryTime;

  Future<void> load() async {
    final stored = await _storage.loadSettings();
    episodeAlerts = stored.episodeAlerts;
    commentNotifications = stored.commentNotifications;
    reviewNotifications = stored.reviewNotifications;
    newsNotifications = stored.newsNotifications;
    playerPreference = stored.playerPreference;
    notifyListeners();
  }

  Future<void> _persist() => _storage.saveSettings(StoredSettings(
        episodeAlerts: episodeAlerts,
        commentNotifications: commentNotifications,
        reviewNotifications: reviewNotifications,
        newsNotifications: newsNotifications,
        playerPreference: playerPreference,
      ));

  Future<void> setEpisodeAlerts(EpisodeAlertScope value) async {
    episodeAlerts = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setCommentNotifications(bool value) async {
    commentNotifications = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setReviewNotifications(bool value) async {
    reviewNotifications = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setNewsNotifications(bool value) async {
    newsNotifications = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setPlayerPreference(PlayerPreference value) async {
    playerPreference = value;
    notifyListeners();
    await _persist();
  }
}
