import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/music_provider.dart';
import 'screens/search_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => MusicProvider(),
      child: const NonoMusicApp(),
    ),
  );
}

class NonoMusicApp extends StatelessWidget {
  const NonoMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nono Music',
      theme: ThemeData.dark(),
      home: const SearchScreen(),
    );
  }
}
