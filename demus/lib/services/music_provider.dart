import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';

import '../models/song.dart';
import 'supabase_service.dart';
import 'auth_service.dart';

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  const PositionData(this.position, this.bufferedPosition, this.duration);
}

class MusicProvider with ChangeNotifier {
static const String _baseUrl = 'https://nono-music.onrender.com';

  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  static const _kPlaylists      = 'nono_playlists';
  static const _kFavorites      = 'nono_favorites';
  static const _kRecentlyPlayed = 'nono_recently_played';
  static const _kDownloads      = 'downloaded_songs';

  // ── Search ────────────────────────────────────────────────────────────────
  List<Song> _songs       = [];
  bool _isLoading         = false;
  String? _errorMessage;
  Timer? _searchDebounce;

  // ── Playback ──────────────────────────────────────────────────────────────
  Song?      _currentSong;
  List<Song> _queue        = [];
  int        _currentIndex = -1;
  int        _loadId       = 0;
  bool       _isPlaying    = false;
  bool       _isAudioLoading = false;
  bool       _autoPlayNext = true;

  // ── Library ───────────────────────────────────────────────────────────────
  List<Song>                 _favoriteSongs  = [];
  List<Song>                 _recentlyPlayed = [];
  List<Map<String, dynamic>> _playlists      = [];

  // ── Downloads ─────────────────────────────────────────────────────────────
  List<Song>            _downloadedSongs   = [];
  final Map<String, double> _downloadProgress = {};

