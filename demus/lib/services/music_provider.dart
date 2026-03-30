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
  List<Song> _songs = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ── Lecture ────────────────────────────────────────────────────────────────
  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;

  /// INTENTION UI : true = on veut jouer.
  /// Géré UNIQUEMENT par notre code, jamais synced depuis le player stream.
  bool _isPlaying = false;

  /// true = en train de charger (fetching URL ou setUrl/setFilePath en cours).
  /// Le bouton pause/play est IGNORÉ pendant cet état.
  bool _isAudioLoading = false;

  /// ─── Clé de sérialisation ─────────────────────────────────────────────────
  ///
  /// _loadId   : incrémenté à chaque playSong(). Chaque appel mémorise son
  ///             propre myId. Un appel "périmé" (myId != _loadId) abandonne
  ///             silencieusement sa progression SANS réinitialiser les flags.
  ///
  /// _isChangingSong : bloque le listener processingStateStream pendant toute
  ///             la durée d'un changement de chanson (stop → fetch → setUrl).
  ///             Seul l'appel GAGNANT (myId == _loadId) le remet à false.
  ///
  int _loadId = 0;
  bool _isChangingSong = false;

  // ── Téléchargements ────────────────────────────────────────────────────────
  List<Song> _downloadedSongs = [];
  final Map<String, double> _downloadProgress = {};

  // ── Bibliothèque ───────────────────────────────────────────────────────────
  final List<Song> _favoriteSongs = [];
  final List<Song> _recentlyPlayed = [];
  final List<Map<String, dynamic>> _playlists = [];

  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Stream position ────────────────────────────────────────────────────────
  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _audioPlayer.positionStream,
        _audioPlayer.bufferedPositionStream,
        _audioPlayer.durationStream,
        (pos, buf, dur) => PositionData(pos, buf, dur ?? Duration.zero),
      );

  AudioPlayer get audioPlayer => _audioPlayer;

  // ── Getters publics ────────────────────────────────────────────────────────
  List<Song> get songs           => _songs;
  bool get isLoading             => _isLoading;
  String? get errorMessage       => _errorMessage;
  Song? get currentSong          => _currentSong;
  bool get isPlaying             => _isPlaying;
  bool get isAudioLoading        => _isAudioLoading;
  List<Song> get favoriteSongs   => _favoriteSongs;
  List<Song> get recentlyPlayed  => _recentlyPlayed;
  List<Map<String, dynamic>> get playlists => _playlists;
  List<Song> get downloadedSongs => _downloadedSongs;
  Map<String, double> get downloadProgress => _downloadProgress;

  // ── Constructeur ───────────────────────────────────────────────────────────
  MusicProvider() {
    _initDownloads();

    _audioPlayer.processingStateStream.listen((state) {
      // RÈGLE CRITIQUE : Si _isChangingSong est true, on est en pleine
      // transition (stop → setUrl). On ignore TOUT évènement du player,
      // y compris "completed" qui serait émis par le stop() précédent.
      if (_isChangingSong) return;

      if (state == ProcessingState.completed) {
        _isPlaying = false;
        _isAudioLoading = false;
        notifyListeners();
        // Petit délai pour laisser le player se stabiliser avant la transition
        Future.delayed(const Duration(milliseconds: 300), playNext);
      }
    });
  }

  // ── Persistance ────────────────────────────────────────────────────────────
  Future<void> _initDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final String? json = prefs.getString('downloaded_songs');
    if (json == null) return;
    try {
      final decoded = jsonDecode(json) as List;
      _downloadedSongs = decoded.map((j) => Song(
        id: j['id'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String,
        duration: (j['duration'] as num).toInt(),
        coverUrl: j['coverUrl'] as String? ?? '',
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
    _isLoading = true;
    _errorMessage = null;
    _songs = [];
    notifyListeners();
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {'q': query.trim()});
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        _errorMessage = 'Erreur serveur (${response.statusCode})';
      } else {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final rawList = decoded['results'];
          if (rawList is List) {
            for (final item in rawList) {
              if (item is Map<String, dynamic>) {
                try { _songs.add(Song.fromJson(item)); } catch (_) {}
              }
            }
          }
        }
        debugPrint('[FLUTTER] ${_songs.length} chansons affichées');
      }
    } on http.ClientException {
      _errorMessage = 'Serveur inaccessible. Lancez : node server.js';
    } catch (e) {
      _errorMessage = 'Erreur : $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  void clearSearch() {
    _songs = [];
    _errorMessage = null;
    notifyListeners();
  }

  // ── LECTURE PRINCIPALE ─────────────────────────────────────────────────────
  //
  // LOGIQUE :
  //   1. myId = ++_loadId  →  invalide tous les chargements précédents
  //   2. _isChangingSong = true  →  bloque le listener pendant la transition
  //   3. Mise à jour UI immédiate (_currentSong, _isPlaying, _isAudioLoading)
  //   4. stop() → résolution source → setUrl/setFilePath → play()
  //   5. Après chaque await : si myId != _loadId → return SANS toucher aux flags
  //      (un appel plus récent gère maintenant le player)
  //   6. SEUL l'appel gagnant (myId == _loadId) remet _isChangingSong à false
  //
  Future<void> playSong(Song song, {List<Song>? queue}) async {
    final myId = ++_loadId;
    _isChangingSong = true; // Bloquer le listener

    // ── Mise à jour de la queue ──────────────────────────────────────────
    _currentSong = song;
    if (queue != null && queue.isNotEmpty) {
      _queue = List.from(queue);
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) _currentIndex = 0;
    } else if (_songs.isNotEmpty) {
      _queue = List.from(_songs);
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) { _queue = [song]; _currentIndex = 0; }
    } else {
      _queue = [song];
      _currentIndex = 0;
    }

    // ── UI : intention de jouer, chargement ─────────────────────────────
    _isPlaying = true;
    _isAudioLoading = true;
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > 20) _recentlyPlayed.removeLast();
    notifyListeners();

    try {
      // Étape 1 : Stopper proprement le player en cours
      await _audioPlayer.stop();
      // Si un appel plus récent est arrivé pendant le stop() : on abandonne
      // SANS toucher à _isChangingSong (le nouveau appel le gère lui-même)
      if (myId != _loadId) return;

      // Étape 2 : Résoudre la source audio
      String? source;
      try {
        final dir = await getApplicationDocumentsDirectory();
        final local = File('${dir.path}/${song.id}.m4a');
        if (await local.exists()) {
          debugPrint('[FLUTTER] Lecture hors-ligne : ${song.id}');
          source = local.path;
        } else {
          if (myId != _loadId) return;
          debugPrint('[FLUTTER] Lecture proxy : $_baseUrl/proxy/${song.id}');
          source = '$_baseUrl/proxy/${song.id}';
        }
      } catch (e) {
        debugPrint('[FLUTTER] Résolution source erreur : $e');
      }

      if (myId != _loadId) return;

      if (source == null) {
        // Échec résolution : on est le gagnant, on reset tout
        _isChangingSong = false;
        _isPlaying = false;
        _isAudioLoading = false;
        notifyListeners();
        return;
      }

      // Étape 3 : Charger dans le player avec fallback automatique
      if (source.startsWith('http')) {
        await _audioPlayer.setUrl(source);
      } else {
        // Fichier local : vérifier qu'il n'est pas corrompu (< 50KB = incomplet)
        final localFile = File(source);
        final fileSize = await localFile.length();
        if (fileSize < 50000) {
          debugPrint('[FLUTTER] Fichier local corrompu ($fileSize bytes), suppression et fallback proxy');
          await localFile.delete();
          // Retirer de la liste des téléchargements
          _downloadedSongs.removeWhere((s) => s.id == song.id);
          _saveDownloads();
          if (myId != _loadId) return;
          // Fallback vers le proxy
          await _audioPlayer.setUrl('$_baseUrl/proxy/${song.id}');
        } else {
          try {
            await _audioPlayer.setFilePath(source);
          } catch (e) {
            // setFilePath a échoué (threading Windows ou format) → fallback proxy
            debugPrint('[FLUTTER] setFilePath échoué, fallback proxy : $e');
            if (myId != _loadId) return;
            await _audioPlayer.setUrl('$_baseUrl/proxy/${song.id}');
          }
        }
      }
      if (myId != _loadId) return;

      // Étape 4 : Lancer la lecture — on est le gagnant, libérer les flags
      _isChangingSong = false; // ← Seul l'appel gagnant remet ce flag à false
      _isAudioLoading = false;
      notifyListeners();
      await _audioPlayer.play();

    } catch (e) {
      // "Loading interrupted" = causé par un stop() plus récent. Normal.
      // On ne remet les flags à false QUE si on est encore le gagnant.
      if (myId == _loadId) {
        _isChangingSong = false;
        _isPlaying = false;
        _isAudioLoading = false;
        notifyListeners();
      }
      debugPrint('[FLUTTER] playSong error: $e');
    }
  }

  // ── Contrôles ──────────────────────────────────────────────────────────────

  void togglePlayPause() {
    if (_isAudioLoading) return; // En chargement → ignorer

    if (_isPlaying) {
      _audioPlayer.pause();
      _isPlaying = false;
      notifyListeners();
    } else {
      final ps = _audioPlayer.processingState;
      if (ps == ProcessingState.ready || ps == ProcessingState.buffering) {
        _audioPlayer.play();
        _isPlaying = true;
        notifyListeners();
      }
    }
  }

  void playNext() {
    if (_queue.isEmpty || _currentIndex < 0) return;
    if (_currentIndex < _queue.length - 1) {
      playSong(_queue[_currentIndex + 1], queue: _queue);
    } else {
      _isPlaying = false;
      _isAudioLoading = false;
      notifyListeners();
    }
  }

  void playPrevious() {
    if (_currentSong == null) return;
    if (_audioPlayer.position.inSeconds > 3) {
      _audioPlayer.seek(Duration.zero);
      return;
    }
    if (_queue.isEmpty || _currentIndex <= 0) {
      _audioPlayer.seek(Duration.zero);
      return;
    }
    playSong(_queue[_currentIndex - 1], queue: _queue);
  }

  void addToQueue(Song song) {
    if (!_queue.any((s) => s.id == song.id)) _queue.add(song);
    notifyListeners();
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

  bool isFavorite(Song song) => _favoriteSongs.any((s) => s.id == song.id);

  // ── Playlists ──────────────────────────────────────────────────────────────
  void createPlaylist(String name) {
    _playlists.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'songs': <Song>[],
    });
    notifyListeners();
  }

  void addSongToPlaylist(String playlistId, Song song) {
    final pl = _playlists.firstWhere((p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isNotEmpty) {
      (pl['songs'] as List<Song>).add(song);
      notifyListeners();
    }
  }

  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    final pl = _playlists.firstWhere((p) => p['id'] == playlistId, orElse: () => {});
    if (pl.isEmpty) return [];
    return List<Song>.from(pl['songs'] as List<Song>);
  }

  // ── Téléchargements ────────────────────────────────────────────────────────
  bool isDownloaded(Song song) => _downloadedSongs.any((s) => s.id == song.id);

  Future<void> downloadSong(Song song, {VoidCallback? onComplete}) async {
    if (isDownloaded(song)) return;
    _downloadProgress[song.id] = 0.0;
    notifyListeners();
    bool success = false;
    try {
      final res = await http.get(Uri.parse('$_baseUrl/stream/${song.id}'));
      if (res.statusCode == 200) {
        final streamUrl = (jsonDecode(res.body) as Map)['url'] as String?;
        if (streamUrl != null) {
          final dir = await getApplicationDocumentsDirectory();
          final savePath = '${dir.path}/${song.id}.m4a';
          await Dio().download(streamUrl, savePath, onReceiveProgress: (rec, tot) {
            if (tot != -1) { _downloadProgress[song.id] = rec / tot; notifyListeners(); }
          });
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
    if (success && onComplete != null) onComplete();
  }

  Future<void> removeDownload(Song song) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${song.id}.m4a');
    if (await file.exists()) await file.delete();
    _downloadedSongs.removeWhere((s) => s.id == song.id);
    await _saveDownloads();
    notifyListeners();
  }
}