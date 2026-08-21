import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'monitoring_service.dart';

class BackendStatus {
  final bool online;
  final String message;

  const BackendStatus({
    required this.online,
    required this.message,
  });
}

class BackendService {
  final String baseUrl;
  final http.Client client;

  BackendService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? apiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
        client = client ?? http.Client();

  Future<BackendStatus> checkHealth() async {
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl/health'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        await _recordHealthSafely(false);
        return BackendStatus(
          online: false,
          message: 'الخادم أعاد ${response.statusCode}',
        );
      }

      final body = jsonDecode(response.body);
      final status = body is Map ? body['status']?.toString() : null;

      await _recordHealthSafely(status == 'ok');
      return BackendStatus(
        online: status == 'ok',
        message: status == 'ok' ? 'الخادم يعمل' : 'استجابة غير متوقعة',
      );
    } catch (error) {
      await _recordHealthSafely(false);
      return BackendStatus(
        online: false,
        message: _friendlyNetworkError(error),
      );
    }
  }

  Future<void> _recordHealthSafely(bool success) async {
    try {
      await MonitoringService.instance.recordHealth(success: success);
    } catch (_) {
      // Local diagnostics must never make the health check fail.
    }
  }

  String _friendlyNetworkError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') || raw.contains('failed host lookup')) {
      return 'تعذر الوصول إلى الخادم من التطبيق. تحقق من صلاحية الإنترنت.';
    }
    if (raw.contains('timeout')) {
      return 'انتهت مهلة الاتصال بالخادم.';
    }
    if (raw.contains('certificate') || raw.contains('handshake')) {
      return 'تعذر إنشاء اتصال آمن بالخادم.';
    }
    return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.';
  }

  void dispose() => client.close();
}
