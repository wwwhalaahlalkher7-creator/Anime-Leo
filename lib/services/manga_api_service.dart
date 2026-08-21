import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class MangaChapter {
  final String id;
  final String? chapter;
  final String? title;
  final String? volume;
  final String? language;
  final String? publishAt;
  final int pages;
  final String? group;

  const MangaChapter({required this.id, this.chapter, this.title, this.volume, this.language, this.publishAt, this.pages = 0, this.group});

  factory MangaChapter.fromJson(Map<String, dynamic> json) => MangaChapter(
    id: json['id']?.toString() ?? '',
    chapter: json['chapter']?.toString(),
    title: json['title']?.toString(),
    volume: json['volume']?.toString(),
    language: json['translatedLanguage']?.toString(),
    publishAt: json['publishAt']?.toString(),
    pages: (json['pages'] as num?)?.toInt() ?? 0,
    group: json['group']?.toString(),
  );
}

class MangaApiService {
  final String baseUrl;
  final http.Client client;

  MangaApiService({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? apiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
        client = client ?? http.Client();

  Future<List<MangaChapter>> chapters(String mangaId) async {
    final uri = Uri.parse('$baseUrl/manga/${Uri.encodeComponent(mangaId)}/chapters').replace(queryParameters: {
      'page': '1',
      'limit': '100',
      'language': 'ar',
    });
    final response = await client.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) throw Exception(decoded is Map ? decoded['message']?.toString() ?? 'تعذر تحميل الفصول.' : 'تعذر تحميل الفصول.');
    final data = decoded is Map ? decoded['data'] : null;
    return data is List ? data.whereType<Map>().map((e) => MangaChapter.fromJson(Map<String, dynamic>.from(e))).where((e) => e.id.isNotEmpty).toList() : [];
  }

  Future<List<String>> pages(String chapterId) async {
    final uri = Uri.parse('$baseUrl/manga/chapter/${Uri.encodeComponent(chapterId)}');
    final response = await client.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) throw Exception(decoded is Map ? decoded['message']?.toString() ?? 'تعذر تحميل الصفحات.' : 'تعذر تحميل الصفحات.');
    final pages = decoded is Map ? decoded['pages'] : null;
    return pages is List ? pages.map((e) => e.toString()).toList() : [];
  }

  void dispose() => client.close();
}
