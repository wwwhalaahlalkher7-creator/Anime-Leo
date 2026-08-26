import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class CatalogApiService {
  final String baseUrl;
  final http.Client client;

  CatalogApiService({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? apiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
        client = client ?? http.Client();

  Future<Map<String, dynamic>> page(String kind, {int page = 1, int limit = 24, String? category}) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (category != null && category.trim().isNotEmpty) params['category'] = category.trim();
    final uri = Uri.parse('$baseUrl/$kind').replace(queryParameters: params);
    final response = await client.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw Exception(message ?? 'تعذر تحميل البيانات.');
    }
    if (decoded is! Map<String, dynamic>) throw Exception('استجابة غير صالحة.');
    return decoded;
  }

  void dispose() => client.close();
}
