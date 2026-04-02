import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_spacing.dart';
import '../services/music_provider.dart';
import 'song_options_menu.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final song = context.select((MusicProvider p) => p.currentSong);
    if (song == null) return const SizedBox.shrink();

    final isPlaying      = context.select((MusicProvider p) => p.isPlaying);
    final isLoading      = context.select((MusicProvider p) => p.isAudioLoading);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Container(
        height: AppSpacing.miniPlayerH,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderSubtle, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.sm),

            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: song.coverUrl.isNotEmpty
                  ? Image.network(
                      song.coverUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: AppSpacing.sm + 4),

            // Title + artist
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.calloutBold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption1,
                  ),
                ],
              ),
            ),

            // Play / Pause / Loading
            SizedBox(
              width: 40,
              height: 40,
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                      onPressed:
                          context.read<MusicProvider>().togglePlayPause,
                      padding: EdgeInsets.zero,
                    ),
            ),

            // Skip next
            IconButton(
              icon: const Icon(Icons.skip_next_rounded,
                  color: AppColors.textPrimary, size: 26),
              onPressed: isLoading
                  ? null
                  : context.read<MusicProvider>().playNext,
              padding: EdgeInsets.zero,
            ),

            // Options
            IconButton(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary, size: 20),
              onPressed: () => showSongOptionsMenu(context, song),
              padding: EdgeInsets.zero,
            ),

            const SizedBox(width: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 48,
        height: 48,
        color: AppColors.surfaceHighlight,
        child: const Icon(Icons.music_note,
            color: AppColors.textTertiary, size: 22),
      );
}