import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Audio Service for OSD
///
/// Plays notification sounds when orders become ready.
/// Used to alert customers that their order is ready for pickup.
class AudioService {
  static AudioService? _instance;
  static AudioService get instance {
    _instance ??= AudioService._internal();
    return _instance!;
  }

  AudioService._internal();

  late AudioPlayer _player;
  bool _initialized = false;
  bool _soundEnabled = true;

  // Getters
  bool get soundEnabled => _soundEnabled;

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _player = AudioPlayer();
      _initialized = true;
      debugPrint('✅ [OSD AUDIO] Service initialized');
    } catch (e) {
      debugPrint('❌ [OSD AUDIO] Failed to initialize: $e');
    }
  }

  /// Play the "order ready" notification sound
  Future<void> playOrderReadySound() async {
    if (!_initialized || !_soundEnabled) return;

    try {
      debugPrint('🔔 [OSD AUDIO] Playing order ready sound');
      await _player.play(AssetSource('sounds/order_ready.mp3'));
    } catch (e) {
      debugPrint('❌ [OSD AUDIO] Failed to play sound: $e');
      // Try fallback sound
      try {
        await _player.play(AssetSource('sounds/notification.mp3'));
      } catch (e2) {
        debugPrint('❌ [OSD AUDIO] Fallback sound also failed: $e2');
      }
    }
  }

  /// Play a generic notification sound
  Future<void> playNotificationSound() async {
    if (!_initialized || !_soundEnabled) return;

    try {
      await _player.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('❌ [OSD AUDIO] Failed to play notification: $e');
    }
  }

  /// Enable or disable sound
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    debugPrint('🔊 [OSD AUDIO] Sound ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (!_initialized) return;
    await _player.setVolume(volume.clamp(0.0, 1.0));
    debugPrint('🔊 [OSD AUDIO] Volume set to $volume');
  }

  /// Stop any currently playing sound
  Future<void> stop() async {
    if (!_initialized) return;
    await _player.stop();
  }

  /// Dispose the audio player
  Future<void> dispose() async {
    if (!_initialized) return;
    await _player.dispose();
    _initialized = false;
  }
}
