import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import '../models/song.dart';
import 'playlist_detail_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Bibliothèque',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              background: Container(color: const Color(0xFF0A0A0A)),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFFFF2D55)),
                onPressed: () => _showCreatePlaylistDialog(context),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Raccourcis rapides
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QuickLink(
                      icon: Icons.favorite_rounded,
                      label: 'Favoris',
                      count: provider.favoriteSongs.length,
                      color: const Color(0xFFFF2D55),
                      onTap: () => _showFavoritesSheet(context, provider),
                    ),
                    const SizedBox(width: 12),
                    _QuickLink(
                      icon: Icons.download_rounded,
                      label: 'Téléchargés',
                      count: 0,
                      color: const Color(0xFF30D158),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Titre section playlists
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Playlists',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    GestureDetector(
                      onTap: () => _showCreatePlaylistDialog(context),
                      child: const Text(
                        'Nouvelle',
                        style: TextStyle(color: Color(0xFFFF2D55), fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (provider.playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      'Aucune playlist. Appuyez sur + pour en créer une.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                else
                  ...provider.playlists.map(
                    (pl) => _PlaylistTile(playlist: pl),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nouvelle playlist',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nom de la playlist',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF2C2C2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<MusicProvider>().createPlaylist(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Créer',
                style: TextStyle(color: Color(0xFFFF2D55), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showFavoritesSheet(BuildContext context, MusicProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FavoritesSheet(songs: provider.favoriteSongs),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('$count titre${count != 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Map<String, dynamic> playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final songs = (playlist['songs'] as List<dynamic>?) ?? [];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: songs.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  (songs.first as Song).coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.queue_music, color: Colors.white30),
                ),
              )
            : const Icon(Icons.queue_music_rounded, color: Colors.white30),
      ),
      title: Text(
        playlist['name'] as String,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Text(
        '${songs.length} titre${songs.length != 1 ? 's' : ''}',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlist: playlist),
        ),
      ),
    );
  }
}

class _FavoritesSheet extends StatelessWidget {
  final List<Song> songs;
  const _FavoritesSheet({required this.songs});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 16),
        const Text('Favoris',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const Divider(color: Colors.white12, height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: songs.length,
            itemBuilder: (_, i) {
              final s = songs[i];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(s.coverUrl, width: 44, height: 44, fit: BoxFit.cover),
                ),
                title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(s.artist, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  context.read<MusicProvider>().playSong(s);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}