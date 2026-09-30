import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class CatalogApiException implements Exception {
  final String message;
  final int? statusCode;
  final String endpoint;
  final Object? cause;
  const CatalogApiException(this.message, {this.statusCode, required this.endpoint, this.cause});
  @override
  String toString() => [message, if (statusCode != null) 'HTTP $statusCode', endpoint, if (cause != null) 'cause=${cause.runtimeType}'].join(' • ');
}

class CatalogApiService {
  final String baseUrl;
  final http.Client client;

  CatalogApiService({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? apiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
        client = client ?? http.Client();

  Future<Map<String, dynamic>> page(String kind, {int page = 1, int limit = 24, String? category}) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (category != null && category.trim().isNotEmpty) params['category'] = category.trim();
    final uri = Uri.parse('$baseUrl/$kind').replace(queryParameters: params);
    try {
      final response = await client.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
      dynamic decoded;
      try { decoded = jsonDecode(response.body); } catch (e) {
        throw CatalogApiException('المصدر أعاد ردًا غير صالح JSON. السبب: ${e.runtimeType}', statusCode: response.statusCode, endpoint: uri.toString(), cause: e);
      }
      if (response.statusCode != 200) {
        final message = decoded is Map ? decoded['message']?.toString() ?? decoded['error']?.toString() : null;
        throw CatalogApiException('فشل تحميل قسم $kind: ${message ?? 'الخادم لم يرسل سببًا واضحًا.'}', statusCode: response.statusCode, endpoint: uri.toString());
      }
      if (decoded is! Map<String, dynamic>) throw CatalogApiException('فشل تحميل قسم $kind: بنية الاستجابة غير متوقعة.', statusCode: response.statusCode, endpoint: uri.toString());
      return decoded;
    } catch (e) {
      if (e is CatalogApiException) rethrow;
      throw CatalogApiException('فشل الاتصال بمصدر قسم $kind. السبب: ${e.runtimeType} — $e', endpoint: uri.toString(), cause: e);
    }
  }

  void dispose() => client.close();
}
