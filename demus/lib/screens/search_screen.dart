import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import '../models/song.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  void _performSearch() async {
    if (_searchController.text.isEmpty) return;
    await context.read<MusicProvider>().searchYouTube(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final songs = provider.songs;

    return Scaffold(
      appBar: AppBar(title: const Text('Recherche YouTube')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Chercher une chanson',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _performSearch,
                ),
              ),
            ),
            if (provider.isLoading)
              const CircularProgressIndicator()
            else
              Expanded(
                child: ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      title: Text(song.title),
                      subtitle: Text(song.artist),
                      leading: Image.network(song.coverUrl),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
