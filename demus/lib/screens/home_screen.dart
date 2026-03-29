import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import '../models/song.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          // Large App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Accueil',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(color: const Color(0xFF0A0A0A)),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFFF2D55),
                  child: const Text(
                    'N',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Section récemment joués
                if (provider.recentlyPlayed.isNotEmpty) ...[
                  const _SectionTitle('Écoutés récemment'),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 170,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.recentlyPlayed.length,
                      itemBuilder: (_, i) =>
                          _HorizontalSongCard(song: provider.recentlyPlayed[i]),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Section favoris
                if (provider.favoriteSongs.isNotEmpty) ...[
                  const _SectionTitle('Vos favoris'),
                  const SizedBox(height: 14),
                  ...provider.favoriteSongs
                      .take(5)
                      .map((s) => _SongListTile(song: s)),
                  const SizedBox(height: 32),
                ],

                // Bandeau de bienvenue si tout est vide
                if (provider.recentlyPlayed.isEmpty &&
                    provider.favoriteSongs.isEmpty)
                  _WelcomeBanner(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _HorizontalSongCard extends StatelessWidget {
  final Song song;
  const _HorizontalSongCard({required this.song});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<MusicProvider>().playSong(song),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                song.coverUrl,
                width: 130,
                height: 130,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 130,
                  height: 130,
                  color: const Color(0xFF2C2C2E),
                  child: const Icon(Icons.music_note, color: Colors.white30, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongListTile extends StatelessWidget {
  final Song song;
  const _SongListTile({required this.song});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MusicProvider>();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          song.coverUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 48,
            height: 48,
            color: const Color(0xFF2C2C2E),
            child: const Icon(Icons.music_note, color: Colors.white30),
          ),
        ),
      ),
      title: Text(song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(song.artist,
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: const Icon(Icons.more_horiz, color: Colors.grey),
      onTap: () => provider.playSong(song),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.music_note, color: Color(0xFFFF2D55), size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bienvenue sur Nono Music',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lancez une recherche pour commencer à écouter.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}