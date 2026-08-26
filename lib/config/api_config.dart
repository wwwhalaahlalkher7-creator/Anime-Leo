/// Centralized API configuration for Anime Leo.
///
/// All API base URLs and provider switches should be configured here.
/// Secrets MUST NOT be placed in this file or in the APK.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8787/api',
  );

  // Provider feature flags. Keep these as non-secret configuration.
  static const bool enableOpenSubtitles = bool.fromEnvironment(
    'ENABLE_OPENSUBTITLES',
    defaultValue: false,
  );

  static const bool enableVideoProvider = bool.fromEnvironment(
    'ENABLE_VIDEO_PROVIDER',
    defaultValue: false,
  );

  static Uri endpoint(String path, [Map<String, String>? query]) {
    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath').replace(
      queryParameters: query,
    );
  }
}
