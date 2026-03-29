import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nono_music/services/music_provider.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Map<String, dynamic> playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final songs = await context.read<MusicProvider>().getPlaylistSongs(widget.playlist['id']);
    setState(() {
      _songs = songs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist['name']),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : _songs.isEmpty
              ? const Center(child: Text("Cette playlist est vide.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(song.coverUrl, width: 50, height: 50, fit: BoxFit.cover),
                      ),
                      title: Text(song.title, maxLines: 1),
                      subtitle: Text(song.artist),
                      onTap: () => context.read<MusicProvider>().playSong(song),
                    );
                  },
                ),
    );
  }
}
