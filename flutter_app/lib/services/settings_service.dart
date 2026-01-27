import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings Service for OSD
///
/// Manages application settings including:
/// - Device configuration (display ID, store ID, etc.)
/// - Display preferences (language, theme)
/// - Connection settings
class SettingsService extends ChangeNotifier {
  static SettingsService? _instance;
  static SettingsService get instance {
    _instance ??= SettingsService._internal();
    return _instance!;
  }

  SettingsService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  // Settings keys
  static const String _keyDisplayId = 'osd_display_id';
  static const String _keyDeviceName = 'osd_device_name';
  static const String _keyOrganizationId = 'osd_organization_id';
  static const String _keyStoreId = 'osd_store_id';
  static const String _keyLanguage = 'osd_language';
  static const String _keyAutoRefreshInterval = 'osd_auto_refresh_interval';
  static const String _keyPlayReadySound = 'osd_play_ready_sound';
  static const String _keyPrimaryDisplayType = 'osd_primary_display_type';
  static const String _keyIsDarkMode = 'osd_is_dark_mode';
  static const String _keyShowElapsedTimeNowCooking = 'osd_show_elapsed_time_now_cooking';
  static const String _keyShowElapsedTimeReady = 'osd_show_elapsed_time_ready';
  static const String _keyHighlightDurationSeconds = 'osd_highlight_duration_seconds';
  static const String _keyReadySoundType = 'osd_ready_sound_type';

  // Cached settings
  String? _displayId;
  String? _deviceName;
  String? _organizationId;
  String? _storeId;
  String _language = 'ja';
  int _autoRefreshInterval = 30; // seconds
  bool _playReadySound = true;
  PrimaryDisplayType _primaryDisplayType = PrimaryDisplayType.callNumber;
  bool _isDarkMode = false; // Default to light mode
  bool _showElapsedTimeNowCooking = false; // Default to hide elapsed time on Now Cooking
  bool _showElapsedTimeReady = false; // Default to hide elapsed time on It's Ready
  int _highlightDurationSeconds = 60; // Default 1 minute highlight for newly ready orders
  ReadySoundType _readySoundType = ReadySoundType.slick; // Default sound type

  // Getters
  String? get displayId => _displayId;
  String? get deviceName => _deviceName;
  String? get organizationId => _organizationId;
  String? get storeId => _storeId;
  String get language => _language;
  int get autoRefreshInterval => _autoRefreshInterval;
  bool get playReadySound => _playReadySound;
  PrimaryDisplayType get primaryDisplayType => _primaryDisplayType;
  bool get isDarkMode => _isDarkMode;
  bool get showElapsedTimeNowCooking => _showElapsedTimeNowCooking;
  bool get showElapsedTimeReady => _showElapsedTimeReady;
  int get highlightDurationSeconds => _highlightDurationSeconds;
  Duration get highlightDuration => Duration(seconds: _highlightDurationSeconds);
  ReadySoundType get readySoundType => _readySoundType;
  bool get isConfigured =>
      _displayId != null && _storeId != null && _organizationId != null;

  /// Initialize the settings service
  static Future<void> initialize() async {
    final service = instance;
    if (!service._initialized) {
      service._prefs = await SharedPreferences.getInstance();
      await service._loadSettings();
      service._initialized = true;
      debugPrint('✅ [OSD SETTINGS] Service initialized');
    }
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    _displayId = _prefs.getString(_keyDisplayId);
    _deviceName = _prefs.getString(_keyDeviceName);
    _organizationId = _prefs.getString(_keyOrganizationId);
    _storeId = _prefs.getString(_keyStoreId);
    _language = _prefs.getString(_keyLanguage) ?? 'ja';
    _autoRefreshInterval = _prefs.getInt(_keyAutoRefreshInterval) ?? 30;
    _playReadySound = _prefs.getBool(_keyPlayReadySound) ?? true;
    final displayTypeStr = _prefs.getString(_keyPrimaryDisplayType);
    _primaryDisplayType = PrimaryDisplayType.values.firstWhere(
      (e) => e.name == displayTypeStr,
      orElse: () => PrimaryDisplayType.callNumber,
    );
    _isDarkMode = _prefs.getBool(_keyIsDarkMode) ?? false;
    _showElapsedTimeNowCooking = _prefs.getBool(_keyShowElapsedTimeNowCooking) ?? false;
    _showElapsedTimeReady = _prefs.getBool(_keyShowElapsedTimeReady) ?? false;
    _highlightDurationSeconds = _prefs.getInt(_keyHighlightDurationSeconds) ?? 60;
    final soundTypeStr = _prefs.getString(_keyReadySoundType);
    _readySoundType = ReadySoundType.values.firstWhere(
      (e) => e.name == soundTypeStr,
      orElse: () => ReadySoundType.slick,
    );

    debugPrint('📝 [OSD SETTINGS] Loaded settings:');
    debugPrint('   Display ID: $_displayId');
    debugPrint('   Device Name: $_deviceName');
    debugPrint('   Store ID: $_storeId');
    debugPrint('   Language: $_language');
    debugPrint('   Dark Mode: $_isDarkMode');
  }

