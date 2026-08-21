import 'package:flutter/foundation.dart';
import '../models/anime.dart';
import '../services/storage_service.dart';

String _animeKey(Anime anime) => anime.canonicalId ?? 'legacy:${anime.id}';

class AppState extends ChangeNotifier {
  final StorageService storage;

  final List<Anime> favorites = [];
  final List<StoredHistory> history = [];

  bool initialized = false;

  AppState({StorageService? storage})
      : storage = storage ?? StorageService();

  Future<void> load() async {
    favorites
      ..clear()
      ..addAll(await storage.loadFavorites());

    history
      ..clear()
      ..addAll(await storage.loadHistory());

    initialized = true;
    notifyListeners();
  }

  bool isFavorite(Anime anime) =>
      favorites.any((item) => _animeKey(item) == _animeKey(anime));

  Future<void> toggleFavorite(Anime anime) async {
    final index = favorites.indexWhere((item) => _animeKey(item) == _animeKey(anime));
    if (index >= 0) {
      favorites.removeAt(index);
    } else {
      favorites.insert(0, anime);
    }
    notifyListeners();
    await storage.saveFavorites(favorites);
  }

  Future<void> rememberEpisode(Anime anime, int episode) async {
    history.removeWhere((item) => _animeKey(item.anime) == _animeKey(anime));
    history.insert(
      0,
      StoredHistory(anime: anime, episode: episode),
    );

    // Keep local storage bounded.
    if (history.length > 30) {
      history.removeRange(30, history.length);
    }

    notifyListeners();
    await storage.saveHistory(history);
  }

  Future<void> removeHistory(int animeId) async {
    history.removeWhere((item) => item.anime.id == animeId || item.anime.canonicalId == 'mal:$animeId');
    notifyListeners();
    await storage.saveHistory(history);
  }

  Future<void> clearHistory() async {
    history.clear();
    notifyListeners();
    await storage.saveHistory(history);
  }
}
