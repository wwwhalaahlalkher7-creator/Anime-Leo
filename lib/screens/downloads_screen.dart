import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_language.dart';
import '../models/anime.dart';
import '../services/anime_api_service.dart';
import '../services/download_service.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  final Anime? anime;
  final List<Map<String, dynamic>> episodes;
  final bool downloadWholeAnime;

  const DownloadsScreen({super.key, this.anime, this.episodes = const [], this.downloadWholeAnime = false});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final api = AnimeApiService();
  List<DownloadTask> tasks = [];
  bool loading = false;
  String? message;
  final Map<String, StreamSubscription<DownloadTask>> subscriptions = {};

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.downloadWholeAnime) WidgetsBinding.instance.addPostFrameCallback((_) => _downloadAll());
  }

  @override
  void dispose() {
    for (final sub in subscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final value = await DownloadService.instance.list();
    if (mounted) setState(() => tasks = value);
  }

  Future<void> _downloadAll() async {
    if (widget.anime == null || widget.episodes.isEmpty) {
      if (mounted) setState(() => message = AppLanguage.instance.text('لا توجد حلقات متاحة.', 'No episodes are available.'));
      return;
    }
    setState(() { loading = true; message = null; });
    var available = 0;
    var skipped = 0;
    for (final ep in widget.episodes) {
      final number = (ep['mal_id'] as num?)?.toInt() ?? (ep['episode'] as num?)?.toInt() ?? 0;
      if (number <= 0) continue;
      try {
        final data = await api.playback(widget.anime!.malId ?? widget.anime!.id, number);
        final stream = _bestDownload(data);
        if (stream == null) {
          skipped++;
          continue;
        }
        available++;
        await _startEpisode(number, stream.url, stream.quality);
      } catch (_) {
        skipped++;
      }
    }
    if (mounted) {
      setState(() {
        loading = false;
        message = skipped == 0
            ? AppLanguage.instance.text('$available حلقة أضيفت للتنزيل.', '$available episodes queued for download.')
            : AppLanguage.instance.text('تمت إتاحة $available حلقة، وتعذر تنزيل $skipped حاليًا.', '$available episodes are available; $skipped could not be downloaded now.');
      });
    }
    await _load();
  }

  _DownloadChoice? _bestDownload(Map<String, dynamic> data) {
    final streams = data['streams'];
    if (streams is! List) return null;
    final choices = <_DownloadChoice>[];
    for (final item in streams.whereType<Map>()) {
      final url = item['downloadUrl']?.toString() ?? (item['downloadable'] == true ? item['url']?.toString() : null);
      if (url == null || !url.startsWith('http')) continue;
      final q = item['quality']?.toString() ?? 'auto';
      choices.add(_DownloadChoice(url, q));
    }
    if (choices.isEmpty) return null;
    int rank(String q) => int.tryParse(q.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    choices.sort((a, b) => rank(b.quality).compareTo(rank(a.quality)));
    return choices.first;
  }

  Future<void> _startEpisode(int number, String url, String quality) async {
    final anime = widget.anime!;
    final task = await DownloadService.instance.start(
      animeId: anime.id,
      episode: number,
      title: anime.title,
      url: url,
      quality: quality,
    );
    subscriptions[task.id]?.cancel();
    subscriptions[task.id] = DownloadService.instance.watch(task.id).listen((_) => _load());
  }

  Future<void> _delete(DownloadTask task) async {
    await DownloadService.instance.delete(task);
    await _load();
  }

  String _status(DownloadTask t) {
    if (t.completed) return AppLanguage.instance.text('مكتمل', 'Completed');
    if (t.status == 'downloading') return AppLanguage.instance.text('جارٍ التنزيل', 'Downloading');
    if (t.status == 'failed') return AppLanguage.instance.text('فشل التنزيل', 'Failed');
    if (t.status == 'cancelled') return AppLanguage.instance.text('ملغى', 'Cancelled');
    return t.status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLanguage.instance.text('التنزيلات', 'Downloads'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: tasks.isEmpty
                  ? ListView(children: [const SizedBox(height: 120), Icon(Icons.download_for_offline_outlined, size: 64), const SizedBox(height: 12), Center(child: Text('لا توجد تنزيلات بعد.'))])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: tasks.length + (message == null ? 0 : 1),
                      itemBuilder: (_, i) {
                        if (message != null && i == 0) return Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(message!, style: const TextStyle(fontWeight: FontWeight.w700)));
                        final t = tasks[i - (message == null ? 0 : 1)];
                        final progress = t.progress;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Icon(t.completed ? Icons.check : Icons.download)),
                            title: Text('${t.title} • الحلقة ${t.episode}'),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${t.quality} • ${_status(t)}'),
                              if (progress != null) Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: progress)),
                              if (t.error != null) Text(t.error!, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ]),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'cancel') await DownloadService.instance.cancel(t.id);
                                if (value == 'retry' && t.url.isNotEmpty) await DownloadService.instance.start(animeId: t.animeId, episode: t.episode, title: t.title, url: t.url, quality: t.quality);
                                if (value == 'delete') await _delete(t);
                                if (value == 'watch' && t.completed && widget.anime != null) {
                                  if (!context.mounted) return;
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(anime: widget.anime!, episodeNumber: t.episode, localFilePath: t.filePath)));
                                }
                                await _load();
                              },
                              itemBuilder: (_) => [
                                if (t.completed) const PopupMenuItem(value: 'watch', child: Text('مشاهدة')),
                                if (!t.completed) const PopupMenuItem(value: 'cancel', child: Text('إلغاء')),
                                if (t.status == 'failed' || t.status == 'cancelled') const PopupMenuItem(value: 'retry', child: Text('إعادة المحاولة')),
                                const PopupMenuItem(value: 'delete', child: Text('حذف')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _DownloadChoice {
  final String url;
  final String quality;
  const _DownloadChoice(this.url, this.quality);
}
