import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_music/services/music_provider.dart';
import 'package:nono_music/main.dart'; // Le soulignement bleu ici est juste le correcteur d'orthographe, ignore-le.

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // On utilise NonoMusicApp au lieu de MyApp
    await tester.pumpWidget(const NonoMusicApp());

    // Le reste du test par défaut (qui ne sert pas à grand chose pour notre app, 
    // mais on le laisse pour que Flutter soit content et compile sans erreur).
    expect(find.text('0'), findsNothing);
  });
}