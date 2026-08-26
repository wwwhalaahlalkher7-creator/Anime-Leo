import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Optional, on-demand translation. The original synopsis remains the source
/// of truth; Arabic is cached locally after a successful translation.
class TranslationService {
  static final TranslationService instance = TranslationService._();
  TranslationService._();

  final http.Client _client = http.Client();

  Future<String?> toArabic({required int animeId, required String text}) async {
    final source = text.trim();
    if (source.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final key = 'synopsis_ar_$animeId';
    final cached = prefs.getString(key);
    if (cached != null && cached.trim().isNotEmpty) return cached;

    try {
      final translated = await _translate(source);
      if (translated == null || translated.trim().isEmpty) return null;
      await prefs.setString(key, translated.trim());
      return translated.trim();
    } catch (_) {
      return null;
    }
  }

  Future<String?> toArabicGeneric({required String key, required String text}) async {
    final source = text.trim();
    if (source.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'translation_ar_${key.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_')}';
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.trim().isNotEmpty) return cached;
    try {
      final translated = await _translate(source);
      if (translated == null || translated.trim().isEmpty) return null;
      await prefs.setString(cacheKey, translated.trim());
      return translated.trim();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _translate(String text) async {
    // Keep requests modest and preserve paragraph boundaries as much as possible.
    final chunks = <String>[];
    var remaining = text;
    // MyMemory commonly rejects requests above ~500 characters. Keep a safety margin.
    const maxQueryChars = 420;
    while (remaining.length > maxQueryChars) {
      var cut = remaining.lastIndexOf(' ', maxQueryChars);
      if (cut < 180) cut = maxQueryChars;
      chunks.add(remaining.substring(0, cut));
      remaining = remaining.substring(cut).trimLeft();
    }
    if (remaining.isNotEmpty) chunks.add(remaining);

    final output = <String>[];
    for (final chunk in chunks) {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {
        'q': chunk,
        'langpair': 'en|ar',
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      String? translated;
      if (body is Map<String, dynamic>) {
        final responseData = body['responseData'];
        if (responseData is Map<String, dynamic>) {
          final value = responseData['translatedText'];
          if (value != null) translated = value.toString();
        }
      }
      if (translated == null || translated.trim().isEmpty) return null;
      output.add(translated.trim());
    }
    return output.join('\n\n');
  }

  void dispose() => _client.close();
}
