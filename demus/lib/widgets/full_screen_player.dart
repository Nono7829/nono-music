import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';
import 'song_options_menu.dart';

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
    final provider = context.watch<MusicProvider>();
    final song     = provider.currentSong;
    if (song == null) return const SizedBox.shrink();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Arrière-plan flouté
            song.coverUrl.isNotEmpty
                ? Image.network(song.coverUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF1C1C1E)))
                : const ColoredBox(color: Color(0xFF1C1C1E)),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: const ColoredBox(color: Colors.black54),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 32, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text('Lecture en cours',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz, color: Colors.white70),
                          onPressed: () => showSongOptionsMenu(context, song),
                        ),
                      ],
                    ),
                  ),
                  // Pochette
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: song.coverUrl.isNotEmpty
                              ? Image.network(song.coverUrl, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _placeholder())
                              : _placeholder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Titre + favori
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(song.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 20,
                                    fontWeight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(song.artist,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white60, fontSize: 16)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            provider.isFavorite(song) ? Icons.favorite : Icons.favorite_border,
                            color: provider.isFavorite(song) ? const Color(0xFFFF2D55) : Colors.white60,
                            size: 26,
                          ),
                          onPressed: () => provider.toggleFavorite(song),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Barre de progression
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: StreamBuilder<PositionData>(
                      stream: provider.positionDataStream,
                      builder: (_, snap) {
                        final pd  = snap.data;
                        final pos = pd?.position ?? Duration.zero;
                        final dur = pd?.duration  ?? Duration.zero;
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
                                    ? (v) => provider.audioPlayer.seek(
                                        Duration(milliseconds: (v * dur.inMilliseconds).round()))
                                    : null,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_fmt(pos),
                                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  Text(dur > pos ? '-${_fmt(dur - pos)}' : '0:00',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Contrôles
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shuffle_rounded, color: Colors.white54, size: 22),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 42),
                          onPressed: provider.isAudioLoading ? null : provider.playPrevious,
                        ),
                        GestureDetector(
                          onTap: provider.isAudioLoading ? null : provider.togglePlayPause,
                          child: Container(
                            width: 66, height: 66,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: provider.isAudioLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black))
                                : Icon(
                                    provider.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.black, size: 38),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 42),
                          onPressed: provider.isAudioLoading ? null : provider.playNext,
                        ),
                        IconButton(
                          icon: const Icon(Icons.repeat_rounded, color: Colors.white54, size: 22),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  // Volume
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_down_rounded, color: Colors.white54, size: 18),
                        Expanded(
                          child: StreamBuilder<double>(
                            stream: provider.audioPlayer.volumeStream,
                            builder: (_, snap) {
                              final vol = snap.data ?? 1.0;
                              return SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: SliderComponentShape.noOverlay,
                                  activeTrackColor: Colors.white54,
                                  inactiveTrackColor: Colors.white12,
                                  thumbColor: Colors.white54,
                                ),
                                child: Slider(
                                  value: vol,
                                  onChanged: (v) => provider.audioPlayer.setVolume(v),
                                ),
                              );
                            },
                          ),
                        ),
                        const Icon(Icons.volume_up_rounded, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
      color: const Color(0xFF2C2C2E),
      child: const Icon(Icons.music_note, color: Colors.white24, size: 80));
}