  /// Set device configuration (called after display selection)
  Future<void> setDeviceConfiguration({
    required String displayId,
    required String deviceName,
    required String organizationId,
    required String storeId,
  }) async {
    _displayId = displayId;
    _deviceName = deviceName;
    _organizationId = organizationId;
    _storeId = storeId;

    await _prefs.setString(_keyDisplayId, displayId);
    await _prefs.setString(_keyDeviceName, deviceName);
    await _prefs.setString(_keyOrganizationId, organizationId);
    await _prefs.setString(_keyStoreId, storeId);

    debugPrint('✅ [OSD SETTINGS] Device configuration saved');
    notifyListeners();
  }

  /// Set language
  Future<void> setLanguage(String language) async {
    _language = language;
    await _prefs.setString(_keyLanguage, language);
    notifyListeners();
  }

  /// Set auto refresh interval (in seconds)
  Future<void> setAutoRefreshInterval(int seconds) async {
    _autoRefreshInterval = seconds;
    await _prefs.setInt(_keyAutoRefreshInterval, seconds);
    notifyListeners();
  }

  /// Set play ready sound preference
  Future<void> setPlayReadySound(bool value) async {
    _playReadySound = value;
    await _prefs.setBool(_keyPlayReadySound, value);
    notifyListeners();
  }

  /// Set primary display type
  Future<void> setPrimaryDisplayType(PrimaryDisplayType type) async {
    _primaryDisplayType = type;
    await _prefs.setString(_keyPrimaryDisplayType, type.name);
    notifyListeners();
  }

  /// Set dark mode preference
  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    await _prefs.setBool(_keyIsDarkMode, value);
    notifyListeners();
  }

  /// Set show elapsed time preference for Now Cooking
  Future<void> setShowElapsedTimeNowCooking(bool value) async {
    _showElapsedTimeNowCooking = value;
    await _prefs.setBool(_keyShowElapsedTimeNowCooking, value);
    notifyListeners();
  }

  /// Set show elapsed time preference for It's Ready
  Future<void> setShowElapsedTimeReady(bool value) async {
    _showElapsedTimeReady = value;
    await _prefs.setBool(_keyShowElapsedTimeReady, value);
    notifyListeners();
  }

  /// Set highlight duration for newly ready orders (in seconds)
  Future<void> setHighlightDurationSeconds(int seconds) async {
    _highlightDurationSeconds = seconds;
    await _prefs.setInt(_keyHighlightDurationSeconds, seconds);
    notifyListeners();
  }

  /// Set ready sound type
  Future<void> setReadySoundType(ReadySoundType type) async {
    _readySoundType = type;
    await _prefs.setString(_keyReadySoundType, type.name);
    notifyListeners();
  }

  /// Clear all settings (logout)
  Future<void> clearSettings() async {
    _displayId = null;
    _deviceName = null;
    _organizationId = null;
    _storeId = null;

    await _prefs.remove(_keyDisplayId);
    await _prefs.remove(_keyDeviceName);
    await _prefs.remove(_keyOrganizationId);
    await _prefs.remove(_keyStoreId);

    debugPrint('🗑️ [OSD SETTINGS] Settings cleared');
    notifyListeners();
  }
}

/// Primary display type for order cards
enum PrimaryDisplayType {
  callNumber,   // Customer pickup number (default)
  tableNumber,  // Table number for dine-in
  orderNumber,  // System order identifier
}

/// Ready sound type options
enum ReadySoundType {
  slick,        // Default notification sound (slick-notification)
  bell,         // Bell ring sound (ちりりりーん)
  quick,        // Quick notification sound (that-was-quick)
}

/// Get display name for sound type
extension ReadySoundTypeExtension on ReadySoundType {
  String get displayName {
    switch (this) {
      case ReadySoundType.slick:
        return 'Notification';
      case ReadySoundType.bell:
        return 'Bell';
      case ReadySoundType.quick:
        return 'Quick';
    }
  }

  String get assetPath {
    switch (this) {
      case ReadySoundType.slick:
        return 'sounds/order_ready.mp3';
      case ReadySoundType.bell:
        return 'sounds/bell.mp3';
      case ReadySoundType.quick:
        return 'sounds/notification.mp3';
    }
  }
}
