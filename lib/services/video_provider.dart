class VideoAsset {
  final String streamUrl;
  final String? downloadUrl;
  final List<VideoSubtitle> subtitles;
  final String provider;
  final String? licenseId;

  const VideoAsset({
    required this.streamUrl,
    required this.provider,
    this.licenseId,
    this.downloadUrl,
    this.subtitles = const [],
  });
}

class VideoSubtitle {
  final String language;
  final String url;

  const VideoSubtitle({required this.language, required this.url});
}

abstract class VideoProvider {
  /// Only a provider with explicit distribution rights may return an asset.
  Future<VideoAsset?> getEpisodeVideo({
    required int animeId,
    required int episodeNumber,
  });
}

class NoOpVideoProvider implements VideoProvider {
  const NoOpVideoProvider();
  @override
  Future<VideoAsset?> getEpisodeVideo({
    required int animeId,
    required int episodeNumber,
  }) async {
    return null;
  }
}
