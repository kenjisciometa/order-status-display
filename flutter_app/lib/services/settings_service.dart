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
  static const String _keyShowCallNumber = 'osd_show_call_number';
  static const String _keyShowTableNumber = 'osd_show_table_number';
  static const String _keyAutoRefreshInterval = 'osd_auto_refresh_interval';
  static const String _keyPlayReadySound = 'osd_play_ready_sound';
  static const String _keyPrimaryDisplayType = 'osd_primary_display_type';

  // Cached settings
  String? _displayId;
  String? _deviceName;
  String? _organizationId;
  String? _storeId;
  String _language = 'ja';
  bool _showCallNumber = true;
  bool _showTableNumber = true;
  int _autoRefreshInterval = 30; // seconds
  bool _playReadySound = true;
  PrimaryDisplayType _primaryDisplayType = PrimaryDisplayType.callNumber;

  // Getters
  String? get displayId => _displayId;
  String? get deviceName => _deviceName;
  String? get organizationId => _organizationId;
  String? get storeId => _storeId;
  String get language => _language;
  bool get showCallNumber => _showCallNumber;
  bool get showTableNumber => _showTableNumber;
  int get autoRefreshInterval => _autoRefreshInterval;
  bool get playReadySound => _playReadySound;
  PrimaryDisplayType get primaryDisplayType => _primaryDisplayType;
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
    _showCallNumber = _prefs.getBool(_keyShowCallNumber) ?? true;
    _showTableNumber = _prefs.getBool(_keyShowTableNumber) ?? true;
    _autoRefreshInterval = _prefs.getInt(_keyAutoRefreshInterval) ?? 30;
    _playReadySound = _prefs.getBool(_keyPlayReadySound) ?? true;
    final displayTypeStr = _prefs.getString(_keyPrimaryDisplayType);
    _primaryDisplayType = PrimaryDisplayType.values.firstWhere(
      (e) => e.name == displayTypeStr,
      orElse: () => PrimaryDisplayType.callNumber,
    );

    debugPrint('📝 [OSD SETTINGS] Loaded settings:');
    debugPrint('   Display ID: $_displayId');
    debugPrint('   Device Name: $_deviceName');
    debugPrint('   Store ID: $_storeId');
    debugPrint('   Language: $_language');
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

  /// Set show call number preference
  Future<void> setShowCallNumber(bool value) async {
    _showCallNumber = value;
    await _prefs.setBool(_keyShowCallNumber, value);
    notifyListeners();
  }

  /// Set show table number preference
  Future<void> setShowTableNumber(bool value) async {
    _showTableNumber = value;
    await _prefs.setBool(_keyShowTableNumber, value);
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