  // ── Audio player (single instance, lives for app lifetime) ────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Position stream ───────────────────────────────────────────────────────
  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (pos, buf, dur) => PositionData(pos, buf, dur ?? Duration.zero),
      );

  AudioPlayer get audioPlayer => _player;
  bool get autoPlayNext => _autoPlayNext;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<Song>  get songs            => List.unmodifiable(_songs);
  bool        get isLoading        => _isLoading;
  String?     get errorMessage     => _errorMessage;
  Song?       get currentSong      => _currentSong;
  bool        get isPlaying        => _isPlaying;
  bool        get isAudioLoading   => _isAudioLoading;
  List<Song>  get favoriteSongs    => List.unmodifiable(_favoriteSongs);
  List<Song>  get recentlyPlayed   => List.unmodifiable(_recentlyPlayed);
  List<Song>  get downloadedSongs  => List.unmodifiable(_downloadedSongs);
  Map<String, double> get downloadProgress => Map.unmodifiable(_downloadProgress);
  List<Map<String, dynamic>> get playlists => List.unmodifiable(_playlists);

  // ── Constructor ───────────────────────────────────────────────────────────
  MusicProvider() {
    // Note: JustAudioBackground.init() is called in main() via
    // AudioServiceInitializer — never here.
    _loadAllData();

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && _autoPlayNext) {
        _isPlaying = false;
        notifyListeners();
        Future.delayed(const Duration(milliseconds: 200), playNext);
      }
    });

    _player.playingStream.listen((playing) {
      if (!_isAudioLoading && _isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    });
  }

  void toggleAutoPlay() {
    _autoPlayNext = !_autoPlayNext;
    notifyListeners();
  }

  // ── Serialization ─────────────────────────────────────────────────────────
  static Map<String, dynamic> _songToJson(Song s) => {
    'id': s.id, 'title': s.title, 'artist': s.artist,
    'duration': s.duration, 'coverUrl': s.coverUrl,
  };

  static Song _songFromJson(Map<String, dynamic> j) => Song(
    id:       j['id']       as String,
    title:    j['title']    as String,
    artist:   j['artist']   as String,
    duration: (j['duration'] as num?)?.toInt() ?? 0,
    coverUrl: (j['coverUrl'] as String?) ?? '',
  );

  // ── Cloud sync ────────────────────────────────────────────────────────────
  Future<void> loadFromSupabase() async {
    if (!_auth.isAuthenticated) {
      await _loadAllData();
      return;
    }
    try {
      debugPrint('[SYNC] Loading from Supabase…');
      _favoriteSongs  = await _supabase.getFavorites();
      _playlists      = await _supabase.getPlaylists();
      _recentlyPlayed = await _supabase.getRecentlyPlayed();
      await _loadDownloads();
      debugPrint('[SYNC] ✅ ${_favoriteSongs.length} favorites, ${_playlists.length} playlists');
      notifyListeners();
    } catch (e) {
      debugPrint('[SYNC] ❌ $e');
      await _loadAllData();
    }
  }

  // ── Local persistence ─────────────────────────────────────────────────────
  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final favRaw = prefs.getString(_kFavorites);
      if (favRaw != null) {
        _favoriteSongs = (jsonDecode(favRaw) as List)
            .map((j) => _songFromJson(j as Map<String, dynamic>))
            .toList();
      }

      final recRaw = prefs.getString(_kRecentlyPlayed);
      if (recRaw != null) {
        _recentlyPlayed = (jsonDecode(recRaw) as List)
            .map((j) => _songFromJson(j as Map<String, dynamic>))
            .toList();
      }

      final plRaw = prefs.getString(_kPlaylists);
      if (plRaw != null) {
        final decoded = jsonDecode(plRaw) as List;
        _playlists = decoded.map((pl) {
          final songs = (pl['songs'] as List? ?? [])
              .map((s) => _songFromJson(s as Map<String, dynamic>))
              .toList();
          return <String, dynamic>{
            'id':       pl['id']   as String,
            'name':     pl['name'] as String,
            'coverUrl': pl['coverUrl'] as String?,
            'songs':    songs,
          };
        }).toList();
      }

      await _loadDownloads();
      notifyListeners();
    } catch (e) {
      debugPrint('[PREFS] Load error: $e');
    }
  }

  Future<void> _loadDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final dlRaw = prefs.getString(_kDownloads);
    if (dlRaw != null) {
      _downloadedSongs = (jsonDecode(dlRaw) as List)
          .map((j) => _songFromJson(j as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFavorites,
        jsonEncode(_favoriteSongs.map(_songToJson).toList()));
    if (_auth.isAuthenticated) {
      unawaited(_supabase.syncFavorites(_favoriteSongs).catchError(
            (e) => debugPrint('[SYNC] favorites error: $e'),
          ));
    }
  }

  Future<void> _saveRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRecentlyPlayed,
        jsonEncode(_recentlyPlayed.map(_songToJson).toList()));
    if (_auth.isAuthenticated) {
      unawaited(_supabase.syncRecentlyPlayed(_recentlyPlayed).catchError(
            (e) => debugPrint('[SYNC] recently played error: $e'),
          ));
    }
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _playlists.map((pl) => {
      'id':       pl['id'],
      'name':     pl['name'],
      'coverUrl': pl['coverUrl'],
      'songs':    (pl['songs'] as List<Song>).map(_songToJson).toList(),
    }).toList();
    await prefs.setString(_kPlaylists, jsonEncode(data));
    if (_auth.isAuthenticated) {
      unawaited(_supabase.syncPlaylists(_playlists).catchError(
            (e) => debugPrint('[SYNC] playlists error: $e'),
          ));
    }
  }

  Future<void> _saveDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDownloads,
        jsonEncode(_downloadedSongs.map(_songToJson).toList()));
  }

  // ── Search (debounced) ────────────────────────────────────────────────────

  /// Call from the TextField's onChanged. Debounces 450 ms.
  void searchDebounced(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => searchYouTube(query),
    );
  }

  Future<void> searchYouTube(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    _isLoading    = true;
    _errorMessage = null;
    _songs        = [];
    notifyListeners();

    try {
      final uri = Uri.parse('$_baseUrl/search')
          .replace(queryParameters: {'q': q});
      final resp = await http.get(uri).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        _errorMessage = 'Server error (${resp.statusCode})';
      } else {
        final body = jsonDecode(resp.body) as Map<String, dynamic>?;
        if (body?['results'] is List) {
          for (final item in body!['results'] as List) {
            if (item is Map<String, dynamic>) {
              try { _songs.add(Song.fromJson(item)); } catch (_) {}
            }
          }
        }
        debugPrint('[SEARCH] ${_songs.length} results for "$q"');
      }
    } on http.ClientException {
      _errorMessage = 'Server unreachable.\nRun: cd demus-backend && node server.js';
    } on TimeoutException {
      _errorMessage = 'Request timed out. Check backend connectivity.';
    } catch (e) {
      _errorMessage = 'Error: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    _songs        = [];
    _errorMessage = null;
    notifyListeners();
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    final myId = ++_loadId;

    _currentSong = song;
    final sourceQueue = queue ?? (_songs.isNotEmpty ? _songs : [song]);
    _queue        = List.from(sourceQueue);
    _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    if (_currentIndex == -1) { _queue = [song]; _currentIndex = 0; }

    _isPlaying      = true;
    _isAudioLoading = true;

    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > 30) _recentlyPlayed.removeLast();
    unawaited(_saveRecentlyPlayed());

    notifyListeners();

    try {
      await _player.stop();
      if (myId != _loadId) return;

      final audioPath = await _resolveSource(song);
      if (myId != _loadId) return;

      final tag = MediaItem(
        id:     song.id,
        title:  song.title,
        artist: song.artist,
        artUri: song.coverUrl.isNotEmpty ? Uri.parse(song.coverUrl) : null,
      );

      final source = audioPath.startsWith('http')
          ? AudioSource.uri(Uri.parse(audioPath), tag: tag)
          : AudioSource.file(audioPath, tag: tag);

      await _player.setAudioSource(source);
      if (myId != _loadId) return;

      _isAudioLoading = false;
      notifyListeners();
      await _player.play();
    } catch (e) {
      debugPrint('[AUDIO] playSong error: $e');
      if (myId == _loadId) {
        _isPlaying      = false;
        _isAudioLoading = false;
        notifyListeners();
      }
    }
  }

  Future<String> _resolveSource(Song song) async {
    try {
      final dir   = await getApplicationDocumentsDirectory();
      final local = File('${dir.path}/${song.id}.m4a');
      if (await local.exists()) {
        final size = await local.length();
        if (size > 50000) return local.path;
        // Corrupt file — remove it.
        await local.delete();
        _downloadedSongs.removeWhere((s) => s.id == song.id);
        unawaited(_saveDownloads());
      }
    } catch (_) {}
    return '$_baseUrl/proxy/${song.id}';
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void togglePlayPause() {
    if (_isAudioLoading) return;
    if (_isPlaying) {
      _player.pause();
      _isPlaying = false;
    } else {
      final ps = _player.processingState;
      if (ps == ProcessingState.ready || ps == ProcessingState.buffering) {
        _player.play();
        _isPlaying = true;
      } else if (ps == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.play();
        _isPlaying = true;
      }
    }
    notifyListeners();
  }

  void playNext() {
    if (_queue.isEmpty) return;
    if (_currentIndex >= 0 && _currentIndex < _queue.length - 1) {
      playSong(_queue[_currentIndex + 1], queue: _queue);
    } else {
      _isPlaying      = false;
      _isAudioLoading = false;
      notifyListeners();
    }
  }

  void playPrevious() {
    if (_currentSong == null) return;
    if (_player.position.inSeconds < 3 && _currentIndex > 0) {
      playSong(_queue[_currentIndex - 1], queue: _queue);
    } else {
      _player.seek(Duration.zero);
    }
  }

  void addToQueue(Song song) {
    if (_queue.any((s) => s.id == song.id)) return;
    _queue.add(song);
    notifyListeners();
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  void toggleFavorite(Song song) {
    if (_favoriteSongs.any((s) => s.id == song.id)) {
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongs.add(song);
    }
    unawaited(_saveFavorites());
    notifyListeners();
  }

  bool isFavorite(Song song) => _favoriteSongs.any((s) => s.id == song.id);

  // ── Playlists ─────────────────────────────────────────────────────────────

  void createPlaylist(String name, {String? coverUrl}) {
    _playlists.add({
      'id':       DateTime.now().millisecondsSinceEpoch.toString(),
      'name':     name,
      'coverUrl': coverUrl,
      'songs':    <Song>[],
    });
    unawaited(_savePlaylists());
    notifyListeners();
  }

  void deletePlaylist(String playlistId) {
    _playlists.removeWhere((p) => p['id'] == playlistId);
    unawaited(_savePlaylists());
    notifyListeners();
  }

  void renamePlaylist(String playlistId, String newName) {
    final pl = _playlists.firstWhere(
        (p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isNotEmpty) {
      pl['name'] = newName;
      unawaited(_savePlaylists());
      notifyListeners();
    }
  }

  void updatePlaylistCover(String playlistId, String coverUrl) {
    final pl = _playlists.firstWhere(
        (p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isNotEmpty) {
      pl['coverUrl'] = coverUrl;
      unawaited(_savePlaylists());
      notifyListeners();
    }
  }

  void addSongToPlaylist(String playlistId, Song song) {
    final pl = _playlists.firstWhere(
        (p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isNotEmpty) {
      final songs = pl['songs'] as List<Song>;
      if (!songs.any((s) => s.id == song.id)) {
        songs.add(song);
        unawaited(_savePlaylists());
        notifyListeners();
      }
    }
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    final pl = _playlists.firstWhere(
        (p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isNotEmpty) {
      (pl['songs'] as List<Song>).removeWhere((s) => s.id == songId);
      unawaited(_savePlaylists());
      notifyListeners();
    }
  }

  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    final pl = _playlists.firstWhere(
        (p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isEmpty) return [];
    return List<Song>.from(pl['songs'] as List<Song>);
  }

  bool isPlaylistFullyDownloaded(String playlistId) {
    final pl = _playlists.firstWhere(
        (p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isEmpty) return false;
    final songs = pl['songs'] as List<Song>;
    if (songs.isEmpty) return false;
    return songs.every(isDownloaded);
  }

  Future<void> downloadPlaylist(String playlistId,
      {VoidCallback? onComplete}) async {
    final songs = await getPlaylistSongs(playlistId);
    int completed = 0;
    for (final song in songs) {
      if (!isDownloaded(song)) {
        await downloadSong(song);
        completed++;
      }
    }
    if (completed > 0) onComplete?.call();
  }

  // ── Downloads ─────────────────────────────────────────────────────────────

  bool isDownloaded(Song song) => _downloadedSongs.any((s) => s.id == song.id);

  Future<void> downloadSong(Song song, {VoidCallback? onComplete}) async {
    if (isDownloaded(song) || _downloadProgress.containsKey(song.id)) return;
    _downloadProgress[song.id] = 0.0;
    notifyListeners();

    bool success = false;
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/stream/${song.id}'))
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final streamUrl =
            (jsonDecode(resp.body) as Map<String, dynamic>)['url'] as String?;
        if (streamUrl != null && streamUrl.isNotEmpty) {
          final dir      = await getApplicationDocumentsDirectory();
          final savePath = '${dir.path}/${song.id}.m4a';
          await Dio().download(
            streamUrl,
            savePath,
            onReceiveProgress: (rec, tot) {
              if (tot > 0) {
                _downloadProgress[song.id] = rec / tot;
                notifyListeners();
              }
            },
            options: Options(headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            }),
          );
          _downloadedSongs.add(song);
          await _saveDownloads();
          success = true;
        }
      }
    } catch (e) {
      debugPrint('[DOWNLOAD] error: $e');
    }

    _downloadProgress.remove(song.id);
    notifyListeners();
    if (success) onComplete?.call();
  }

  Future<void> removeDownload(Song song) async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${song.id}.m4a');
      if (await file.exists()) await file.delete();
    } catch (_) {}
    _downloadedSongs.removeWhere((s) => s.id == song.id);
    await _saveDownloads();
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _player.dispose();
    super.dispose();
  }
}