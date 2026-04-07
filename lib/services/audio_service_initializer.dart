import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';

abstract final class AudioServiceInitializer {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.nonomusic.app.channel.audio',
        androidNotificationChannelName: 'Nono Music',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        preloadArtwork: false,
      );
    } catch (e) {
      // Re-init on hot reload is a no-op — the service is already running.
      debugPrint('[AudioService] init skipped (already running): $e');
    }
  }
}