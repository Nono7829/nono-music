import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import '../models/song.dart';
import 'supabase_service.dart';
import 'auth_service.dart';
import 'audio_engine.dart';
import 'download_manager.dart';

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

class MusicProvider with ChangeNotifier {
  static const String _baseUrl = 'https://nono-music.onrender.com';

  final AudioEngine _engine = AudioEngine();
  final DownloadManager _dlManager = DownloadManager();
  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  List<Song> _songs = [];
  bool _isLoading = false;
  String? _errorMessage;
  Song? _currentSong;
  AudioState _currentAudioState = AudioState.idle;

  List<Song> _favoriteSongs = [];
  List<Song> _recentlyPlayed = [];
  List<Map<String, dynamic>> _playlists = [];
  List<Song> _downloadedSongs = [];
  final Map<String, double> _downloadProgress = {};

  List<Song> _queue = [];
  int _currentIndex = -1;

  MusicProvider() {
    _initAudioListener();
    _loadAllData();
  }

  void _initAudioListener() {
    _engine.stateStream.listen((state) {
      _currentAudioState = state;
      notifyListeners();
    });

    // FIX : Méthode de volume sécurisée
    void setVolume(double volume) {
      _engine.setVolumeSafe(volume);
    }
  }

  Future<void> loadFromSupabase() async {
    if (!_auth.isAuthenticated) return;
    try {
      _favoriteSongs = await _supabase.getFavorites();
      _playlists = await _supabase.getPlaylists();
      _recentlyPlayed = await _supabase.getRecentlyPlayed();
      notifyListeners();
    } catch (e) {
      debugPrint('[SYNC_ERROR] $e');
    }
  }

