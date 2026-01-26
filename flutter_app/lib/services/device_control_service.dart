import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Device Control Service for OSD
///
/// Manages device-specific settings for kiosk/display mode:
/// - Screen wake lock (prevent screen sleep)
/// - Screen brightness control
class DeviceControlService extends ChangeNotifier {
  static DeviceControlService? _instance;
  static DeviceControlService get instance {
    _instance ??= DeviceControlService._internal();
    return _instance!;
  }

  DeviceControlService._internal();

  bool _initialized = false;
  bool _wakeLockEnabled = false;
  double _brightness = 1.0;

  // Getters
  bool get wakeLockEnabled => _wakeLockEnabled;
  double get brightness => _brightness;

  /// Initialize the device control service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Enable wake lock by default for kiosk displays
      await enableWakeLock();

      // Get current brightness
      try {
        _brightness = await ScreenBrightness().current;
      } catch (e) {
        debugPrint('⚠️ [OSD DEVICE] Could not get brightness: $e');
        _brightness = 1.0;
      }

      _initialized = true;
      debugPrint('✅ [OSD DEVICE] Service initialized');
      debugPrint('   Wake Lock: $_wakeLockEnabled');
      debugPrint('   Brightness: $_brightness');
    } catch (e) {
      debugPrint('❌ [OSD DEVICE] Failed to initialize: $e');
    }
  }

  /// Enable screen wake lock (prevent screen from turning off)
  Future<void> enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      _wakeLockEnabled = true;
      debugPrint('🔒 [OSD DEVICE] Wake lock enabled');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [OSD DEVICE] Failed to enable wake lock: $e');
    }
  }

  /// Disable screen wake lock
  Future<void> disableWakeLock() async {
    try {
      await WakelockPlus.disable();
      _wakeLockEnabled = false;
      debugPrint('🔓 [OSD DEVICE] Wake lock disabled');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [OSD DEVICE] Failed to disable wake lock: $e');
    }
  }

  /// Toggle wake lock
  Future<void> toggleWakeLock() async {
    if (_wakeLockEnabled) {
      await disableWakeLock();
    } else {
      await enableWakeLock();
    }
  }

  /// Set screen brightness (0.0 to 1.0)
  Future<void> setBrightness(double brightness) async {
    final clampedBrightness = brightness.clamp(0.0, 1.0);

    try {
      await ScreenBrightness().setScreenBrightness(clampedBrightness);
      _brightness = clampedBrightness;
      debugPrint('💡 [OSD DEVICE] Brightness set to $clampedBrightness');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [OSD DEVICE] Failed to set brightness: $e');
    }
  }

  /// Reset brightness to system default
  Future<void> resetBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
      _brightness = await ScreenBrightness().current;
      debugPrint('💡 [OSD DEVICE] Brightness reset to system default');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [OSD DEVICE] Failed to reset brightness: $e');
    }
  }

  /// Set display to "kiosk mode" (full brightness, wake lock enabled)
  Future<void> enableKioskMode() async {
    await enableWakeLock();
    await setBrightness(1.0);
    debugPrint('📺 [OSD DEVICE] Kiosk mode enabled');
  }

  /// Disable kiosk mode
  Future<void> disableKioskMode() async {
    await disableWakeLock();
    await resetBrightness();
    debugPrint('📺 [OSD DEVICE] Kiosk mode disabled');
  }
}
