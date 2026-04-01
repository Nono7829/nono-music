import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import '../models/song.dart';
import 'supabase_service.dart';
import 'auth_service.dart';

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

class MusicProvider with ChangeNotifier {
  static const String _baseUrl = 'http://localhost:3000';

  // Services
  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  // ── Clés SharedPreferences (backup local) ───────────────────────────────
  static const _kPlaylists      = 'nono_playlists';
  static const _kFavorites      = 'nono_favorites';
  static const _kRecentlyPlayed = 'nono_recently_played';
  static const _kDownloads      = 'downloaded_songs';

  // ── Recherche ──────────────────────────────────────────────────────────
  List<Song> _songs       = [];
  bool _isLoading         = false;
  String? _errorMessage;

  // ── Lecture ────────────────────────────────────────────────────────────
  Song?      _currentSong;
  List<Song> _queue        = [];
  int        _currentIndex = -1;
  int        _loadId       = 0;
  bool       _isPlaying    = false;
  bool       _isAudioLoading = false;
  bool       _autoPlayNext = true; // Lecture automatique activée par défaut

  // ── Bibliothèque (persistées localement + cloud) ───────────────────────
  List<Song>                   _favoriteSongs  = [];
  List<Song>                   _recentlyPlayed = [];
  List<Map<String, dynamic>>   _playlists      = [];

  // ── Téléchargements ────────────────────────────────────────────────────
  List<Song>           _downloadedSongs   = [];
  final Map<String, double> _downloadProgress = {};

  final AudioPlayer _player = AudioPlayer();

