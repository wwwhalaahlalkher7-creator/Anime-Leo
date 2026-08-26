import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class RemoteConfig {
  final bool ads;
  final bool analytics;
  final bool video;
  final bool legalVideoArchitecture;
  final bool maintenanceMode;
  final int cacheSeconds;
  final String appVersion;
  final String minimumAppVersion;
  final int maxPageSize;
  final int maxQueryLength;
  final bool monetizationEnabled;
  final String monetizationProvider;
  final bool monetizationConsentRequired;

  const RemoteConfig({
    required this.ads,
    required this.analytics,
    required this.video,
    required this.legalVideoArchitecture,
    required this.maintenanceMode,
    required this.cacheSeconds,
    required this.appVersion,
    required this.minimumAppVersion,
    required this.maxPageSize,
    required this.maxQueryLength,
    required this.monetizationEnabled,
    required this.monetizationProvider,
    required this.monetizationConsentRequired,
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    final features = json['features'];
    final featureMap = features is Map ? Map<String, dynamic>.from(features) : <String, dynamic>{};
    final limits = json['searchLimits'];
    final limitMap = limits is Map ? Map<String, dynamic>.from(limits) : <String, dynamic>{};

    return RemoteConfig(
      ads: featureMap['ads'] == true,
      analytics: featureMap['analytics'] == true,
      video: featureMap['video'] == true,
      legalVideoArchitecture: featureMap['legalVideoArchitecture'] == true,
      maintenanceMode: json['maintenanceMode'] == true,
      cacheSeconds: (json['cacheSeconds'] as num?)?.toInt() ?? 900,
      appVersion: json['appVersion']?.toString() ?? '',
      minimumAppVersion: json['minimumAppVersion']?.toString() ?? '',
      maxPageSize: (limitMap['maxPageSize'] as num?)?.toInt() ?? 24,
      maxQueryLength: (limitMap['maxQueryLength'] as num?)?.toInt() ?? 80,
      monetizationEnabled: (json['monetization'] is Map) && (json['monetization']['enabled'] == true),
      monetizationProvider: (json['monetization'] is Map) ? (json['monetization']['provider']?.toString() ?? 'none') : 'none',
      monetizationConsentRequired: (json['monetization'] is Map) ? (json['monetization']['consentRequired'] != false) : true,
    );
  }

  RemoteConfig copyWith({
    bool? ads,
    bool? analytics,
    bool? video,
    bool? monetizationEnabled,
    String? monetizationProvider,
    bool? monetizationConsentRequired,
  }) => RemoteConfig(
        ads: ads ?? this.ads,
        analytics: analytics ?? this.analytics,
        video: video ?? this.video,
        legalVideoArchitecture: legalVideoArchitecture,
        maintenanceMode: maintenanceMode,
        cacheSeconds: cacheSeconds,
        appVersion: appVersion,
        minimumAppVersion: minimumAppVersion,
        maxPageSize: maxPageSize,
        maxQueryLength: maxQueryLength,
        monetizationEnabled: monetizationEnabled ?? this.monetizationEnabled,
        monetizationProvider: monetizationProvider ?? this.monetizationProvider,
        monetizationConsentRequired: monetizationConsentRequired ?? this.monetizationConsentRequired,
      );

  static const disabled = RemoteConfig(
    ads: false,
    analytics: false,
    video: false,
    legalVideoArchitecture: true,
    maintenanceMode: false,
    cacheSeconds: 900,
    appVersion: '',
    minimumAppVersion: '',
    maxPageSize: 24,
    maxQueryLength: 80,
    monetizationEnabled: false,
    monetizationProvider: 'none',
    monetizationConsentRequired: true,
  );
}

class RemoteConfigService {
  final String baseUrl;
  final http.Client client;

  RemoteConfigService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? apiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
        client = client ?? http.Client();

  Future<RemoteConfig> fetch() async {
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl/config'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return RemoteConfig.disabled;

      final data = jsonDecode(response.body);
      if (data is! Map) return RemoteConfig.disabled;

      return RemoteConfig.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return RemoteConfig.disabled;
    }
  }

  void dispose() => client.close();
}
