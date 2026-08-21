import 'anime_api_service.dart';
class VideoAsset {
  final String streamUrl;
  final String? downloadUrl;
  final List<VideoSubtitle> subtitles;
  final String provider;
  final String? licenseId;
  final String? mimeType;
  final List<VideoQuality> qualities;

  const VideoAsset({
    required this.streamUrl,
    required this.provider,
    this.licenseId,
    this.downloadUrl,
    this.subtitles = const [],
    this.mimeType,
    this.qualities = const [],
  });

  bool get isHls =>
      streamUrl.toLowerCase().contains('.m3u8') ||
      mimeType?.toLowerCase() == 'application/x-mpegurl';

  factory VideoAsset.fromJson(Map<String, dynamic> json) {
    final rawSubs = json['subtitles'];
    final rawQualities = json['qualities'];

    return VideoAsset(
      streamUrl: (json['streamUrl'] ?? json['url'] ?? '').toString(),
      downloadUrl: json['downloadUrl']?.toString(),
      provider: (json['provider'] ?? 'unknown').toString(),
      licenseId: json['licenseId']?.toString(),
      mimeType: json['mimeType']?.toString(),
      subtitles: rawSubs is List
          ? rawSubs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).map((e) => VideoSubtitle(
                language: (e['language'] ?? e['lang'] ?? '').toString(),
                url: (e['url'] ?? '').toString(),
              )).where((e) => e.url.isNotEmpty).toList()
          : const [],
      qualities: rawQualities is List
          ? rawQualities.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).map((e) => VideoQuality(
                label: (e['label'] ?? e['quality'] ?? '').toString(),
                url: (e['url'] ?? '').toString(),
                downloadUrl: e['downloadUrl']?.toString(),
              )).where((e) => e.url.isNotEmpty).toList()
          : const [],
    );
  }
}

class VideoQuality {
  final String label;
  final String url;
  final String? downloadUrl;

  const VideoQuality({required this.label, required this.url, this.downloadUrl});
}

class VideoSubtitle {
  final String language;
  final String url;

  const VideoSubtitle({required this.language, required this.url});
}

abstract class VideoProvider {
  Future<VideoAsset?> getEpisodeVideo({
    required int animeId,
    required int episodeNumber,
  });

  Future<List<VideoAsset>> getEpisodeVideos({
    required int animeId,
    required int episodeNumber,
  }) async {
    final asset = await getEpisodeVideo(animeId: animeId, episodeNumber: episodeNumber);
    return asset == null ? const [] : [asset];
  }
}

class BackendVideoProvider implements VideoProvider {
  final AnimeApiService api;
  BackendVideoProvider({AnimeApiService? api}) : api = api ?? AnimeApiService();

  static const providerPriority = <String>[
    'mkissa', 'reanime', 'anikoto', 'animegg', 'anineko', 'anidbapp',
    '2dhive', 'animenosub', 'anizone', 'anibd', 'senshi', 'kaa', 'animedunya',
  ];

  @override
  Future<VideoAsset?> getEpisodeVideo({required int animeId, required int episodeNumber}) async {
    final assets = await getEpisodeVideos(animeId: animeId, episodeNumber: episodeNumber);
    return assets.isEmpty ? null : assets.first;
  }

  @override
  Future<List<VideoAsset>> getEpisodeVideos({required int animeId, required int episodeNumber}) async {
    // The playback contract accepts MAL IDs only. Catalog/provider IDs are
    // never sent to playback as if they were MAL IDs.
    final malId = animeId;
    if (malId <= 0) return const [];
    // V1.29 primary source: ani-cli-arabic. It consumes the catalog MAL id
    // directly, so playback does not depend on an AniList id being present.
    try {
      final response = await api.getJson('/playback/$malId/$episodeNumber');
      final primary = _assetsFromPlaybackResponse('ani-cli-arabic', response);
      if (primary.isNotEmpty) return primary;
    } catch (_) {
      // Fall through to the existing Anivexa provider chain.
    }

    // Secondary provider chain retained for resilience.
    final mappingResponse = await api.getJson('/anivexa/map-mal/$malId');
    final anilistId = _asInt(mappingResponse['anilistId']);
    if (anilistId == null || anilistId <= 0) return const [];

    final episodeResponse = await api.anivexaEpisodes(anilistId);
    final assets = <VideoAsset>[];

    for (final provider in providerPriority) {
      final rawProviderData = episodeResponse[provider];
      if (rawProviderData is! Map) continue;
      final providerData = <String, dynamic>{
        for (final entry in rawProviderData.entries)
          entry.key.toString(): entry.value,
      };
      if (providerData['error'] != null) continue;
      if (!_providerHasEpisode(providerData, episodeNumber)) continue;
      try {
        final watch = await api.anivexaWatch(
          provider: provider,
          anilistId: anilistId,
          audio: 'sub',
          episode: episodeNumber,
        );
        final asset = _assetFromWatchResponse(provider, watch);
        if (asset != null) assets.add(asset);
      } catch (_) {
        // A provider can be temporarily unavailable. Continue to the next
        // authorized provider instead of failing the complete playback flow.
      }
    }

    return assets;
  }

