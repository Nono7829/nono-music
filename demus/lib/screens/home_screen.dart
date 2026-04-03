import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/music_provider.dart';
import '../models/song.dart';
import '../screens/profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
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
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: AppSpacing.screenHPad,
                bottom: AppSpacing.md,
              ),
              title: Text(_greeting(), style: AppTextStyles.title1),
              background: Container(color: AppColors.background),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen()),
                  ),
                  child: _ProfileAvatar(),
                ),
              ),
            ],
          ),

          // ── Body ──────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.only(bottom: AppSpacing.bottomPad),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _RecentlyPlayedSection(),
                _FavoritesSection(),
                _WelcomeState(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Avatar ────────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'N',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ── Recently Played ───────────────────────────────────────────────────────────

class _RecentlyPlayedSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final recent =
        context.select((MusicProvider p) => p.recentlyPlayed);
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenHPad),
          child: Text('Recently played', style: AppTextStyles.sectionHeader),
        ),
        const SizedBox(height: AppSpacing.md),
        // ── FIX: height calculated to avoid overflow ──
        // Album art: 136 + spacing 8 + title ~16 + gap 3 + artist ~13 = 176 + vertical pad
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHPad),
            itemCount: recent.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _HorizontalSongCard(song: recent[i]),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ── Horizontal Song Card ──────────────────────────────────────────────────────

class _HorizontalSongCard extends StatelessWidget {
  final Song song;
  const _HorizontalSongCard({required this.song});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<MusicProvider>().playSong(song),
      child: SizedBox(
        width: 136,
        // No fixed height — Column with mainAxisSize.min expands naturally
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // ← FIX: never asks for more than it needs
          children: [
            // Album art with fixed 1:1 ratio — no height surprises
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.albumArt),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  song.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surfaceHighlight,
                    child: const Icon(Icons.music_note,
                        color: AppColors.textTertiary, size: 40),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Text is constrained: maxLines + overflow prevent any layout blowout
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.calloutMedium,
            ),
            const SizedBox(height: 3),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption1,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Favorites ─────────────────────────────────────────────────────────────────

class _FavoritesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final favorites =
        context.select((MusicProvider p) => p.favoriteSongs);
    if (favorites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenHPad),
          child: Text('Your favorites', style: AppTextStyles.sectionHeader),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...favorites
            .take(5)
            .map((s) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHPad),
                  child: _FavoriteTile(song: s),
                )),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final Song song;
  const _FavoriteTile({required this.song});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Image.network(
          song.coverUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 50,
            height: 50,
            color: AppColors.surfaceHighlight,
            child: const Icon(Icons.music_note,
                color: AppColors.textTertiary, size: 20),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.calloutMedium,
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.subhead,
      ),
      trailing: const Icon(Icons.more_horiz,
          color: AppColors.textTertiary, size: 20),
      onTap: () => context.read<MusicProvider>().playSong(song),
    );
  }
}

// ── Welcome (empty state) ─────────────────────────────────────────────────────

class _WelcomeState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isEmpty = context.select((MusicProvider p) =>
        p.recentlyPlayed.isEmpty && p.favoriteSongs.isEmpty);
    if (!isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha:0.12),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.music_note, color: AppColors.accent, size: 40),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Welcome to Nono Music', style: AppTextStyles.title3),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Search for something to start listening.',
            style: AppTextStyles.subhead,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}