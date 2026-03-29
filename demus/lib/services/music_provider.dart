import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

class MusicProvider with ChangeNotifier {
  final YoutubeExplode youtube = YoutubeExplode();
  List<Song> _songs = [];
  bool _isLoading = false;

  List<Song> get songs => _songs;
  bool get isLoading => _isLoading;

  Future<List<Song>> searchYouTube(String query) async {
    setState(() => _isLoading = true);
    _songs.clear();

    try {
      final searchResults = await youtube.search.getVideos(query);

      for (final item in searchResults.take(10)) { // Limitez à 10 résultats
        final videoId = item.id;
        final video = await youtube.videos.get(videoId);

        _songs.add(Song(
          title: video.title,
          artist: item.author,
          coverUrl: item.thumbnails.standardRes.url.toString(),
        ));
      }
    } catch (e) {
      print('Erreur lors de la recherche YouTube : $e');
    }

    setState(() => _isLoading = false);
    return _songs;
  }

  void dispose() {
    youtube.close();
    super.dispose();
  }
}
