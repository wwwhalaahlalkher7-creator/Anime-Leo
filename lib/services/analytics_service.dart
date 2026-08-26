import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

abstract class AnalyticsService {
  Future<void> initialize();
  Future<void> track(String event, {Map<String, Object?> parameters = const {}});
  Future<void> dispose();
}

class NoOpAnalyticsService implements AnalyticsService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> track(
    String event, {
    Map<String, Object?> parameters = const {},
  }) async {}

  @override
  Future<void> dispose() async {}
}

/// Anonymous analytics implementation. It sends only explicitly supplied
/// non-sensitive event data and is normally disabled by Remote Config.
class RemoteAnalyticsService implements AnalyticsService {
  final String baseUrl;
  final http.Client client;
  bool _initialized = false;

  RemoteAnalyticsService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? apiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
        client = client ?? http.Client();

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<void> track(
    String event, {
    Map<String, Object?> parameters = const {},
  }) async {
    if (!_initialized) return;
    try {
      await client
          .post(
            Uri.parse('$baseUrl/events'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-Client-Version': apiVersion,
            },
            body: jsonEncode({
              'event': event,
              'platform': 'flutter',
              'appVersion': appVersion,
              'parameters': parameters,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Analytics must never break the user experience.
    }
  }

  @override
  Future<void> dispose() async => client.close();
}
