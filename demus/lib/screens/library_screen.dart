import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nono_music/services/music_provider.dart';
import 'package:nono_music/screens/playlist_detail_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bibliothèque', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28)),
          backgroundColor: Colors.transparent,
          bottom: const TabBar(
            indicatorColor: Colors.pinkAccent,
            tabs: [Tab(text: "Favoris"), Tab(text: "Playlists")],
          ),
        ),
        body: TabBarView(
          children: [
            // Onglet Favoris
            musicProvider.favoriteSongs.isEmpty
                ? const Center(child: Text("Aucun favori pour le moment.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: musicProvider.favoriteSongs.length,
                    itemBuilder: (context, index) {
                      final song = musicProvider.favoriteSongs[index];
                      return ListTile(
                        leading: Image.network(song.coverUrl, width: 50, height: 50, fit: BoxFit.cover),
                        title: Text(song.title, maxLines: 1),
                        subtitle: Text(song.artist),
                        onTap: () => musicProvider.playSong(song),
                      );
                    },
                  ),
            // Onglet Playlists
            Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_box, color: Colors.pinkAccent, size: 40),
                  title: const Text("Nouvelle Playlist", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                  onTap: () => _showCreatePlaylistDialog(context),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: musicProvider.playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = musicProvider.playlists[index];
                      return ListTile(
                        leading: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.queue_music, color: Colors.white54),
                        ),
                        title: Text(playlist['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // Ouvre la vue détaillée de la playlist
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PlaylistDetailScreen(playlist: playlist)),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final txtController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Créer une playlist"),
        content: TextField(controller: txtController, decoration: const InputDecoration(hintText: "Nom de la playlist")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (txtController.text.isNotEmpty) {
                context.read<MusicProvider>().createPlaylist(txtController.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Créer", style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }
}
