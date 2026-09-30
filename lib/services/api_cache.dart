import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiCacheEntry {
  final Map<String, dynamic> data;
  final DateTime storedAt;

  const ApiCacheEntry({required this.data, required this.storedAt});

  Duration get age => DateTime.now().difference(storedAt);
}

/// Small persistent JSON cache used by repositories.
///
/// Repositories can read fresh data normally or intentionally read stale data
/// and refresh it in the background. This keeps the UI responsive when the
/// network is slow/unavailable without treating old data as permanently fresh.
class ApiCache {
  static const _prefix = 'api_cache_v2_';

  Future<ApiCacheEntry?> readEntry(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;

    try {
      final wrapper = jsonDecode(raw);
      if (wrapper is! Map) return null;

      final timestamp = DateTime.tryParse(wrapper['timestamp']?.toString() ?? '');
      final data = wrapper['data'];
      if (timestamp == null || data is! Map) return null;

      return ApiCacheEntry(
        data: Map<String, dynamic>.from(data),
        storedAt: timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> read(
    String key, {
    Duration maxAge = const Duration(minutes: 10),
  }) async {
    final entry = await readEntry(key);
    if (entry == null || entry.age > maxAge) return null;
    return entry.data;
  }

  /// Returns expired data too. Intended only for stale-while-revalidate flows.
  Future<Map<String, dynamic>?> readStale(String key) async {
    final entry = await readEntry(key);
    return entry?.data;
  }

  Future<void> write(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$key',
      jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'data': data,
      }),
    );
  }
}
