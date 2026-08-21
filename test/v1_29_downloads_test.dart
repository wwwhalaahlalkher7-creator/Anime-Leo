import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:anime_platform_mobile/services/download_service.dart';

void main() {
  test('download task reports completed only when file exists', () {
    final file = File('${Directory.systemTemp.path}/anime_leo_test_download.mp4');
    file.writeAsBytesSync([1, 2, 3]);
    final task = DownloadTask(
      id: '1_1', animeId: 1, episode: 1, title: 'Test', filePath: file.path,
      quality: '720p', url: 'https://example.com/test.mp4', downloadedBytes: 3, totalBytes: 3, status: 'completed',
    );
    expect(task.completed, isTrue);
    file.deleteSync();
    expect(task.completed, isFalse);
  });
}
