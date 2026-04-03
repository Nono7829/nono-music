import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/music_provider.dart';
import 'main_navigation.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class _Genre {
  final String label;
  final String query;
  final Color  color;
  final IconData icon;
  const _Genre(this.label, this.query, this.color, this.icon);
}

class _Chart {
  final String label;
  final String query;
  final String emoji;
  const _Chart(this.label, this.query, this.emoji);
}

class _Mood {
  final String emoji;
  final String label;
  final String query;
  final Color  color;
  const _Mood(this.emoji, this.label, this.query, this.color);
}

const List<_Genre> _genres = [
  _Genre('Rap FR',    'rap français 2024',      Color(0xFF8B5CF6), Icons.mic_rounded),
  _Genre('Pop',       'pop hits 2024',           Color(0xFFEC4899), Icons.star_rounded),
  _Genre('R&B / Soul','rnb soul hits',           Color(0xFFF59E0B), Icons.favorite_rounded),
  _Genre('Hip-Hop',   'hip hop hits',            Color(0xFF3B82F6), Icons.headphones_rounded),
  _Genre('Électro',   'electronic dance music',  Color(0xFF06B6D4), Icons.equalizer_rounded),
  _Genre('Afrobeats', 'afrobeats hits 2024',     Color(0xFF10B981), Icons.music_note_rounded),
  _Genre('Drill',     'drill music 2024',        Color(0xFF6366F1), Icons.bolt_rounded),
  _Genre('Classique', 'musique classique',       Color(0xFF64748B), Icons.piano_rounded),
  _Genre('Jazz',      'jazz music best',         Color(0xFFD97706), Icons.queue_music_rounded),
  _Genre('Reggaeton', 'reggaeton hits 2024',     Color(0xFFEF4444), Icons.celebration_rounded),
  _Genre('K-Pop',     'kpop hits 2024',          Color(0xFFF43F5E), Icons.album_rounded),
  _Genre('Rock',      'rock classics',           Color(0xFF475569), Icons.electric_bolt_rounded),
];

const List<_Chart> _charts = [
  _Chart('Top France',       'top hits france 2024',    '🇫🇷'),
  _Chart('Top Mondial',      'top world hits 2024',     '🌍'),
  _Chart('Rap FR Charts',    'top rap français 2024',   '🎤'),
  _Chart('Nouvelles sorties','nouveautés musique 2024', '🆕'),
  _Chart('Années 2000',      'hits années 2000',        '💿'),
  _Chart('Années 90',        'best hits 90s',           '📼'),
];

const List<_Mood> _moods = [
  _Mood('😊', 'Bonne humeur',  'feel good music',         Color(0xFFFBBF24)),
  _Mood('🧠', 'Concentration', 'focus study music',       Color(0xFF60A5FA)),
  _Mood('💪', 'Sport',         'workout motivation music', Color(0xFF34D399)),
  _Mood('😌', 'Détente',       'chill relaxing music',    Color(0xFFA78BFA)),
  _Mood('🎉', 'Soirée',        'party hits music',        Color(0xFFF87171)),
  _Mood('🕰️', 'Nostalgie',    'nostalgia classics hits', Color(0xFFFB923C)),
];

const List<String> _artists = [
  'PLK', 'Damso', 'Ninho', 'Aya Nakamura',
  'Jul', 'Hamza', 'Freeze Corleone', 'Stromae',
  'Nekfeu', 'SCH', 'Gims', 'Orelsan',
  'Drake', 'Travis Scott', 'Kendrick Lamar', 'The Weeknd',
  'Taylor Swift', 'Dua Lipa', 'Bad Bunny', 'Rosalía',
];

