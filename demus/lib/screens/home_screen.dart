import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import '../services/auth_service.dart'; // Ajout pour l'avatar
import '../models/song.dart';
import 'profile_screen.dart'; // Ajout pour la navigation

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final authService = AuthService(); // Pour récupérer l'avatar

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          // Large App Bar Style Apple Music
          SliverAppBar(
            expandedHeight: 110,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 12),
              title: const Text(
                'Écouter',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
              background: Container(color: const Color(0xFF0A0A0A)),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20, top: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFFF2D55),
                      backgroundImage: authService.userAvatar != null 
                          ? NetworkImage(authService.userAvatar!) 
                          : null,
                      child: authService.userAvatar == null
                          ? Text(
                              authService.userName?.isNotEmpty == true 
                                  ? authService.userName![0].toUpperCase() 
                                  : 'N',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Section récemment joués
                if (provider.recentlyPlayed.isNotEmpty) ...[
                  const _SectionTitle('Récemment écouté'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: provider.recentlyPlayed.length,
                      itemBuilder: (_, i) =>
                          _HorizontalSongCard(song: provider.recentlyPlayed[i]),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],

                // Section favoris
                if (provider.favoriteSongs.isNotEmpty) ...[
                  const _SectionTitle('Vos favoris'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03), // Translucide style Apple
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: provider.favoriteSongs
                          .take(5)
                          .map((s) => _SongListTile(song: s))
                          .toList(),
                    ),
                  ),
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
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
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
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  song.coverUrl,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 140,
                    height: 140,
                    color: Colors.white.withOpacity(0.05),
                    child: const Icon(Icons.music_note, color: Colors.white30, size: 40),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          song.coverUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 48,
            height: 48,
            color: Colors.white.withOpacity(0.05),
            child: const Icon(Icons.music_note, color: Colors.white30),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        song.artist,
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
      ),
      trailing: Icon(Icons.play_circle_fill_rounded, color: Colors.white.withOpacity(0.2)),
      onTap: () => provider.playSong(song),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D55).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.music_note_rounded, color: Color(0xFFFF2D55), size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bienvenue sur Nono Music',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Lancez une recherche pour commencer à écouter.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}