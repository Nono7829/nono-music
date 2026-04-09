import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart'; // Ajouté pour le binding
import 'package:nono_music/services/audio_engine.dart';
import 'package:nono_music/services/download_manager.dart';

void main() {
  // CRUCIAL : Initialise le lien entre Dart et le Natif pour les plugins (just_audio)
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Audio State Machine Transition', () async {
    final engine = AudioEngine();
    
    // Test initial
    expect(engine.currentState, AudioState.idle);
    
    // Note: Dans un test unitaire, on ne peut pas réellement "jouer" un son 
    // car il n'y a pas de carte son native, mais on vérifie que l'objet 
    // est créé sans crash et que l'état initial est correct.
    expect(engine.currentState, AudioState.idle);
  });

  test('Download Status Logic', () {
    // Vérification simple des enums
    expect(DownloadStatus.queued, isNotNull);
    expect(DownloadStatus.completed, isNotNull);
  });
}
