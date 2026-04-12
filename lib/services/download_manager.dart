import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

class DownloadManager {
  final Dio _dio = Dio();

  Future<void> downloadSongAtomic(Song song, String url, Function(double) onProgress) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final tempPath = p.join(dir.path, '${song.id}.tmp');
      final finalPath = p.join(dir.path, '${song.id}.m4a');
      
      debugPrint('[DL_MANAGER] Start: ${song.title} -> $tempPath');

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
      if (await file.exists()) {
        final size = await file.length();
        debugPrint('[DL_MANAGER] File size: $size bytes');
        
        if (size > 50000) {
          await file.rename(finalPath);
          debugPrint('[DL_MANAGER] Success: ${song.id}');
        } else {
          debugPrint('[DL_MANAGER] Error: File too small');
          await file.delete();
          throw Exception("Fichier corrompu");
        }
      }
    } catch (e) {
      debugPrint('[DL_MANAGER] Fatal Error: $e');
      rethrow;
    }
  }
}
