import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_spacing.dart';
import '../services/music_provider.dart';
import 'song_options_menu.dart';
import 'queue_sheet.dart';

class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});

  String _fmt(Duration d) {
    if (d.inMilliseconds <= 0) return '0:00';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final song = context.select((MusicProvider p) => p.currentSong);
    if (song == null) return const SizedBox.shrink();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Blurred background ────────────────────────────────────────
            song.coverUrl.isNotEmpty
                ? Image.network(song.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: AppColors.surface))
                : const ColoredBox(color: AppColors.surface),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 72, sigmaY: 72),
              child: const ColoredBox(color: Color(0xCC000000)),
            ),

            // ── Content ───────────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.sm),

                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),

                  // Top bar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 32, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            'En lecture',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.calloutMedium
                                .copyWith(color: Colors.white60),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz,
                              color: Colors.white70),
                          onPressed: () => showSongOptionsMenu(context, song),
                        ),
                      ],
                    ),
                  ),

                  // Album art
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl + AppSpacing.sm),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.albumArtLg + 2),
                          child: song.coverUrl.isNotEmpty
                              ? Image.network(song.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _placeholder())
                              : _placeholder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Title + favorite
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.title3
                                    .copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.subhead
                                    .copyWith(color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        _FavoriteButton(song: song),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg + 4),
                    child: _ProgressBar(fmtFn: _fmt),
                  ),

                  // Controls
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                    child: _ControlRow(),
                  ),

                  // Volume
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
                    child: _VolumeSlider(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
      color: AppColors.surfaceHighlight,
      child: const Icon(Icons.music_note, color: Colors.white24, size: 80));
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _FavoriteButton extends StatelessWidget {
  final dynamic song;
  const _FavoriteButton({required this.song});

  @override
  Widget build(BuildContext context) {
    final isFav = context.select((MusicProvider p) => p.isFavorite(song));
    return IconButton(
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? AppColors.accent : Colors.white54,
        size: 26,
      ),
      onPressed: () => context.read<MusicProvider>().toggleFavorite(song),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String Function(Duration) fmtFn;
  const _ProgressBar({required this.fmtFn});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MusicProvider>();
    return StreamBuilder<PositionData>(
      stream: provider.positionDataStream,
      builder: (_, snap) {
        final pd = snap.data;
        final pos = pd?.position ?? Duration.zero;
        final dur = pd?.duration ?? Duration.zero;
        final pct = dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: pct,
                onChanged: dur.inMilliseconds > 0
                    ? (v) => provider.audioPlayer.seek(Duration(
                        milliseconds: (v * dur.inMilliseconds).round()))
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmtFn(pos),
                      style: AppTextStyles.caption1
                          .copyWith(color: Colors.white54)),
                  Text(dur > pos ? '-${fmtFn(dur - pos)}' : '0:00',
                      style: AppTextStyles.caption1
                          .copyWith(color: Colors.white54)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final isLoading = provider.isAudioLoading;
    final isPlaying = provider.isPlaying;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.queue_music_rounded,
              color: Colors.white70, size: 22),
          onPressed: () => showQueueSheet(context),
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded,
              color: Colors.white, size: 42),
          onPressed: isLoading ? null : provider.playPrevious,
        ),
        GestureDetector(
          onTap: isLoading ? null : provider.togglePlayPause,
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.black))
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 40,
                  ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded,
              color: Colors.white, size: 42),
          onPressed: isLoading ? null : provider.playNext,
        ),
        IconButton(
          icon:
              const Icon(Icons.repeat_rounded, color: Colors.white38, size: 22),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.volume_down_rounded, color: Colors.white38, size: 18),
        Expanded(
          child: StreamBuilder<double>(
            stream: context.read<MusicProvider>().audioPlayer.volumeStream,
            builder: (_, snap) {
              final vol = snap.data ?? 1.0;
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: Colors.white38,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: Colors.white38,
                ),
                child: Slider(
                  value: vol,
                  onChanged: (v) =>
                      context.read<MusicProvider>().audioPlayer.setVolume(v),
                ),
              );
            },
          ),
        ),
        const Icon(Icons.volume_up_rounded, color: Colors.white38, size: 18),
      ],
    );
  }
}