// ── Screen ────────────────────────────────────────────────────────────────────

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  void _search(BuildContext context, String query) {
    context.read<MusicProvider>().searchYouTube(query);
    MainNavigation.of(context)?.goToSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ───────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                  left: AppSpacing.screenHPad, bottom: AppSpacing.md),
              title: const Text('Explore', style: AppTextStyles.title1),
              background: Container(color: AppColors.background),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SliverPadding(
            padding:
                const EdgeInsets.only(bottom: AppSpacing.bottomPad),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Hero banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHPad, AppSpacing.sm,
                      AppSpacing.screenHPad, 0),
                  child: _HeroBanner(
                    onTap: () => _search(context, 'top hits 2024'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Charts
                const _SectionLabel(
                    title: 'Charts',
                    subtitle: 'What\'s trending right now'),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 88,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHPad),
                    itemCount: _charts.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _ChartChip(
                        chart: _charts[i],
                        onTap: () => _search(context, _charts[i].query),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Moods
                const _SectionLabel(
                    title: 'Moods & moments',
                    subtitle: 'A playlist for every feeling'),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHPad),
                  child: _MoodGrid(
                    moods: _moods,
                    onTap: (m) => _search(context, m.query),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Genres
                const _SectionLabel(
                    title: 'Genres',
                    subtitle: 'Dive into a sound'),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHPad),
                  child: _GenreGrid(
                    genres: _genres,
                    onTap: (g) => _search(context, g.query),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Artists
                const _SectionLabel(
                    title: 'Popular artists',
                    subtitle: 'Quick search by artist'),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHPad),
                  child: _ArtistPills(
                    artists: _artists,
                    onTap: (a) => _search(context, a),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 128,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Top Hits 2024',
                      style: AppTextStyles.title2
                          .copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('The biggest tracks right now',
                      style: AppTextStyles.subhead
                          .copyWith(color: Colors.white70)),
                ],
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.2),
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

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.screenHPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.sectionHeader),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.subhead),
        ],
      ),
    );
  }
}

// ── Chart Chip ────────────────────────────────────────────────────────────────

class _ChartChip extends StatelessWidget {
  final _Chart chart;
  final VoidCallback onTap;
  const _ChartChip({required this.chart, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.borderDefault, width: 0.5),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(chart.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              chart.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.calloutMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mood Grid ─────────────────────────────────────────────────────────────────

class _MoodGrid extends StatelessWidget {
  final List<_Mood> moods;
  final void Function(_Mood) onTap;
  const _MoodGrid({required this.moods, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:  2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing:  AppSpacing.sm,
        childAspectRatio: 3.0,
      ),
      itemCount: moods.length,
      itemBuilder: (_, i) {
        final m = moods[i];
        return GestureDetector(
          onTap: () => onTap(m),
          child: Container(
            decoration: BoxDecoration(
              color: m.color.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                  color: m.color.withValues(alpha:0.25), width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Text(m.emoji,
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    m.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.calloutMedium
                        .copyWith(color: m.color),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Genre Grid ────────────────────────────────────────────────────────────────

class _GenreGrid extends StatelessWidget {
  final List<_Genre> genres;
  final void Function(_Genre) onTap;
  const _GenreGrid({required this.genres, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:  2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing:  AppSpacing.sm,
        childAspectRatio: 2.2,
      ),
      itemCount: genres.length,
      itemBuilder: (_, i) {
        final g = genres[i];
        return GestureDetector(
          onTap: () => onTap(g),
          child: Container(
            decoration: BoxDecoration(
              color: g.color.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                  color: g.color.withValues(alpha:0.3), width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: g.color.withValues(alpha:0.18),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(g.icon, color: g.color, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    g.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.calloutBold
                        .copyWith(color: g.color),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Artist Pills ──────────────────────────────────────────────────────────────

class _ArtistPills extends StatelessWidget {
  final List<String> artists;
  final void Function(String) onTap;
  const _ArtistPills({required this.artists, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: artists
          .map(
            (a) => GestureDetector(
              onTap: () => onTap(a),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusPill),
                  border: Border.all(
                      color: AppColors.borderDefault, width: 0.5),
                ),
                child: Text(a, style: AppTextStyles.calloutMedium),
              ),
            ),
          )
          .toList(),
    );
  }
}