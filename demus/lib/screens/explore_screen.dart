import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import 'main_navigation.dart';

// ─── Données statiques des catégories ────────────────────────────────────────

class _Genre {
  final String label;
  final String query;
  final Color  color;
  final IconData icon;
  const _Genre(this.label, this.query, this.color, this.icon);
}

const _genres = [
  _Genre('Rap FR',      'rap français 2024',       Color(0xFF8B5CF6), Icons.mic_rounded),
  _Genre('Pop',         'pop hits 2024',            Color(0xFFEC4899), Icons.star_rounded),
  _Genre('R&B / Soul',  'rnb soul hits',            Color(0xFFF59E0B), Icons.favorite_rounded),
  _Genre('Hip-Hop',     'hip hop hits',             Color(0xFF3B82F6), Icons.headphones_rounded),
  _Genre('Électro',     'electronic dance music',   Color(0xFF06B6D4), Icons.equalizer_rounded),
  _Genre('Afrobeats',   'afrobeats hits 2024',      Color(0xFF10B981), Icons.music_note_rounded),
  _Genre('Drill',       'drill music 2024',         Color(0xFF6366F1), Icons.bolt_rounded),
  _Genre('Classique',   'musique classique',        Color(0xFF64748B), Icons.piano_rounded),
  _Genre('Jazz',        'jazz music best',          Color(0xFFD97706), Icons.queue_music_rounded),
  _Genre('Reggaeton',   'reggaeton hits 2024',      Color(0xFFEF4444), Icons.celebration_rounded),
  _Genre('K-Pop',       'kpop hits 2024',           Color(0xFFF43F5E), Icons.album_rounded),
  _Genre('Rock',        'rock classics',            Color(0xFF475569), Icons.electric_bolt_rounded),
];

class _Chart {
  final String label;
  final String query;
  final String emoji;
  const _Chart(this.label, this.query, this.emoji);
}

const _charts = [
  _Chart('Top France',       'top hits france 2024',       '🇫🇷'),
  _Chart('Top Mondial',      'top world hits 2024',        '🌍'),
  _Chart('Rap FR Charts',    'top rap français 2024',      '🎤'),
  _Chart('Nouvelles sorties','nouveautés musique 2024',    '🆕'),
  _Chart('Années 2000',      'hits années 2000',           '💿'),
  _Chart('Années 90',        'best hits 90s',              '📼'),
];

// ─── Écran principal ──────────────────────────────────────────────────────────

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {

  void _launchSearch(String query) {
    // Déclenche la recherche et navigue vers l'onglet Recherche
    context.read<MusicProvider>().searchYouTube(query);
    MainNavigation.of(context)?.goToSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text('Explorer',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              background: Container(color: const Color(0xFF0A0A0A)),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Bannière top ─────────────────────────────────────────
                _TopBanner(onTap: () => _launchSearch('top hits 2024')),
                const SizedBox(height: 28),

                // ── Charts ───────────────────────────────────────────────
                _SectionHeader(
                  title: 'Classements',
                  subtitle: 'Les titres qui cartonnent',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _charts.length,
                    itemBuilder: (_, i) => _ChartChip(
                      chart: _charts[i],
                      onTap: () => _launchSearch(_charts[i].query),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Humeurs / Moments ─────────────────────────────────────
                _SectionHeader(
                  title: 'Humeurs & moments',
                  subtitle: 'Une playlist pour chaque instant',
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.8,
                  children: [
                    _MoodTile('Bonne humeur 😊', 'feel good music', const Color(0xFFFBBF24)),
                    _MoodTile('Concentration 🧠', 'focus study music', const Color(0xFF60A5FA)),
                    _MoodTile('Sport 💪', 'workout motivation music', const Color(0xFF34D399)),
                    _MoodTile('Détente 😌', 'chill relaxing music', const Color(0xFFA78BFA)),
                    _MoodTile('Soirée 🎉', 'party hits music', const Color(0xFFF87171)),
                    _MoodTile('Nostalgie 🕰️', 'nostalgia classics hits', const Color(0xFFFB923C)),
                  ].map((t) => GestureDetector(
                    onTap: () => _launchSearch(t.query),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: t.color.withOpacity(0.15), // CORRIGÉ ICI
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: t.color.withOpacity(0.3), // CORRIGÉ ICI
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(t.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(t.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t.color,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 28),

                // ── Genres ───────────────────────────────────────────────
                _SectionHeader(
                  title: 'Genres',
                  subtitle: 'Plongez dans un style musical',
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.9,
                  ),
                  itemCount: _genres.length,
                  itemBuilder: (_, i) => _GenreCard(
                    genre: _genres[i],
                    onTap: () => _launchSearch(_genres[i].query),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Artistes populaires ───────────────────────────────────
                _SectionHeader(
                  title: 'Artistes populaires',
                  subtitle: 'Recherche rapide par artiste',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    'PLK', 'Damso', 'Ninho', 'Aya Nakamura',
                    'Jul', 'Hamza', 'Freeze Corleone', 'Stromae',
                    'Nekfeu', 'SCH', 'Gims', 'Orelsan',
                    'Drake', 'Travis Scott', 'Kendrick Lamar', 'The Weeknd',
                    'Taylor Swift', 'Dua Lipa', 'Bad Bunny', 'Rosalía',
                  ].map((artist) => GestureDetector(
                    onTap: () => _launchSearch(artist),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(artist,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets internes ─────────────────────────────────────────────────────────

class _MoodTile {
  final String label;
  final String query;
  final Color  color;
  final String emoji;
  _MoodTile(String labelWithEmoji, this.query, this.color)
    : label = labelWithEmoji.replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true), '').trim(),
      emoji = RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}]', unicode: true)
              .firstMatch(labelWithEmoji)?.group(0) ?? '';
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 13)),
    ],
  );
}

class _TopBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _TopBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF2D55), Color(0xFFFF6B35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Top Hits 2024',
                    style: TextStyle(
                      color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('Les meilleurs titres du moment',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartChip extends StatelessWidget {
  final _Chart chart;
  final VoidCallback onTap;
  const _ChartChip({required this.chart, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(chart.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(chart.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final _Genre genre;
  final VoidCallback onTap;
  const _GenreCard({required this.genre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: genre.color.withOpacity(0.15), // CORRIGÉ ICI
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: genre.color.withOpacity(0.35)), // CORRIGÉ ICI
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: genre.color.withOpacity(0.2), // CORRIGÉ ICI
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(genre.icon, color: genre.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(genre.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: genre.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: genre.color.withOpacity(0.6), size: 18), // CORRIGÉ ICI
          ],
        ),
      ),
    );
  }
}