  List<VideoAsset> _assetsFromPlaybackResponse(String provider, Map<String, dynamic> data) {
    final assets = <VideoAsset>[];
    final rawStreams = data['streams'];
    final subtitles = <VideoSubtitle>[];
    final rawSubs = data['subtitles'];
    if (rawSubs is List) {
      for (final item in rawSubs.whereType<Map>()) {
        final url = (item['url'] ?? item['src'] ?? '').toString();
        if (url.isEmpty) continue;
        subtitles.add(VideoSubtitle(
          language: (item['language'] ?? item['lang'] ?? 'en').toString(),
          url: url,
        ));
      }
    }
    if (rawStreams is List) {
      final qualities = <VideoQuality>[];
      for (final item in rawStreams.whereType<Map>()) {
        final url = (item['url'] ?? '').toString();
        if (url.isEmpty) continue;
        qualities.add(VideoQuality(
          label: (item['quality'] ?? item['label'] ?? 'auto').toString(),
          url: url,
          downloadUrl: item['downloadUrl']?.toString(),
        ));
      }
      if (qualities.isNotEmpty) {
        assets.add(VideoAsset(
          streamUrl: qualities.first.url,
          downloadUrl: qualities.first.downloadUrl,
          provider: provider,
          subtitles: subtitles,
          qualities: qualities,
          mimeType: rawStreams.first is Map ? rawStreams.first['type']?.toString() : null,
        ));
      }
    }
    return assets;
  }

  bool _providerHasEpisode(Map<String, dynamic> providerData, int number) {
    final raw = providerData['episodes'];
    if (raw is Map) {
      for (final value in raw.values) {
        if (value is List && value.any((e) => _episodeNumber(e) == number)) return true;
      }
    }
    if (raw is List && raw.any((e) => _episodeNumber(e) == number)) return true;
    return false;
  }

  int _episodeNumber(dynamic value) {
    if (value is! Map) return 0;
    return _asInt(value['number'] ?? value['episode'] ?? value['ep']) ?? 0;
  }

  VideoAsset? _assetFromWatchResponse(String provider, Map<String, dynamic> data) {
    final subtitles = <VideoSubtitle>[];
    final rawSubs = data['subtitles'];
    if (rawSubs is List) {
      for (final item in rawSubs.whereType<Map>()) {
        final url = item['url']?.toString() ?? item['src']?.toString() ?? '';
        if (url.isEmpty) continue;
        final lang = item['language']?.toString() ?? item['lang']?.toString() ?? 'en';
        subtitles.add(VideoSubtitle(language: lang, url: url));
      }
    }

    final urls = <VideoQuality>[];
    void add(dynamic value, String label) {
      if (value is! String || value.trim().isEmpty) return;
      final uri = Uri.tryParse(value);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return;
      if (urls.any((q) => q.url == value)) return;
      urls.add(VideoQuality(label: label, url: value, downloadUrl: value));
    }

    final streams = data['streams'];
    if (streams is List) {
      for (final item in streams.whereType<Map>()) {
        add(item['url']?.toString(), item['quality']?.toString() ?? item['label']?.toString() ?? 'auto');
      }
    }
    final sources = data['sources'];
    if (sources is List) {
      for (final item in sources.whereType<Map>()) {
        add(item['url']?.toString(), item['quality']?.toString() ?? item['label']?.toString() ?? 'auto');
      }
    }
    add(data['stream_url']?.toString(), 'auto');
    add(data['streamUrl']?.toString(), 'auto');
    add(data['url']?.toString(), 'auto');
    add(data['redirect_url']?.toString(), 'redirect');

    if (urls.isEmpty) return null;
    return VideoAsset(
      streamUrl: urls.first.url,
      downloadUrl: urls.first.downloadUrl,
      provider: provider,
      subtitles: subtitles,
      qualities: urls,
      mimeType: data['mimeType']?.toString(),
    );
  }

  int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}

class NoOpVideoProvider implements VideoProvider {
  const NoOpVideoProvider();

  @override
  Future<VideoAsset?> getEpisodeVideo({required int animeId, required int episodeNumber}) async => null;

  @override
  Future<List<VideoAsset>> getEpisodeVideos({required int animeId, required int episodeNumber}) async => const [];
}
