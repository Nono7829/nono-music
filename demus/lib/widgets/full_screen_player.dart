import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';

class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final song = provider.currentSong;
    if (song == null) return const SizedBox.shrink();

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 30, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('Lecture en cours',
                    style: TextStyle(color: Colors.grey, fontSize: 12,
                        fontWeight: FontWeight.w500)),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Pochette grande
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    song.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF2C2C2E),
                      child: const Icon(Icons.music_note,
                          color: Colors.white30, size: 80),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Titre + artiste + favori
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(song.artist,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    provider.isFavorite(song)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: provider.isFavorite(song)
                        ? const Color(0xFFFF2D55)
                        : Colors.grey,
                    size: 26,
                  ),
                  onPressed: () => provider.toggleFavorite(song),
                ),
              ],
            ),
          ),

          // Barre de progression simulée
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: Column(
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
                  child: Slider(value: 0.3, onChanged: (_) {}),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1:12', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text('-2:34', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          // Contrôles
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.shuffle_rounded, color: Colors.grey, size: 22),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded,
                      color: Colors.white, size: 40),
                  onPressed: () {},
                ),
                // Play / Pause
                GestureDetector(
                  onTap: provider.togglePlayPause,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      provider.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 36,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded,
                      color: Colors.white, size: 40),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.repeat_rounded, color: Colors.grey, size: 22),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Volume
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
            child: Row(
              children: [
                const Icon(Icons.volume_down_rounded, color: Colors.grey, size: 18),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: Colors.grey,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: Colors.grey,
                    ),
                    child: Slider(value: 0.7, onChanged: (_) {}),
                  ),
                ),
                const Icon(Icons.volume_up_rounded, color: Colors.grey, size: 18),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}