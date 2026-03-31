import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/song.dart';

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

class MusicProvider with ChangeNotifier {
  static const String _baseUrl = 'http://localhost:3000';

  // ── Recherche ──────────────────────────────────────────────────────────────
  List<Song> _songs        = [];
  bool _isLoading          = false;
  String? _errorMessage;

  // ── Lecture ────────────────────────────────────────────────────────────────
  Song?      _currentSong;
  List<Song> _queue        = [];
  int        _currentIndex = -1;

  // _loadId : incrémenté à chaque playSong().
  // Chaque tâche mémorise son propre id ; si elle découvre que _loadId a changé
  // (un appel plus récent est arrivé), elle abandonne sans toucher à l'état.
  int  _loadId        = 0;
  bool _isPlaying     = false;
  bool _isAudioLoading = false;

  // ── Téléchargements ────────────────────────────────────────────────────────
  List<Song>           _downloadedSongs   = [];
  final Map<String, double> _downloadProgress = {};

  // ── Bibliothèque ───────────────────────────────────────────────────────────
  final List<Song>              _favoriteSongs  = [];
  final List<Song>              _recentlyPlayed = [];
  final List<Map<String, dynamic>> _playlists  = [];

  final AudioPlayer _player = AudioPlayer();

  // ── Stream position (pour la barre de progression) ────────────────────────
  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (pos, buf, dur) => PositionData(pos, buf, dur ?? Duration.zero),
      );

  AudioPlayer get audioPlayer => _player;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<Song>  get songs          => _songs;
  bool        get isLoading      => _isLoading;
  String?     get errorMessage   => _errorMessage;
  Song?       get currentSong    => _currentSong;
  bool        get isPlaying      => _isPlaying;
  bool        get isAudioLoading => _isAudioLoading;
  List<Song>  get favoriteSongs  => _favoriteSongs;
  List<Song>  get recentlyPlayed => _recentlyPlayed;
  List<Song>  get downloadedSongs => _downloadedSongs;
  Map<String, double> get downloadProgress => _downloadProgress;
  List<Map<String, dynamic>> get playlists => _playlists;

  // ── Constructeur ───────────────────────────────────────────────────────────
  MusicProvider() {
    _initDownloads();

    // Écoute la fin de piste — logique simplifiée, pas de flag bloquant.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _isPlaying = false;
        notifyListeners();
        Future.delayed(const Duration(milliseconds: 200), playNext);
      }
    });

    // Synchronise _isPlaying avec l'état réel du player (pause externe, etc.)
    _player.playingStream.listen((playing) {
      if (!_isAudioLoading && _isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    });
  }

  // ── Persistance des téléchargements ───────────────────────────────────────
  Future<void> _initDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('downloaded_songs');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _downloadedSongs = list.map((j) => Song(
        id:       j['id']       as String,
        title:    j['title']    as String,
        artist:   j['artist']   as String,
        duration: (j['duration'] as num).toInt(),
        coverUrl: (j['coverUrl'] as String?) ?? '',
      )).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('downloaded_songs', jsonEncode(
      _downloadedSongs.map((s) => {
        'id': s.id, 'title': s.title, 'artist': s.artist,
        'duration': s.duration, 'coverUrl': s.coverUrl,
      }).toList(),
    ));
  }

  // ── Recherche ──────────────────────────────────────────────────────────────
  Future<void> searchYouTube(String query) async {
    if (query.trim().isEmpty) return;
    _isLoading     = true;
    _errorMessage  = null;
    _songs         = [];
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

  // ── LECTURE ────────────────────────────────────────────────────────────────
  //
  // Logique simplifiée :
  //  • myId = ++_loadId  invalide tous les chargements antérieurs.
  //  • Après chaque await, on vérifie `myId != _loadId` → abandon silencieux.
  //  • Plus de _isChangingSong : le listener processingStateStream peut
  //    toujours s'exécuter ; s'il déclenche playNext() pendant un chargement
  //    en cours, playNext incrémente _loadId et annule le précédent.
  //
  Future<void> playSong(Song song, {List<Song>? queue}) async {
    final myId = ++_loadId;

    // ── Mise à jour de la file ───────────────────────────────────────────
    _currentSong = song;
    final sourceQueue = queue ?? ((_songs.isNotEmpty) ? _songs : [song]);
    _queue = List.from(sourceQueue);
    _currentIndex = _queue.indexWhere((s) => s.id == song.id);
    if (_currentIndex == -1) { _queue = [song]; _currentIndex = 0; }

    _isPlaying      = true;
    _isAudioLoading = true;
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > 20) _recentlyPlayed.removeLast();
    notifyListeners();

    try {
      // 1. Arrêter l'audio en cours
      await _player.stop();
      if (myId != _loadId) return;

      // 2. Déterminer la source (local ou proxy)
      final String audioSource = await _resolveSource(song);
      if (myId != _loadId) return;

      // 3. Charger la source dans le player
      if (audioSource.startsWith('http')) {
        await _player.setUrl(audioSource);
      } else {
        try {
          await _player.setFilePath(audioSource);
        } catch (e) {
          debugPrint('[FLUTTER] setFilePath failed, fallback proxy: $e');
          if (myId != _loadId) return;
          await _player.setUrl('$_baseUrl/proxy/${song.id}');
        }
      }
      if (myId != _loadId) return;

      // 4. Lancer
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

  /// Retourne le chemin local s'il existe, sinon l'URL du proxy.
  Future<String> _resolveSource(Song song) async {
    try {
      final dir   = await getApplicationDocumentsDirectory();
      final local = File('${dir.path}/${song.id}.m4a');
      if (await local.exists()) {
        final size = await local.length();
        if (size > 50000) {
          debugPrint('[FLUTTER] source locale : ${song.id} ($size bytes)');
          return local.path;
        }
        // Fichier incomplet → supprimer et retomber sur le proxy
        await local.delete();
        _downloadedSongs.removeWhere((s) => s.id == song.id);
        _saveDownloads();
      }
    } catch (_) {}
    debugPrint('[FLUTTER] source proxy : $_baseUrl/proxy/${song.id}');
    return '$_baseUrl/proxy/${song.id}';
  }

  // ── Contrôles ──────────────────────────────────────────────────────────────

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
        // Rembobiner et relire
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
    // < 3s écoulées → chanson précédente ; sinon → rembobiner
    if (_player.position.inSeconds < 3 &&
        _currentIndex > 0 &&
        _queue.isNotEmpty) {
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

  // ── Favoris ────────────────────────────────────────────────────────────────
  void toggleFavorite(Song song) {
    if (_favoriteSongs.any((s) => s.id == song.id)) {
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongs.add(song);
    }
    notifyListeners();
  }

  bool isFavorite(Song song) =>
      _favoriteSongs.any((s) => s.id == song.id);

  // ── Playlists ──────────────────────────────────────────────────────────────
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

  // ── Téléchargements ────────────────────────────────────────────────────────
  bool isDownloaded(Song song) =>
      _downloadedSongs.any((s) => s.id == song.id);

  Future<void> downloadSong(Song song, {VoidCallback? onComplete}) async {
    if (isDownloaded(song) || _downloadProgress.containsKey(song.id)) return;

    _downloadProgress[song.id] = 0.0;
    notifyListeners();

    bool success = false;
    try {
      // 1. Obtenir l'URL brute depuis le backend
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
            onReceiveProgress: (received, total) {
              if (total > 0) {
                _downloadProgress[song.id] = received / total;
                notifyListeners();
              }
            },
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              },
            ),
          );

          _downloadedSongs.add(song);
          await _saveDownloads();
          success = true;
          debugPrint('[FLUTTER] Téléchargé : ${song.id}');
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