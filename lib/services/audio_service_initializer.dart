import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';

abstract final class AudioServiceInitializer {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    // just_audio_background is NOT supported on Windows desktop.
    // Initializing it on Windows can create additional platform channel
    // conflicts on top of the existing just_audio_windows threading issue.
    // Skip silently — background playback notifications are a no-op on Windows.
    if (!kIsWeb && _isWindowsPlatform) {
      debugPrint('[AudioService] Skipped on Windows (not supported)');
      return;
    }

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

  static bool get _isWindowsPlatform {
    try { return Platform.isWindows; } catch (_) { return false; }
  }
}