  // ── Stream position ────────────────────────────────────────────────────
  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (pos, buf, dur) => PositionData(pos, buf, dur ?? Duration.zero),
      );

  AudioPlayer get audioPlayer => _player;
  bool get autoPlayNext => _autoPlayNext;

  // ── Getters ────────────────────────────────────────────────────────────
  List<Song>  get songs           => _songs;
  bool        get isLoading       => _isLoading;
  String?     get errorMessage    => _errorMessage;
  Song?       get currentSong     => _currentSong;
  bool        get isPlaying       => _isPlaying;
  bool        get isAudioLoading  => _isAudioLoading;
  List<Song>  get favoriteSongs   => _favoriteSongs;
  List<Song>  get recentlyPlayed  => _recentlyPlayed;
  List<Song>  get downloadedSongs => _downloadedSongs;
  Map<String, double> get downloadProgress => _downloadProgress;
  List<Map<String, dynamic>> get playlists => _playlists;

  // ── Constructeur ───────────────────────────────────────────────────────
  MusicProvider() {
    _initializeAudioService();
    _loadAllData();

    // Lecture automatique du suivant quand une chanson se termine
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

  Future<void> _initializeAudioService() async {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.nonomusic.app.channel.audio',
        androidNotificationChannelName: 'Nono Music',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      );
    } catch (e) {
      debugPrint('[AUDIO_SERVICE] Erreur init : $e');
    }
  }

  void toggleAutoPlay() {
    _autoPlayNext = !_autoPlayNext;
    notifyListeners();
  }

  // ── Sérialisation Song ─────────────────────────────────────────────────
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

  // ── Chargement depuis Supabase (prioritaire) ──────────────────────────
  Future<void> loadFromSupabase() async {
    if (!_auth.isAuthenticated) {
      await _loadAllData(); // Fallback local
      return;
    }

    try {
      debugPrint('[SYNC] Chargement depuis Supabase...');
      
      // Charger les favoris
      _favoriteSongs = await _supabase.getFavorites();
      
      // Charger les playlists
      final cloudPlaylists = await _supabase.getPlaylists();
      _playlists = cloudPlaylists;
      
      // Charger l'historique
      _recentlyPlayed = await _supabase.getRecentlyPlayed();
      
      // Charger les téléchargements (local uniquement)
      await _loadDownloads();
      
      debugPrint('[SYNC] ✅ ${_favoriteSongs.length} favoris, ${_playlists.length} playlists');
      notifyListeners();
      
    } catch (e) {
      debugPrint('[SYNC] ❌ Erreur : $e');
      await _loadAllData(); // Fallback local
    }
  }

  // ── Chargement local (backup) ──────────────────────────────────────────
  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // Favoris
      final favRaw = prefs.getString(_kFavorites);
      if (favRaw != null) {
        _favoriteSongs = (jsonDecode(favRaw) as List)
            .map((j) => _songFromJson(j as Map<String, dynamic>))
            .toList();
      }

      // Récemment joués
      final recRaw = prefs.getString(_kRecentlyPlayed);
      if (recRaw != null) {
        _recentlyPlayed = (jsonDecode(recRaw) as List)
            .map((j) => _songFromJson(j as Map<String, dynamic>))
            .toList();
      }

      // Playlists
      final plRaw = prefs.getString(_kPlaylists);
      if (plRaw != null) {
        final decoded = jsonDecode(plRaw) as List;
        _playlists = decoded.map((pl) {
          final songs = (pl['songs'] as List? ?? [])
              .map((s) => _songFromJson(s as Map<String, dynamic>))
              .toList();
          return {
            'id':    pl['id']   as String,
            'name':  pl['name'] as String,
            'coverUrl': pl['coverUrl'] as String?,
            'songs': songs,
          };
        }).cast<Map<String, dynamic>>().toList();
      }

      // Téléchargements
      await _loadDownloads();

      notifyListeners();
    } catch (e) {
      debugPrint('[PREFS] Erreur chargement : $e');
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

  // ── Sauvegarde avec sync cloud ─────────────────────────────────────────
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFavorites,
        jsonEncode(_favoriteSongs.map(_songToJson).toList()));
    
    // Sync cloud
    if (_auth.isAuthenticated) {
      try {
        await _supabase.syncFavorites(_favoriteSongs);
      } catch (e) {
        debugPrint('[SYNC] Erreur sync favoris : $e');
      }
    }
  }

  Future<void> _saveRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRecentlyPlayed,
        jsonEncode(_recentlyPlayed.map(_songToJson).toList()));
    
    // Sync cloud
    if (_auth.isAuthenticated) {
      try {
        await _supabase.syncRecentlyPlayed(_recentlyPlayed);
      } catch (e) {
        debugPrint('[SYNC] Erreur sync historique : $e');
      }
    }
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _playlists.map((pl) => {
      'id':    pl['id'],
      'name':  pl['name'],
      'coverUrl': pl['coverUrl'],
      'songs': (pl['songs'] as List<Song>).map(_songToJson).toList(),
    }).toList();
    await prefs.setString(_kPlaylists, jsonEncode(data));
    
    // Sync cloud
    if (_auth.isAuthenticated) {
      try {
        await _supabase.syncPlaylists(_playlists);
      } catch (e) {
        debugPrint('[SYNC] Erreur sync playlists : $e');
      }
    }
  }

  Future<void> _saveDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDownloads,
        jsonEncode(_downloadedSongs.map(_songToJson).toList()));
  }

  // ── Recherche ──────────────────────────────────────────────────────────
  Future<void> searchYouTube(String query) async {
    if (query.trim().isEmpty) return;
    _isLoading    = true;
    _errorMessage = null;
    _songs        = [];
    notifyListeners();

    try {
      final uri = Uri.parse('$_baseUrl/search')
          .replace(queryParameters: {'q': query.trim()});
      final resp = await http.get(uri).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        _errorMessage = 'Erreur serveur (${resp.statusCode})';
      } else {
        final body = jsonDecode(resp.body);
        if (body is Map<String, dynamic> && body['results'] is List) {
          for (final item in body['results'] as List) {
            if (item is Map<String, dynamic>) {
              try { _songs.add(Song.fromJson(item)); } catch (_) {}
            }
          }
        }
        debugPrint('[FLUTTER] ${_songs.length} résultats');
      }
    } on http.ClientException {
      _errorMessage = 'Serveur inaccessible.\nLancez : cd demus-backend && node server.js';
    } catch (e) {
      _errorMessage = 'Erreur : $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearSearch() {
    _songs        = [];
    _errorMessage = null;
    notifyListeners();
  }

  // ── LECTURE avec notification arrière-plan ─────────────────────────────
  Future<void> playSong(Song song, {List<Song>? queue}) async {
    final myId = ++_loadId;

    _currentSong = song;
    final sourceQueue = queue ?? (_songs.isNotEmpty ? _songs : [song]);
    _queue = List.from(sourceQueue);
    _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    if (_currentIndex == -1) { _queue = [song]; _currentIndex = 0; }

    _isPlaying      = true;
    _isAudioLoading = true;

    // Historique
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > 30) _recentlyPlayed.removeLast();
    _saveRecentlyPlayed();

    notifyListeners();

    try {
      await _player.stop();
      if (myId != _loadId) return;

      final audioSource = await _resolveSource(song);
      if (myId != _loadId) return;

      // Créer la source audio avec métadonnées pour notification
      final source = audioSource.startsWith('http')
          ? AudioSource.uri(
              Uri.parse(audioSource),
              tag: MediaItem(
                id: song.id,
                title: song.title,
                artist: song.artist,
                artUri: Uri.parse(song.coverUrl),
              ),
            )
          : AudioSource.file(
              audioSource,
              tag: MediaItem(
                id: song.id,
                title: song.title,
                artist: song.artist,
                artUri: Uri.parse(song.coverUrl),
              ),
            );

      await _player.setAudioSource(source);
      if (myId != _loadId) return;

      _isAudioLoading = false;
      notifyListeners();
      await _player.play();

    } catch (e) {
      debugPrint('[FLUTTER] playSong error: $e');
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
        await local.delete();
        _downloadedSongs.removeWhere((s) => s.id == song.id);
        _saveDownloads();
      }
    } catch (_) {}
    return '$_baseUrl/proxy/${song.id}';
  }

  // ── Contrôles ──────────────────────────────────────────────────────────
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
      // Fin de la file d'attente
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
    if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
      notifyListeners();
    }
  }

  // ── Favoris (persistés + cloud) ────────────────────────────────────────
  void toggleFavorite(Song song) {
    if (_favoriteSongs.any((s) => s.id == song.id)) {
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongs.add(song);
    }
    _saveFavorites();
    notifyListeners();
  }

  bool isFavorite(Song song) => _favoriteSongs.any((s) => s.id == song.id);

  // ── Playlists (persistées + cloud) ─────────────────────────────────────
  void createPlaylist(String name, {String? coverUrl}) {
    _playlists.add({
      'id':    DateTime.now().millisecondsSinceEpoch.toString(),
      'name':  name,
      'coverUrl': coverUrl,
      'songs': <Song>[],
    });
    _savePlaylists();
    notifyListeners();
  }

  void deletePlaylist(String playlistId) {
    _playlists.removeWhere((p) => p['id'] == playlistId);
    _savePlaylists();
    notifyListeners();
  }

  void renamePlaylist(String playlistId, String newName) {
    final pl = _playlists.firstWhere(
      (p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isNotEmpty) {
      pl['name'] = newName;
      _savePlaylists();
      notifyListeners();
    }
  }

  void updatePlaylistCover(String playlistId, String coverUrl) {
    final pl = _playlists.firstWhere(
      (p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isNotEmpty) {
      pl['coverUrl'] = coverUrl;
      _savePlaylists();
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
        _savePlaylists();
        notifyListeners();
      }
    }
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    final pl = _playlists.firstWhere(
      (p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isNotEmpty) {
      (pl['songs'] as List<Song>).removeWhere((s) => s.id == songId);
      _savePlaylists();
      notifyListeners();
    }
  }

  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    final pl = _playlists.firstWhere(
      (p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isEmpty) return [];
    return List<Song>.from(pl['songs'] as List<Song>);
  }

  // Télécharger toute une playlist
  Future<void> downloadPlaylist(String playlistId, {VoidCallback? onComplete}) async {
    final songs = await getPlaylistSongs(playlistId);
    int completed = 0;
    
    for (final song in songs) {
      if (!isDownloaded(song)) {
        await downloadSong(song);
        completed++;
      }
    }
    
    if (completed > 0) {
      onComplete?.call();
    }
  }

  bool isPlaylistFullyDownloaded(String playlistId) {
    final pl = _playlists.firstWhere(
      (p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isEmpty) return false;
    
    final songs = pl['songs'] as List<Song>;
    if (songs.isEmpty) return false;
    
    return songs.every((s) => isDownloaded(s));
  }

  // ── Téléchargements ────────────────────────────────────────────────────
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
            streamUrl, savePath,
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
      debugPrint('[FLUTTER] Download error: $e');
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
    _player.dispose();
    super.dispose();
  }
}
