import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_provider.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final song = provider.currentSong;

    if (song == null) return const SizedBox.shrink();

    return Container(
      height: 65,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10)],
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(song.coverUrl, width: 45, height: 45, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: Icon(provider.isPlaying ? Icons.pause : Icons.play_arrow),
            iconSize: 32,
            onPressed: () => provider.togglePlayPause(),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
