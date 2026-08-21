import '../models/catalog_item.dart';
import '../services/api_cache.dart';
import '../services/catalog_api_service.dart';

class CatalogPage {
  final List<CatalogItem> items;
  final int page;
  final bool hasNextPage;

  const CatalogPage({required this.items, required this.page, required this.hasNextPage});
}

class CatalogRepository {
  final CatalogApiService api;
  final ApiCache cache;

  CatalogRepository({CatalogApiService? api, ApiCache? cache})
      : api = api ?? CatalogApiService(),
        cache = cache ?? ApiCache();

  Future<CatalogPage> getPage(String kind, {int page = 1, int limit = 24, String? category, bool forceRefresh = false}) async {
    final categoryKey = (category ?? 'default').trim().isEmpty ? 'default' : category!.trim();
    final key = 'catalog_${kind}_${categoryKey}_${page}_$limit';
    if (!forceRefresh) {
      final cached = await cache.read(key, maxAge: const Duration(minutes: 30));
      if (cached != null) return _map(cached, page);
    }
    try {
      final response = await api.page(kind, page: page, limit: limit, category: category);
      await cache.write(key, response);
      return _map(response, page);
    } catch (e) {
      final stale = await cache.read(key, maxAge: const Duration(days: 7));
      if (stale != null) return _map(stale, page);
      rethrow;
    }
  }

  CatalogPage _map(Map<String, dynamic> json, int fallbackPage) {
    final raw = json['data'];
    final items = raw is List
        ? raw.whereType<Map>().map((e) => CatalogItem.fromJson(Map<String, dynamic>.from(e))).where((e) => e.id.isNotEmpty).toList()
        : <CatalogItem>[];
    final pagination = json['pagination'];
    final page = pagination is Map ? (pagination['current_page'] as num?)?.toInt() ?? fallbackPage : fallbackPage;
    final hasNext = pagination is Map && pagination['has_next_page'] == true;
    return CatalogPage(items: items, page: page, hasNextPage: hasNext);
  }

  void dispose() => api.dispose();
}
