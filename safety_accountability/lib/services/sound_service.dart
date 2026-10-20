import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  /// Chime plus a short vibration. Never throws.
  static Future<void> notify() async {
    try {
      HapticFeedback.mediumImpact();
      await _player.stop();
      await _player.play(AssetSource('sounds/notify.wav'));
    } catch (_) {
      // A sound problem must never break the app.
    }
  }
}