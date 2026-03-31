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
              title: const Text('Bibliothèque', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              background: Container(color: const Color(0xFF0A0A0A)),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFFFF2D55)),
                onPressed: () => _showCreateDialog(context),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                Row(children: [
                  _QuickLink(icon: Icons.favorite_rounded, label: 'Favoris',
                    count: provider.favoriteSongs.length, color: const Color(0xFFFF2D55),
                    onTap: () => _showSheet(context, 'Favoris', provider.favoriteSongs)),
                  const SizedBox(width: 12),
                  _QuickLink(icon: Icons.download_rounded, label: 'Téléchargés',
                    count: provider.downloadedSongs.length, color: const Color(0xFF30D158),
                    onTap: () => _showSheet(context, 'Téléchargés', provider.downloadedSongs, green: true)),
                ]),
                const SizedBox(height: 28),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Playlists', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () => _showCreateDialog(context),
                    child: const Text('Nouvelle', style: TextStyle(color: Color(0xFFFF2D55), fontSize: 14)),
                  ),
                ]),
                const SizedBox(height: 8),
                if (provider.playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Column(children: [
                      Icon(Icons.queue_music_rounded, color: Colors.white12, size: 48),
                      SizedBox(height: 12),
                      Text('Aucune playlist.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      SizedBox(height: 4),
                      Text('Appuyez sur + pour en créer une.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ])),
                  )
                else
                  ...provider.playlists.map((pl) => _PlaylistTile(playlist: pl,
                      onOptions: () => _showPlaylistOptions(context, pl))),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nouvelle playlist', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: const TextStyle(color: Colors.white),
          onSubmitted: (v) { if (v.trim().isNotEmpty) { context.read<MusicProvider>().createPlaylist(v.trim()); Navigator.pop(context); } },
          decoration: InputDecoration(hintText: 'Nom de la playlist', hintStyle: const TextStyle(color: Colors.grey),
            filled: true, fillColor: const Color(0xFF2C2C2E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () { if (ctrl.text.trim().isNotEmpty) { context.read<MusicProvider>().createPlaylist(ctrl.text.trim()); Navigator.pop(context); } },
            child: const Text('Créer', style: TextStyle(color: Color(0xFFFF2D55), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  void _showPlaylistOptions(BuildContext context, Map<String, dynamic> playlist) {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(playlist['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        const Divider(color: Colors.white12),
        ListTile(
          leading: const Icon(Icons.drive_file_rename_outline, color: Colors.white),
          title: const Text('Renommer', style: TextStyle(color: Colors.white)),
          onTap: () { Navigator.pop(ctx); _showRenameDialog(context, playlist); }),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Color(0xFFFF453A)),
          title: const Text('Supprimer', style: TextStyle(color: Color(0xFFFF453A))),
          onTap: () { context.read<MusicProvider>().deletePlaylist(playlist['id'] as String); Navigator.pop(ctx); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _showRenameDialog(BuildContext context, Map<String, dynamic> playlist) {
    final ctrl = TextEditingController(text: playlist['name'] as String);
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Renommer', style: TextStyle(fontWeight: FontWeight.w700)),
      content: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(filled: true, fillColor: const Color(0xFF2C2C2E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
        TextButton(onPressed: () { if (ctrl.text.trim().isNotEmpty) { context.read<MusicProvider>().renamePlaylist(playlist['id'] as String, ctrl.text.trim()); Navigator.pop(context); } },
          child: const Text('Renommer', style: TextStyle(color: Color(0xFFFF2D55), fontWeight: FontWeight.w600))),
      ],
    ));
  }

  void _showSheet(BuildContext context, String title, List<Song> songs, {bool green = false}) {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1C1C1E), isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.95, minChildSize: 0.3, expand: false,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Divider(color: Colors.white12, height: 20),
          Expanded(child: songs.isEmpty
            ? Center(child: Text('Aucun titre.', style: TextStyle(color: Colors.grey[600])))
            : ListView.builder(controller: ctrl, itemCount: songs.length, itemBuilder: (_, i) {
                final s = songs[i];
                return ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: Image.network(s.coverUrl, width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: const Color(0xFF2C2C2E),
                        child: const Icon(Icons.music_note, color: Colors.white30)))),
                  title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: green ? const Color(0xFF30D158) : Colors.white)),
                  subtitle: Text(s.artist, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: green ? const Icon(Icons.file_download_done, color: Color(0xFF30D158)) : null,
                  onTap: () { context.read<MusicProvider>().playSong(s); Navigator.pop(context); },
                );
              })),
        ]),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon; final String label; final int count; final Color color; final VoidCallback onTap;
  const _QuickLink({required this.icon, required this.label, required this.count, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text('$count titre${count != 1 ? 's' : ''}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ]),
    ),
  ));
}

class _PlaylistTile extends StatelessWidget {
  final Map<String, dynamic> playlist; final VoidCallback onOptions;
  const _PlaylistTile({required this.playlist, required this.onOptions});
  @override
  Widget build(BuildContext context) {
    final songs = (playlist['songs'] as List<dynamic>?) ?? [];
    return ListTile(contentPadding: EdgeInsets.zero,
      leading: Container(width: 52, height: 52,
        decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(8)),
        child: songs.isNotEmpty
          ? ClipRRect(borderRadius: BorderRadius.circular(8),
              child: Image.network((songs.first as Song).coverUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.queue_music, color: Colors.white30)))
          : const Icon(Icons.queue_music_rounded, color: Colors.white30)),
      title: Text(playlist['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text('${songs.length} titre${songs.length != 1 ? 's' : ''}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.chevron_right, color: Colors.grey),
        IconButton(icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20), onPressed: onOptions),
      ]),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: playlist))),
    );
  }
}