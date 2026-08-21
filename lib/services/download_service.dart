import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadTask {
  final String id;
  final int animeId;
  final int episode;
  final String title;
  final String filePath;
  final String quality;
  final String url;
  final int downloadedBytes;
  final int? totalBytes;
  final String status;
  final String? error;

  const DownloadTask({
    required this.id,
    required this.animeId,
    required this.episode,
    required this.title,
    required this.filePath,
    required this.quality,
    required this.url,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.status,
    this.error,
  });

  double? get progress => totalBytes != null && totalBytes! > 0
      ? downloadedBytes / totalBytes!
      : null;

  bool get completed => status == 'completed' && File(filePath).existsSync();

  Map<String, dynamic> toJson() => {
        'id': id,
        'animeId': animeId,
        'episode': episode,
        'title': title,
        'filePath': filePath,
        'quality': quality,
        'url': url,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'status': status,
        'error': error,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> j) => DownloadTask(
        id: '${j['id']}',
        animeId: (j['animeId'] as num?)?.toInt() ?? 0,
        episode: (j['episode'] as num?)?.toInt() ?? 0,
        title: '${j['title'] ?? ''}',
        filePath: '${j['filePath'] ?? ''}',
        quality: '${j['quality'] ?? 'auto'}',
        url: '${j['url'] ?? ''}',
        downloadedBytes: (j['downloadedBytes'] as num?)?.toInt() ?? 0,
        totalBytes: (j['totalBytes'] as num?)?.toInt(),
        status: '${j['status'] ?? 'queued'}',
        error: j['error']?.toString(),
      );
}

class DownloadService {
  static final DownloadService instance = DownloadService._();
  DownloadService._();

  static const _key = 'download_tasks_v1';
  final http.Client _client = http.Client();
  final Map<String, StreamController<DownloadTask>> _controllers = {};
  final Set<String> _cancelled = {};

  Future<List<DownloadTask>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final tasks = <DownloadTask>[];
    for (final item in raw) {
      try {
        final task = DownloadTask.fromJson(jsonDecode(item));
        if (task.filePath.isNotEmpty && !File(task.filePath).existsSync() && task.status == 'completed') {
          continue;
        }
        tasks.add(task);
      } catch (_) {}
    }
    return tasks;
  }

  Future<void> _save(List<DownloadTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, tasks.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> _upsert(DownloadTask task) async {
    final tasks = await list();
    final i = tasks.indexWhere((e) => e.id == task.id);
    if (i >= 0) {
      tasks[i] = task;
    } else {
      tasks.insert(0, task);
    }
    await _save(tasks);
    _controllers[task.id]?.add(task);
  }

  Stream<DownloadTask> watch(String id) {
    return (_controllers[id] ??= StreamController<DownloadTask>.broadcast()).stream;
  }

  Future<Directory> _directory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/AnimeLeo/Downloads');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<DownloadTask> start({
    required int animeId,
    required int episode,
    required String title,
    required String url,
    required String quality,
  }) async {
    final id = '${animeId}_$episode';
    final dir = await _directory();
    final safe = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_').replaceAll(RegExp(r'_+'), '_');
    final file = File('${dir.path}/${safe.isEmpty ? 'anime' : safe}_E${episode}_$quality.mp4');
    _cancelled.remove(id);
    final existing = (await list()).where((e) => e.id == id).firstOrNull;
    final initial = DownloadTask(
      id: id,
      animeId: animeId,
      episode: episode,
      title: title,
      filePath: file.path,
      quality: quality,
      url: url,
      downloadedBytes: file.existsSync() ? file.lengthSync() : 0,
      totalBytes: existing?.totalBytes,
      status: 'downloading',
    );
    await _upsert(initial);

    unawaited(_run(initial, url));
    return initial;
  }

  Future<void> _run(DownloadTask task, String url) async {
    try {
      var startAt = File(task.filePath).existsSync() ? File(task.filePath).lengthSync() : 0;
      var response = await _client.send(http.Request('GET', Uri.parse(url))..headers['Range'] = 'bytes=$startAt-');
      if (startAt > 0 && response.statusCode != 206) {
        startAt = 0;
        response = await _client.send(http.Request('GET', Uri.parse(url)));
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download failed: HTTP ${response.statusCode}');
      }
      final total = response.contentLength == null ? null : startAt + response.contentLength!;
      final file = File(task.filePath);
      final sink = file.openWrite(mode: startAt > 0 ? FileMode.append : FileMode.write);
      var downloaded = startAt;
      var lastUpdate = DateTime.now();
      await for (final chunk in response.stream) {
        if (_cancelled.contains(task.id)) {
          await sink.close();
          return;
        }
        sink.add(chunk);
        downloaded += chunk.length;
        if (DateTime.now().difference(lastUpdate).inMilliseconds > 350) {
          lastUpdate = DateTime.now();
          await _upsert(DownloadTask(id: task.id, animeId: task.animeId, episode: task.episode, title: task.title, filePath: task.filePath, quality: task.quality, url: task.url, downloadedBytes: downloaded, totalBytes: total, status: 'downloading'));
        }
      }
      await sink.close();
      await _upsert(DownloadTask(id: task.id, animeId: task.animeId, episode: task.episode, title: task.title, filePath: task.filePath, quality: task.quality, url: task.url, downloadedBytes: downloaded, totalBytes: total, status: 'completed'));
    } catch (e) {
      await _upsert(DownloadTask(id: task.id, animeId: task.animeId, episode: task.episode, title: task.title, filePath: task.filePath, quality: task.quality, url: task.url, downloadedBytes: File(task.filePath).existsSync() ? File(task.filePath).lengthSync() : 0, totalBytes: task.totalBytes, status: 'failed', error: e.toString()));
    }
  }

  Future<void> cancel(String id) async {
    _cancelled.add(id);
    final tasks = await list();
    final task = tasks.where((e) => e.id == id).firstOrNull;
    if (task != null) await _upsert(DownloadTask(id: task.id, animeId: task.animeId, episode: task.episode, title: task.title, filePath: task.filePath, quality: task.quality, url: task.url, downloadedBytes: task.downloadedBytes, totalBytes: task.totalBytes, status: 'cancelled'));
  }

  Future<void> delete(DownloadTask task) async {
    _cancelled.add(task.id);
    final file = File(task.filePath);
    if (file.existsSync()) await file.delete();
    final tasks = await list()..removeWhere((e) => e.id == task.id);
    await _save(tasks);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
