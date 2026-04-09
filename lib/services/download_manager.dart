import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

enum DownloadStatus { queued, starting, downloading, validating, completed, failed, canceled }

class DownloadTask {
  final Song song;
  DownloadStatus status;
  double progress;
  String? error;

  DownloadTask({
    required this.song,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.error,
  });
}

class DownloadManager {
  final Dio _dio = Dio();

  Future<void> downloadSongAtomic(Song song, String url, Function(double) onProgress) async {
    final dir = await getApplicationDocumentsDirectory();
    final tempPath = p.join(dir.path, '${song.id}.tmp');
    final finalPath = p.join(dir.path, '${song.id}.m4a');

    try {
      await _dio.download(
        url, 
        tempPath,
        onReceiveProgress: (rec, tot) {
          if (tot > 0) onProgress(rec / tot);
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          headers: {'User-Agent': 'NonoMusic/1.0'},
        ),
      );

      final file = File(tempPath);
      if (await file.exists() && await file.length() > 50000) {
        await file.rename(finalPath);
      } else {
        throw Exception("Fichier invalide.");
      }
    } catch (e) {
      if (await File(tempPath).exists()) await File(tempPath).delete();
      rethrow;
    }
  }
}
