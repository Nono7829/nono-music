import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nono_music/services/music_provider.dart';


class FullScreenPlayer extends StatelessWidget {
  const FullScreenPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final song = provider.currentSong;

    if (song == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 5,
            decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 30),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(song.coverUrl, width: 300, height: 300, fit: BoxFit.cover),
          ),
          const SizedBox(height: 40),
          Text(song.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(song.artist, style: const TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 30),
          IconButton(
            icon: Icon(provider.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
            iconSize: 80,
            color: Colors.pinkAccent,
            onPressed: () => context.read<MusicProvider>().togglePlayPause(),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