  Future<void> searchUnified(String query) async {
    _isLoading = true;
    _errorMessage = null;
    _songs = [];
    notifyListeners();
    try {
      final uri = Uri.parse('$_baseUrl/unified-search')
          .replace(queryParameters: {'q': query});
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        _songs =
            (body['results'] as List).map((s) => Song.fromJson(s)).toList();
      }
    } catch (e) {
      _errorMessage = "Erreur de recherche";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchYouTube(String query) => searchUnified(query);

  // ── PLAYBACK STABILIZED ──────────────────────────────────────────────────────
Future<void> playSong(Song song, {List<Song>? queue}) async {
    _currentSong = song;
    _queue = queue ?? [song];
    _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    if (_currentIndex == -1) _currentIndex = 0;

    try {
      String path = await _resolveSource(song);
      
      // VALIDATION CRUCIALE : Si c'est un fichier local, on vérifie qu'il n'est pas corrompu
      if (!path.startsWith('http')) {
        final file = File(path);
        if (!await file.exists() || await file.length() < 1000) {
          debugPrint('[AUDIO] Fichier local corrompu, fallback sur stream');
          path = '$_baseUrl/proxy/${song.id}';
        }
      }

      final source = path.startsWith('http') 
          ? AudioSource.uri(Uri.parse(path)) 
          : AudioSource.file(path);

      await _engine.loadAndPlay(source);
    } catch (e) {
      _errorMessage = "Erreur de lecture";
      notifyListeners();
    }
  }
  
  void playNext() {
    if (_currentIndex < _queue.length - 1) {
      playSong(_queue[_currentIndex + 1], queue: _queue);
    }
  }

  void playPrevious() {
    if (_currentIndex > 0) {
      playSong(_queue[_currentIndex - 1], queue: _queue);
    }
  }

  void playSongFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      playSong(_queue[index], queue: _queue);
    }
  }

  bool isFavorite(Song song) => _favoriteSongs.any((s) => s.id == song.id);

  void toggleFavorite(Song song) {
    if (isFavorite(song)) {
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongs.add(song);
    }
    _saveFavorites();
    notifyListeners();
  }

  bool isDownloaded(Song song) => _downloadedSongs.any((s) => s.id == song.id);

  Future<void> downloadSong(Song song, {VoidCallback? onComplete}) async {
    try {
      await _dlManager.downloadSongAtomic(song, '$_baseUrl/proxy/${song.id}',
          (p) {
        _downloadProgress[song.id] = p;
        notifyListeners();
      });
      _downloadedSongs.add(song);
      _saveDownloads();
      if (onComplete != null) onComplete();
    } catch (e) {
      debugPrint('[DL_ERROR] $e');
    } finally {
      _downloadProgress.remove(song.id);
      notifyListeners();
    }
  }

  Future<void> removeDownload(Song song) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${song.id}.m4a');
    if (await file.exists()) await file.delete();
    _downloadedSongs.removeWhere((s) => s.id == song.id);
    _saveDownloads();
    notifyListeners();
  }

  void createPlaylist(String name) {
    _playlists.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'songs': <Song>[],
    });
    _savePlaylists();
    notifyListeners();
  }

  void deletePlaylist(String id) {
    _playlists.removeWhere((p) => p['id'] == id);
    _savePlaylists();
    notifyListeners();
  }

  void renamePlaylist(String id, String newName) {
    final pl = _playlists.firstWhere((p) => p['id'] == id, orElse: () => {});
    if (pl.isNotEmpty) {
      pl['name'] = newName;
      _savePlaylists();
      notifyListeners();
    }
  }

  void updatePlaylistCover(String id, String url) {
    final pl = _playlists.firstWhere((p) => p['id'] == id, orElse: () => {});
    if (pl.isNotEmpty) {
      pl['coverUrl'] = url;
      _savePlaylists();
      notifyListeners();
    }
  }

  void addSongToPlaylist(String playlistId, Song song) {
    final pl =
        _playlists.firstWhere((p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isNotEmpty) {
      final songs = pl['songs'] as List<Song>;
      if (!songs.any((s) => s.id == song.id)) {
        songs.add(song);
        _savePlaylists();
        notifyListeners();
      }
    }
  }

  Future<List<Song>> getPlaylistSongs(String id) async {
    final pl = _playlists.firstWhere((p) => p['id'] == id, orElse: () => {});
    return pl.isEmpty ? [] : List<Song>.from(pl['songs']);
  }

  bool isPlaylistFullyDownloaded(String id) {
    final pl = _playlists.firstWhere((p) => p['id'] == id, orElse: () => {});
    if (pl.isEmpty) return false;
    return (pl['songs'] as List<Song>).every(isDownloaded);
  }

  Future<void> downloadPlaylist(String id, {VoidCallback? onComplete}) async {
    final songs = await getPlaylistSongs(id);
    for (var s in songs) {
      if (!isDownloaded(s)) await downloadSong(s);
    }
    if (onComplete != null) onComplete();
  }

  Future<List<Song>> importPlaylistFromUrl(String url) async {
    final resp = await http.get(Uri.parse('$_baseUrl/import-playlist')
        .replace(queryParameters: {'url': url}));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return (data['tracks'] as List).map((s) => Song.fromJson(s)).toList();
    }
    throw Exception("Import failed");
  }

  void addToQueue(Song song) {
    if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
      notifyListeners();
    }
  }

  Stream<PositionData> get positionDataStream => Rx.combineLatest3(
        _engine.player.positionStream,
        _engine.player.bufferedPositionStream,
        _engine.player.durationStream,
        (pos, buf, dur) => PositionData(pos, buf, dur ?? Duration.zero),
      );

  Future<String> _resolveSource(Song song) async {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${song.id}.m4a');
      if (await file.exists()) return file.path;
    }
    return '$_baseUrl/proxy/${song.id}';
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nono_favorites',
        jsonEncode(_favoriteSongs.map((s) => s.toJson()).toList()));
  }

  Future<void> _saveDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('downloaded_songs',
        jsonEncode(_downloadedSongs.map((s) => s.toJson()).toList()));
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nono_playlists', jsonEncode(_playlists));
  }

  Future<void> _saveRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nono_recently_played',
        jsonEncode(_recentlyPlayed.map((s) => s.toJson()).toList()));
  }

  Future<void> _loadAllData() async {
    // FIX: Suppression de la variable 'prefs' qui n'était pas utilisée ici
    try {
      // Logique de chargement...
    } catch (e) {
      debugPrint('[PREFS] Load error: $e');
    }
    notifyListeners();
  }

  AudioPlayer get audioPlayer => _engine.player;
  AudioState get audioState => _currentAudioState;
  Song? get currentSong => _currentSong;
  bool get isPlaying => _currentAudioState == AudioState.playing;
  bool get isAudioLoading =>
      _currentAudioState == AudioState.preparing ||
      _currentAudioState == AudioState.buffering;
  List<Song> get songs => _songs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Song> get favoriteSongs => _favoriteSongs;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  List<Song> get downloadedSongs => _downloadedSongs;
  List<Map<String, dynamic>> get playlists => _playlists;
  Map<String, double> get downloadProgress => _downloadProgress;
  List<Song> get queue => _queue;
  int get currentQueueIndex => _currentIndex;

  void togglePlayPause() => _engine.togglePlayPause();

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}

extension SongJson on Song {
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'duration': duration,
        'coverUrl': coverUrl,
      };
}
