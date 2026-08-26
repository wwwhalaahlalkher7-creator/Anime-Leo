import 'package:shared_preferences/shared_preferences.dart';

/// Local-only diagnostics for V1.20.0. Nothing is uploaded or shared remotely.
class MonitoringSnapshot {
  final int requests;
  final int successes;
  final int failures;
  final int degraded;
  final int healthChecks;
  final int healthFailures;
  final int totalLatencyMs;
  final String? lastPath;
  final int? lastStatusCode;
  final String? lastMessage;

  const MonitoringSnapshot({
    required this.requests,
    required this.successes,
    required this.failures,
    required this.degraded,
    required this.healthChecks,
    required this.healthFailures,
    required this.totalLatencyMs,
    required this.lastPath,
    required this.lastStatusCode,
    required this.lastMessage,
  });

  int get averageLatencyMs => requests == 0 ? 0 : totalLatencyMs ~/ requests;
  double get successRate => requests == 0 ? 0 : successes * 100 / requests;
}

class MonitoringService {
  static final MonitoringService instance = MonitoringService._();
  MonitoringService._();

  static const int _schemaVersion = 2;
  SharedPreferences? _prefs;
  MonitoringSnapshot _snapshot = const MonitoringSnapshot(
    requests: 0,
    successes: 0,
    failures: 0,
    degraded: 0,
    healthChecks: 0,
    healthFailures: 0,
    totalLatencyMs: 0,
    lastPath: null,
    lastStatusCode: null,
    lastMessage: null,
  );

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (_prefs!.getInt('monitoring_schema_version') != _schemaVersion) {
      await _resetStoredCounters();
      await _prefs!.setInt('monitoring_schema_version', _schemaVersion);
    }
    _snapshot = MonitoringSnapshot(
      requests: _get('requests'),
      successes: _get('successes'),
      failures: _get('failures'),
      degraded: _get('degraded'),
      healthChecks: _get('healthChecks'),
      healthFailures: _get('healthFailures'),
      totalLatencyMs: _get('totalLatencyMs'),
      lastPath: _prefs!.getString('lastPath'),
      lastStatusCode: _prefs!.getInt('lastStatusCode'),
      lastMessage: _prefs!.getString('lastMessage'),
    );
  }

  int _get(String key) => _prefs?.getInt(key) ?? 0;

  MonitoringSnapshot get snapshot => _snapshot;

  Future<void> recordRequest({
    required String path,
    required int latencyMs,
    required bool success,
    bool degraded = false,
    int? statusCode,
    String? message,
  }) async {
    final current = _snapshot;
    _snapshot = MonitoringSnapshot(
      requests: current.requests + 1,
      successes: current.successes + (success ? 1 : 0),
      failures: current.failures + (success ? 0 : 1),
      degraded: current.degraded + (degraded ? 1 : 0),
      healthChecks: current.healthChecks,
      healthFailures: current.healthFailures,
      totalLatencyMs: current.totalLatencyMs + latencyMs,
      lastPath: path,
      lastStatusCode: statusCode,
      lastMessage: message,
    );
    await _persist();
  }

  Future<void> recordHealth({required bool success}) async {
    final current = _snapshot;
    _snapshot = MonitoringSnapshot(
      requests: current.requests,
      successes: current.successes,
      failures: current.failures,
      degraded: current.degraded,
      healthChecks: current.healthChecks + 1,
      healthFailures: current.healthFailures + (success ? 0 : 1),
      totalLatencyMs: current.totalLatencyMs,
      lastPath: current.lastPath,
      lastStatusCode: current.lastStatusCode,
      lastMessage: current.lastMessage,
    );
    await _persist();
  }

  Future<void> _resetStoredCounters() async {
    for (final key in const [
      'requests', 'successes', 'failures', 'degraded', 'healthChecks',
      'healthFailures', 'totalLatencyMs', 'lastPath', 'lastStatusCode', 'lastMessage',
    ]) {
      await _prefs!.remove(key);
    }
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final s = _snapshot;
    await Future.wait([
      prefs.setInt('requests', s.requests),
      prefs.setInt('successes', s.successes),
      prefs.setInt('failures', s.failures),
      prefs.setInt('degraded', s.degraded),
      prefs.setInt('healthChecks', s.healthChecks),
      prefs.setInt('healthFailures', s.healthFailures),
      prefs.setInt('totalLatencyMs', s.totalLatencyMs),
      _setOrRemove('lastPath', s.lastPath),
      _setOrRemove('lastMessage', s.lastMessage),
      _setOrRemoveInt('lastStatusCode', s.lastStatusCode),
    ]);
  }

  Future<void> _setOrRemove(String key, String? value) async {
    if (value == null) {
      await _prefs!.remove(key);
    } else {
      await _prefs!.setString(key, value);
    }
  }

  Future<void> _setOrRemoveInt(String key, int? value) async {
    if (value == null) {
      await _prefs!.remove(key);
    } else {
      await _prefs!.setInt(key, value);
    }
  }

  Future<void> clear() async {
    _snapshot = const MonitoringSnapshot(
      requests: 0,
      successes: 0,
      failures: 0,
      degraded: 0,
      healthChecks: 0,
      healthFailures: 0,
      totalLatencyMs: 0,
      lastPath: null,
      lastStatusCode: null,
      lastMessage: null,
    );
    final prefs = _prefs;
    if (prefs == null) return;
    for (final key in const [
      'requests', 'successes', 'failures', 'degraded', 'healthChecks',
      'healthFailures', 'totalLatencyMs', 'lastPath', 'lastStatusCode', 'lastMessage',
    ]) {
      await prefs.remove(key);
    }
  }
}
