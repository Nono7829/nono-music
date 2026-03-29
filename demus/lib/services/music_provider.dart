import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class MusicProvider with ChangeNotifier {
  // ⚠️ Windows desktop → localhost
  // Android émulateur   → 10.0.2.2
  static const String _baseUrl = 'http://localhost:3000';

  List<Song> _songs = [];
  bool _isLoading = false;
  String? _errorMessage;

  Song? _currentSong;
  bool _isPlaying = false;

  final List<Song> _favoriteSongs = [];
  final List<Song> _recentlyPlayed = [];
  final List<Map<String, dynamic>> _playlists = [];

  List<Song> get songs          => _songs;
  bool get isLoading            => _isLoading;
  String? get errorMessage      => _errorMessage;
  Song? get currentSong         => _currentSong;
  bool get isPlaying            => _isPlaying;
  List<Song> get favoriteSongs  => _favoriteSongs;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  List<Map<String, dynamic>> get playlists => _playlists;

  Future<void> searchYouTube(String query) async {
    if (query.trim().isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    _songs = [];
    notifyListeners();

    debugPrint('[FLUTTER] Recherche : "$query"');

    try {
      final uri = Uri.parse('$_baseUrl/search')
          .replace(queryParameters: {'q': query.trim()});

      debugPrint('[FLUTTER] Appel : $uri');

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 30));

      debugPrint('[FLUTTER] HTTP ${response.statusCode}');

      if (response.statusCode != 200) {
        _errorMessage = 'Erreur serveur (${response.statusCode})';
      } else {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          _errorMessage = 'Réponse JSON invalide';
        } else {
          final rawList = decoded['results'];
          if (rawList is! List) {
            _errorMessage = 'Champ "results" manquant ou invalide';
            debugPrint('[FLUTTER] Body reçu : ${response.body.substring(0, 200)}');
          } else {
            debugPrint('[FLUTTER] ${rawList.length} résultats bruts');
            for (final item in rawList) {
              if (item is Map<String, dynamic>) {
                try {
                  _songs.add(Song.fromJson(item));
                } catch (e) {
                  debugPrint('[FLUTTER] Parse error : $e | item : $item');
                }
              }
            }
            debugPrint('[FLUTTER] ${_songs.length} chansons affichées');
          }
        }
      }
    } on http.ClientException catch (e) {
      _errorMessage = 'Serveur inaccessible. Lancez : node server.js';
      debugPrint('[FLUTTER] ClientException : $e');
    } catch (e) {
      _errorMessage = 'Erreur : $e';
      debugPrint('[FLUTTER] Exception : $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearSearch() {
    _songs = [];
    _errorMessage = null;
    notifyListeners();
  }

  void playSong(Song song) {
    _currentSong = song;
    _isPlaying = true;
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > 20) _recentlyPlayed.removeLast();
    notifyListeners();
  }

  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void toggleFavorite(Song song) {
    if (_favoriteSongs.any((s) => s.id == song.id)) {
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongs.add(song);
    }
    notifyListeners();
  }

  bool isFavorite(Song song) => _favoriteSongs.any((s) => s.id == song.id);

  void createPlaylist(String name) {
    _playlists.add({
      'id':    DateTime.now().millisecondsSinceEpoch.toString(),
      'name':  name,
      'songs': <Song>[],
    });
    notifyListeners();
  }

  void addSongToPlaylist(String playlistId, Song song) {
    final pl = _playlists.firstWhere(
      (p) => p['id'] == playlistId,
      orElse: () => {},
    );
    if (pl.isNotEmpty) {
      (pl['songs'] as List<Song>).add(song);
      notifyListeners();
    }
  }

  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    final pl = _playlists.firstWhere(
      (p) => p['id'] == playlistId,
      orElse: () => {},
    );
    if (pl.isEmpty) return [];
    return List<Song>.from(pl['songs'] as List<Song>);
  }
}