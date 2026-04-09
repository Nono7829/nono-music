import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';

enum AudioState { idle, preparing, buffering, ready, playing, failed }

class AudioEngine {
  final AudioPlayer _player = AudioPlayer();
  AudioState _state = AudioState.idle;
  
  final StreamController<AudioState> _stateController = StreamController<AudioState>.broadcast();
  Stream<AudioState> get stateStream => _stateController.stream;

  AudioState get currentState => _state;

  Future<void> _runSafe(Future<void> Function() action) async {
    if (!kIsWeb && Platform.isWindows) {
      final completer = Completer<void>();
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        try {
          await action();
          completer.complete();
        } catch (e) {
          completer.completeError(e);
        }
      });
      return completer.future;
    }
    return action();
  }

  void _updateState(AudioState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  Future<void> loadAndPlay(AudioSource source) async {
    _updateState(AudioState.preparing);
    try {
      await _runSafe(() async {
        await _player.stop();
      });
      await _runSafe(() async {
        await _player.setAudioSource(source).timeout(const Duration(seconds: 15));
      }).timeout(const Duration(seconds: 20));

      _updateState(AudioState.ready);
      await _player.play();
      _updateState(AudioState.playing);
    } catch (e) {
      debugPrint('[AUDIO_ENGINE] Error: $e');
      _updateState(AudioState.failed);
      rethrow;
    }
  }

  void togglePlayPause() {
    if (_player.playing) {
      _player.pause();
      _updateState(AudioState.buffering);
    } else {
      _player.play();
      _updateState(AudioState.playing);
    }
  }

  void stop() => _player.stop();
  void seek(Duration pos) => _player.seek(pos);
  AudioPlayer get player => _player;

  void dispose() {
    _stateController.close();
    _player.dispose();
  }
}
