import 'package:flutter_test/flutter_test.dart';

import 'package:anime_platform_mobile/config/api_config.dart';
import 'package:anime_platform_mobile/core/config.dart' as app_config;
import 'package:anime_platform_mobile/models/anime.dart';
import 'package:anime_platform_mobile/services/video_provider.dart';

void main() {
  test('V1.29 API configuration has one production base URL', () {
    expect(ApiConfig.baseUrl, startsWith('https://'));
    expect(ApiConfig.baseUrl, app_config.apiBaseUrl);
    expect(app_config.apiVersion, '1.29');
  });

  test('Anime keeps MAL/catalog ID separate from AniList ID', () {
    final anime = Anime.fromJson({
      'id': 20,
      'anilistId': 1535,
      'title': 'Death Note',
      'image': 'https://example.com/image.jpg',
    });

    expect(anime.id, 20);
    expect(anime.anilistId, 1535);
    expect(anime.id, isNot(anime.anilistId));
  });

  test('Anime identity normalization keeps MAL ID canonical and provider IDs separate', () {
    final anime = Anime.fromJson({
      'id': -1535,
      'canonicalId': 'mal:20',
      'malId': 20,
      'anilistId': 1535,
      'providerId': '1535',
      'provider': 'anilist',
      'title': 'Death Note',
      'image': 'https://example.com/image.jpg',
    });

    expect(anime.id, -1535);
    expect(anime.canonicalId, 'mal:20');
    expect(anime.malId, 20);
    expect(anime.anilistId, 1535);
  });

  test('Legacy negative AniList IDs are never treated as MAL playback IDs', () {
    final anime = Anime.fromJson({
      'id': -1535,
      'mal_id': -1535,
      'anilistId': 1535,
      'title': 'Unknown MAL mapping',
      'image': '',
    });

    expect(anime.malId, isNull);
    expect(anime.anilistId, 1535);
  });

  test('VideoAsset parses qualities and subtitles', () {
    final asset = VideoAsset.fromJson({
      'url': 'https://example.com/video.m3u8',
      'provider': 'authorized-provider',
      'qualities': [
        {'label': '1080p', 'url': 'https://example.com/1080.m3u8'},
        {'label': '720p', 'url': 'https://example.com/720.m3u8'},
      ],
      'subtitles': [
        {'language': 'ar', 'url': 'https://example.com/ar.vtt'},
        {'language': 'en', 'url': 'https://example.com/en.vtt'},
      ],
    });

    expect(asset.streamUrl, contains('.m3u8'));
    expect(asset.isHls, isTrue);
    expect(asset.qualities.map((q) => q.label), containsAll(<String>['1080p', '720p']));
    expect(asset.subtitles.map((s) => s.language), containsAll(<String>['ar', 'en']));
  });
}
