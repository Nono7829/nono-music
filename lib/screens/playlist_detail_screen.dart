import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/music_provider.dart';
import '../models/song.dart';
import '../widgets/song_options_menu.dart';
import '../main.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Map<String, dynamic> playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Song> _songs = [];
  bool _isLoading = true;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.playlist['coverUrl'] as String?;
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final songs = await context
        .read<MusicProvider>()
        .getPlaylistSongs(widget.playlist['id']);
    setState(() {
      _songs = songs;
      _isLoading = false;
    });
  }

  Future<void> _pickCover() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _coverUrl = image.path;
      });
      
      // Sauvegarder la cover dans la playlist
      if (!mounted) return;
      context.read<MusicProvider>().updatePlaylistCover(
        widget.playlist['id'] as String,
        image.path,
      );
      
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('🖼️ Photo mise à jour'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _playAll() {
    if (_songs.isEmpty) return;
    context.read<MusicProvider>().playSong(_songs.first, queue: _songs);
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('▶️ Lecture de la playlist'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _playShuffle() {
    if (_songs.isEmpty) return;
    final shuffled = List<Song>.from(_songs)..shuffle();
    context.read<MusicProvider>().playSong(shuffled.first, queue: shuffled);
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('🔀 Lecture aléatoire'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _downloadPlaylist() async {
    final provider = context.read<MusicProvider>();
    
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('⬇️ Téléchargement de la playlist...'),
        duration: Duration(seconds: 3),
      ),
    );
    
    await provider.downloadPlaylist(
      widget.playlist['id'] as String,
      onComplete: () {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF30D158),
            content: Text('✅ Playlist téléchargée !',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
            duration: Duration(seconds: 3),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final isFullyDownloaded = provider.isPlaylistFullyDownloaded(widget.playlist['id'] as String);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          // App bar avec cover
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFFFF2D55)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image
                  if (_coverUrl != null && _coverUrl!.isNotEmpty)
                    _coverUrl!.startsWith('http')
                        ? Image.network(_coverUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultCover())
                        : Image.file(File(_coverUrl!), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultCover())
                  else if (_songs.isNotEmpty)
                    Image.network(_songs.first.coverUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultCover())
                  else
                    _defaultCover(),
                  
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0A0A0A).withValues(alpha: 0.8),
                          const Color(0xFF0A0A0A),
                        ],
                      ),
                    ),
                  ),
                  
                  // Bouton de changement de photo
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      onPressed: _pickCover,
                      backgroundColor: const Color(0xFFFF2D55),
                      child: const Icon(Icons.camera_alt_rounded, size: 20),
                    ),
                  ),
                  
                  // Titre de la playlist
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.playlist['name'] as String,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 20,
                                color: Colors.black,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_songs.length} titre${_songs.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Boutons d'action
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  // Bouton Lire
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _songs.isEmpty ? null : _playAll,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Lire',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D55),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Bouton Aléatoire
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _songs.isEmpty ? null : _playShuffle,
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Aléatoire',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Bouton Télécharger
                  Container(
                    decoration: BoxDecoration(
                      color: isFullyDownloaded
                          ? const Color(0xFF30D158).withValues(alpha: 0.2)
                          : const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _songs.isEmpty
                          ? null
                          : (isFullyDownloaded ? null : _downloadPlaylist),
                      icon: Icon(
                        isFullyDownloaded
                            ? Icons.download_done_rounded
                            : Icons.download_rounded,
                        color: isFullyDownloaded
                            ? const Color(0xFF30D158)
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Liste des chansons
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF2D55)),
              ),
            )
          else if (_songs.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.queue_music_rounded,
                        color: Colors.white24, size: 64),
                    SizedBox(height: 16),
                    Text('Cette playlist est vide.',
                        style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Ajoutez des titres depuis le menu des chansons.',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = _songs[index];
                    final isDownloaded = provider.isDownloaded(song);
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Stack(
                        children: [
                          ClipRounded(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              song.coverUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: const Color(0xFF2C2C2E),
                                child: const Icon(Icons.music_note,
                                    color: Colors.white30),
                              ),
                            ),
                          ),
                          if (isDownloaded)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF30D158),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.download_done_rounded,
                                  size: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.durationFormatted,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded,
                                color: Colors.grey, size: 20),
                            onPressed: () => showSongOptionsMenu(context, song),
                          ),
                        ],
                      ),
                      onTap: () => provider.playSong(song, queue: _songs),
                      onLongPress: () => showSongOptionsMenu(context, song),
                    );
                  },
                  childCount: _songs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      color: const Color(0xFF2C2C2E),
      child: const Center(
        child: Icon(
          Icons.queue_music_rounded,
          size: 80,
          color: Colors.white24,
        ),
      ),
    );
  }
}

class ClipRounded extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const ClipRounded({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: child,
    );
  }
}
