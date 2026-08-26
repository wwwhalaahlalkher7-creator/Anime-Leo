import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiCache {
  static const _prefix = 'api_cache_v1_';

  Future<Map<String, dynamic>?> read(
    String key, {
    Duration maxAge = const Duration(minutes: 10),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;

    try {
      final wrapper = jsonDecode(raw);
      if (wrapper is! Map) return null;

      final timestamp = DateTime.tryParse(wrapper['timestamp']?.toString() ?? '');
      final data = wrapper['data'];

      if (timestamp == null || data is! Map) return null;
      if (DateTime.now().difference(timestamp) > maxAge) return null;

      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
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
