import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import 'full_screen_player.dart';
import 'song_options_menu.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final song = provider.currentSong;
    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const FullScreenPlayer(),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              // Pochette
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  song.coverUrl,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 46,
                    height: 46,
                    color: const Color(0xFF1C1C1E),
                    child: const Icon(Icons.music_note, color: Colors.white30),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Titre + artiste
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Play / Pause / Loading
              SizedBox(
                width: 40,
                height: 40,
                child: provider.isAudioLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF2D55),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          provider.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: provider.togglePlayPause,
                        padding: EdgeInsets.zero,
                      ),
              ),
              // Suivant
              IconButton(
                icon: const Icon(Icons.skip_next_rounded,
                    color: Colors.white, size: 26),
                onPressed: provider.isAudioLoading ? null : provider.playNext,
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    color: Colors.white70, size: 24),
                onPressed: () => showSongOptionsMenu(context, song),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}