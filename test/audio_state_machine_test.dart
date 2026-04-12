import 'package:flutter_test/flutter_test.dart';
import 'package:nono_music/services/audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Audio State Machine - initial state is idle', () async {
    final engine = AudioEngine();
    expect(engine.currentState, AudioState.idle);
  });
}