import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_version.dart';
import 'anime_data_source.dart';
import 'monitoring_service.dart';

/// Diagnostic exception used by the Beta build. It intentionally keeps the
/// upstream status/reason visible so failures can be fixed instead of hidden.
class AnimeApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? requestId;
  final String? endpoint;
  final Object? cause;
  final bool degraded;

  const AnimeApiException(
    this.message, {
    this.statusCode,
    this.requestId,
    this.endpoint,
    this.cause,
    this.degraded = false,
  });

  @override
  String toString() {
    final parts = <String>[message];
    if (statusCode != null) parts.add('HTTP $statusCode');
    if (endpoint != null) parts.add(endpoint!);
    if (requestId != null) parts.add('request=$requestId');
    if (cause != null) parts.add('cause=${cause.runtimeType}');
    return parts.join(' • ');
  }
}

/// Beta decision: Anime data is NOT read from our backend/D1. The mobile app
/// talks to Jikan directly. This deliberately isolates anime failures from
/// Cloudflare/D1 catalog state so the exact upstream problem is observable.
class AnimeApiService implements AnimeDataSource {
  final String baseUrl;
  final http.Client client;

  AnimeApiService({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? 'https://api.jikan.moe/v4').replaceFirst(RegExp(r'/$'), ''),
        client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> topAnime({int page = 1}) => getJson('/top/anime', query: {
        'page': '$page', 'limit': '24', 'sfw': 'true',
      });

  @override
  Future<Map<String, dynamic>> searchAnime(String query, {int page = 1, int limit = 12}) =>
      getJson('/anime', query: {
        'q': query, 'page': '$page', 'limit': '$limit', 'sfw': 'true',
        'order_by': 'popularity', 'sort': 'asc',
      });

  @override
  Future<Map<String, dynamic>> animeDetails(int id) => getJson('/anime/$id/full');

  @override
  Future<Map<String, dynamic>> animeEpisodes(int id, {int page = 1, int limit = 24}) =>
      getJson('/anime/$id/episodes', query: {'page': '$page', 'limit': '$limit'});

  @override
  Future<Map<String, dynamic>> comingSoon({int page = 1, int limit = 24}) =>
      getJson('/anime', query: {
        'status': 'upcoming', 'page': '$page', 'limit': '$limit', 'sfw': 'true',
        'order_by': 'popularity', 'sort': 'asc',
      });

  @override
  Future<Map<String, dynamic>> seasonYears() async {
    // Jikan exposes /seasons/{year}, not a years index. Keep a small rolling
    // list and let the repository cache it. Counts are intentionally omitted.
    final now = DateTime.now().year;
    final years = <Map<String, dynamic>>[];
    for (var year = now; year >= now - 7; year--) {
      try {
        final response = await getJson('/seasons/$year');
        final pagination = response['pagination'];
        final count = pagination is Map ? pagination['items'] : null;
        years.add({'year': year, 'count': count is num ? count : 0});
      } catch (_) {
        // One unavailable year must not hide all other years.
      }
    }
    if (years.isEmpty) {
      throw const AnimeApiException('فشل تحميل قائمة المواسم من Jikan: لم تُرجع أي سنة بيانات صالحة.');
    }
    return {'data': years};
  }

  @override
  Future<Map<String, dynamic>> seasonAnime(int year, {int page = 1, int limit = 24}) =>
      getJson('/seasons/$year', query: {'page': '$page', 'limit': '$limit'});

  String _requestId() => 'beta-${DateTime.now().microsecondsSinceEpoch}';

  Future<Map<String, dynamic>> getJson(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final requestId = _requestId();
    final started = DateTime.now();
    try {
      final response = await client.get(uri, headers: {
        'Accept': 'application/json',
        'X-Client-Version': appVersion,
        'X-Request-ID': requestId,
      }).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            await _record(path, started, true, response.statusCode);
            return decoded;
          }
        } catch (error) {
          throw AnimeApiException(
            'فشل تحليل استجابة Jikan: الرد ليس JSON صالحًا.',
            statusCode: response.statusCode,
            requestId: requestId,
            endpoint: uri.toString(),
            cause: error,
          );
        }
        throw AnimeApiException(
          'فشل تحميل بيانات الأنمي: Jikan أعاد بنية JSON غير متوقعة.',
          statusCode: response.statusCode,
          requestId: requestId,
          endpoint: uri.toString(),
        );
      }

      String detail = 'بدون رسالة من Jikan';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          detail = (decoded['message'] ?? decoded['error'] ?? decoded['status'] ?? detail).toString();
        }
      } catch (_) {
        if (response.body.trim().isNotEmpty) detail = response.body.trim().replaceAll(RegExp(r'\s+'), ' ').substring(0, response.body.trim().length.clamp(0, 180));
      }

      await _record(path, started, false, response.statusCode, detail);
      final reason = switch (response.statusCode) {
        400 => 'طلب غير صالح من التطبيق أو Jikan: $detail',
        404 => 'الأنمي/الحلقة غير موجودة في Jikan: $detail',
        429 => 'Jikan رفض الطلب بسبب Rate Limit: $detail',
        500 || 502 || 503 || 504 => 'Jikan أو MyAnimeList غير متاح مؤقتًا: $detail',
        _ => 'Jikan أعاد HTTP ${response.statusCode}: $detail',
      };
      throw AnimeApiException(reason, statusCode: response.statusCode, requestId: requestId, endpoint: uri.toString());
    } catch (error) {
      if (error is AnimeApiException) rethrow;
      await _record(path, started, false, null, '${error.runtimeType}: $error');
      throw AnimeApiException(
        'فشل الاتصال المباشر بـ Jikan. السبب: ${error.runtimeType} — $error',
        requestId: requestId,
        endpoint: uri.toString(),
        cause: error,
      );
    }
  }

  Future<void> _record(String path, DateTime started, bool success, int? status, [String? message]) async {
    try {
      await MonitoringService.instance.recordRequest(
        path: 'jikan:$path',
        latencyMs: DateTime.now().difference(started).inMilliseconds,
        success: success,
        statusCode: status,
        message: message,
      );
    } catch (_) {}
  }

  void dispose() => client.close();
}
