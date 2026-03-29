import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import '../models/song.dart';
import '../widgets/full_screen_player.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _focus.unfocus();
    await context.read<MusicProvider>().searchYouTube(q);
  }

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
              title: const Text('Chercher',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              background: Container(color: const Color(0xFF0A0A0A)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Artistes, titres, albums…',
                    hintStyle:
                        const TextStyle(color: Colors.grey, fontSize: 16),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.grey, size: 20),
                    suffixIcon: ValueListenableBuilder(
                      valueListenable: _ctrl,
                      builder: (_, val, __) => val.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.cancel,
                                  color: Colors.grey, size: 18),
                              onPressed: () {
                                _ctrl.clear();
                                context.read<MusicProvider>().clearSearch();
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // Loading
          if (provider.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFF2D55)),
                    SizedBox(height: 16),
                    Text('Recherche en cours…',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )

          // Erreur
          else if (provider.errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white24, size: 48),
                      const SizedBox(height: 16),
                      Text(provider.errorMessage!,
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      const Text(
                        'Lancez le backend :\ncd demus-backend && node server.js',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )

          // Aucun résultat
          else if (provider.songs.isEmpty && _ctrl.text.isNotEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('Aucun résultat.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )

          // Résultats
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _SearchResultTile(song: provider.songs[i]),
                  childCount: provider.songs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Song song;
  const _SearchResultTile({required this.song});

  Widget _placeholder() => Container(
        width: 52,
        height: 52,
        color: const Color(0xFF2C2C2E),
        child: const Icon(Icons.music_note, color: Colors.white30),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: song.coverUrl.isNotEmpty
            ? Image.network(
                song.coverUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
      title: Text(song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(
        song.durationFormatted.isNotEmpty
            ? '${song.artist} • ${song.durationFormatted}'
            : song.artist,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              provider.isFavorite(song)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: provider.isFavorite(song)
                  ? const Color(0xFFFF2D55)
                  : Colors.grey,
              size: 20,
            ),
            onPressed: () => provider.toggleFavorite(song),
          ),
          const Icon(Icons.play_arrow_rounded, color: Colors.grey),
        ],
      ),
      onTap: () {
        provider.playSong(song);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const FullScreenPlayer(),
        );
      },
    );
  }
}