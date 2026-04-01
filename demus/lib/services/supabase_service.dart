import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String supabaseUrl = 'https://jfgyatpymoleqlffcaqu.supabase.co'; // À remplacer
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpmZ3lhdHB5bW9sZXFsZmZjYXF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3ODMzNjksImV4cCI6MjA5MDM1OTM2OX0.bS0x0EGSnsv48ky03vfEkpJpFCsDCPO5-70fF_23a6Q'; // À remplacer

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  // ── Initialisation ───────────────────────────────────────────────────────
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  // ── Authentification ─────────────────────────────────────────────────────
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  String? getUserId() => currentUser?.id;
  String? getUserEmail() => currentUser?.email;
  String? getUserName() => currentUser?.userMetadata?['full_name'] as String?;
  String? getUserAvatar() => currentUser?.userMetadata?['avatar_url'] as String?;

  // ── Synchronisation des favoris ──────────────────────────────────────────
  Future<void> syncFavorites(List<Song> favorites) async {
    if (!isAuthenticated) return;
    final userId = getUserId();
    if (userId == null) return;

    final data = favorites.map((s) => {
      'user_id': userId,
      'song_id': s.id,
      'title': s.title,
      'artist': s.artist,
      'cover_url': s.coverUrl,
      'duration': s.duration,
    }).toList();

    // Supprimer les anciens favoris
    await client.from('favorites').delete().eq('user_id', userId);

    // Insérer les nouveaux
    if (data.isNotEmpty) {
      await client.from('favorites').insert(data);
    }
  }

  Future<List<Song>> getFavorites() async {
    if (!isAuthenticated) return [];
    final userId = getUserId();
    if (userId == null) return [];

    final response = await client
        .from('favorites')
        .select()
        .eq('user_id', userId);

    return (response as List).map((item) {
      return Song(
        id: item['song_id'] as String,
        title: item['title'] as String,
        artist: item['artist'] as String,
        coverUrl: item['cover_url'] as String,
        duration: (item['duration'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  // ── Synchronisation des playlists ────────────────────────────────────────
  Future<void> syncPlaylists(List<Map<String, dynamic>> playlists) async {
    if (!isAuthenticated) return;
    final userId = getUserId();
    if (userId == null) return;

    // Supprimer les anciennes playlists
    await client.from('playlists').delete().eq('user_id', userId);

    for (final playlist in playlists) {
      final playlistData = {
        'user_id': userId,
        'playlist_id': playlist['id'] as String,
        'name': playlist['name'] as String,
        'cover_url': playlist['coverUrl'] as String?,
      };

      await client.from('playlists').insert(playlistData);

      // Supprimer les anciennes chansons de cette playlist
      await client.from('playlist_songs').delete().eq('playlist_id', playlist['id']);

      // Ajouter les chansons
      final songs = playlist['songs'] as List<Song>;
      if (songs.isNotEmpty) {
        final songsData = songs.map((s) => {
          'playlist_id': playlist['id'],
          'song_id': s.id,
          'title': s.title,
          'artist': s.artist,
          'cover_url': s.coverUrl,
          'duration': s.duration,
        }).toList();

        await client.from('playlist_songs').insert(songsData);
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    if (!isAuthenticated) return [];
    final userId = getUserId();
    if (userId == null) return [];

    final response = await client
        .from('playlists')
        .select()
        .eq('user_id', userId);

    final playlists = <Map<String, dynamic>>[];
    for (final item in response as List) {
      final playlistId = item['playlist_id'] as String;

      // Récupérer les chansons de cette playlist
      final songsResponse = await client
          .from('playlist_songs')
          .select()
          .eq('playlist_id', playlistId);

      final songs = (songsResponse as List).map((s) {
        return Song(
          id: s['song_id'] as String,
          title: s['title'] as String,
          artist: s['artist'] as String,
          coverUrl: s['cover_url'] as String,
          duration: (s['duration'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      playlists.add({
        'id': playlistId,
        'name': item['name'] as String,
        'coverUrl': item['cover_url'] as String?,
        'songs': songs,
      });
    }

    return playlists;
  }

  // ── Synchronisation de l'historique ──────────────────────────────────────
  Future<void> syncRecentlyPlayed(List<Song> recent) async {
    if (!isAuthenticated) return;
    final userId = getUserId();
    if (userId == null) return;

    final data = recent.asMap().entries.map((entry) => {
      'user_id': userId,
      'song_id': entry.value.id,
      'title': entry.value.title,
      'artist': entry.value.artist,
      'cover_url': entry.value.coverUrl,
      'duration': entry.value.duration,
      'played_at': DateTime.now().subtract(Duration(minutes: entry.key)).toIso8601String(),
    }).toList();

    await client.from('recently_played').delete().eq('user_id', userId);
    if (data.isNotEmpty) {
      await client.from('recently_played').insert(data);
    }
  }

  Future<List<Song>> getRecentlyPlayed() async {
    if (!isAuthenticated) return [];
    final userId = getUserId();
    if (userId == null) return [];

    final response = await client
        .from('recently_played')
        .select()
        .eq('user_id', userId)
        .order('played_at', ascending: false)
        .limit(30);

    return (response as List).map((item) {
      return Song(
        id: item['song_id'] as String,
        title: item['title'] as String,
        artist: item['artist'] as String,
        coverUrl: item['cover_url'] as String,
        duration: (item['duration'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }
}