import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'anime_data_source.dart';
import 'monitoring_service.dart';
import '../config/api_config.dart';

class AnimeApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? requestId;
  final bool degraded;

  const AnimeApiException(
    this.message, {
    this.statusCode,
    this.requestId,
    this.degraded = false,
  });

  @override
  String toString() => message;
}

/// The app talks to our backend only.
/// The backend can change upstream providers without requiring an app update.
class AnimeApiService implements AnimeDataSource {
  final String baseUrl;
  final http.Client client;

  AnimeApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/$'), ''),
        client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> topAnime({int page = 1}) =>
      getJson('/top/anime', query: {
        'page': '$page',
        'limit': '24',
        'sfw': 'true',
        'catalog_v': '5',
      });

  @override
  Future<Map<String, dynamic>> searchAnime(
    String query, {
    int page = 1,
    int limit = 12,
  }) =>
      getJson('/anime', query: {
        'q': query,
        'page': '$page',
        'limit': '$limit',
        'sfw': 'true',
        'order_by': 'popularity',
        'sort': 'asc',
      });

  @override
  Future<Map<String, dynamic>> animeDetails(int id) =>
      getJson('/anime/$id/full');

  @override
  Future<Map<String, dynamic>> animeEpisodes(
    int id, {
    int page = 1,
    int limit = 24,
  }) =>
      getJson('/anime/$id/episodes', query: {'page': '$page', 'limit': '$limit'});

  @override
  Future<Map<String, dynamic>> comingSoon({int page = 1, int limit = 24}) =>
      getJson('/anime/coming-soon', query: {'page': '$page', 'limit': '$limit'});
  @override
  Future<Map<String, dynamic>> episodeSchedule({required String day}) =>
      getJson('/anime/schedule', query: {'day': day});


  @override
  Future<Map<String, dynamic>> seasonYears() => getJson('/anime/seasons');

  @override
  Future<Map<String, dynamic>> seasonAnime(int year, {int page = 1, int limit = 24}) =>
      getJson('/anime/seasons', query: {'year': '$year', 'page': '$page', 'limit': '$limit'});

  /// Returns the merged Anivexa episode catalog for an AniList anime ID.
  @override
  Future<Map<String, dynamic>> anivexaMapMal(int malId) =>
      getJson('/anivexa/map-mal/$malId');

  @override
  Future<Map<String, dynamic>> anivexaEpisodes(int anilistId) =>
      getJson('/anivexa/episodes/$anilistId');

  /// Returns stream metadata for a provider/episode exposed by Anivexa.
  @override
  Future<Map<String, dynamic>> anivexaWatch({
    required String provider,
    required int anilistId,
    required String audio,
    required int episode,
  }) =>
      getJson(
        '/anivexa/watch/$provider/$anilistId/$audio/$episode',
      );

  Future<Map<String, dynamic>> playback(int malId, int episode) =>
      getJson('/playback/$malId/$episode');

  String _requestId() => 'flutter-${DateTime.now().microsecondsSinceEpoch}';

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query,
    );

    final started = DateTime.now();
    try {
      final response = await client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'X-Client-Version': apiVersion,
              'X-Request-ID': _requestId(),
            },
          )
          .timeout(const Duration(seconds: 15));

      final responseRequestId = response.headers['x-request-id'];

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          await _recordRequestSafely(
            path: path,
            latencyMs: DateTime.now().difference(started).inMilliseconds,
            success: true,
            statusCode: response.statusCode,
          );
          return decoded;
        }
        await _recordRequestSafely(
          path: path,
          latencyMs: DateTime.now().difference(started).inMilliseconds,
          success: false,
          statusCode: response.statusCode,
          message: 'invalid_response',
        );
        throw AnimeApiException(
          'استجابة API غير صالحة.', requestId: responseRequestId,
        );
      }

      String? serverMessage;
      bool degraded = false;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          serverMessage = decoded['message']?.toString();
          degraded = decoded['degraded'] == true;
        }
      } catch (_) {}


      await _recordRequestSafely(
        path: path,
        latencyMs: DateTime.now().difference(started).inMilliseconds,
        success: false,
        degraded: degraded,
        statusCode: response.statusCode,
        message: serverMessage,
      );

      if (response.statusCode == 429) {
        throw AnimeApiException(
          serverMessage ?? 'تم تجاوز حد الطلبات مؤقتًا. حاول بعد قليل.',
          statusCode: 429,
          requestId: responseRequestId,
          degraded: degraded,
        );
      }

      if (response.statusCode >= 500) {
        throw AnimeApiException(
          serverMessage ?? 'الخادم غير متاح مؤقتًا.',
          statusCode: response.statusCode,
          requestId: responseRequestId,
          degraded: degraded,
        );
      }

      throw AnimeApiException(
        serverMessage ?? 'تعذر تحميل البيانات (${response.statusCode}).',
        statusCode: response.statusCode,
        requestId: responseRequestId,
        degraded: degraded,
      );
    } on AnimeApiException {
      rethrow;
    } catch (error) {
      if (error is AnimeApiException) rethrow;
      await _recordRequestSafely(
        path: path,
        latencyMs: DateTime.now().difference(started).inMilliseconds,
        success: false,
        message: 'network_error',
      );
      throw AnimeApiException(
        'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.',
        requestId: null,
      );
    }
  }

  Future<void> _recordRequestSafely({
    required String path,
    required int latencyMs,
    required bool success,
    bool degraded = false,
    int? statusCode,
    String? message,
  }) async {
    try {
      await MonitoringService.instance.recordRequest(
        path: path,
        latencyMs: latencyMs,
        success: success,
        degraded: degraded,
        statusCode: statusCode,
        message: message,
      );
    } catch (_) {
      // Local diagnostics must never change the outcome of an API request.
    }
  }

  void dispose() => client.close();
}
