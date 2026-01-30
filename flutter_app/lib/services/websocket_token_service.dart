import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client_service.dart';

/// WebSocket Token Service for OSD
///
/// This service manages WebSocket authentication tokens obtained from the backend.
/// Tokens are retrieved via the restaurant-pos API and stored securely on device.
/// The JWT_SECRET is never exposed to the client - all token generation happens server-side.
class WebSocketTokenService {
  static const String _tokenKey = 'osd_websocket_token';
  static const String _tokenExpiryKey = 'osd_websocket_token_expiry';

  // Refresh token when it has less than 7 days until expiry
  static const int _refreshThresholdDays = 7;

  SharedPreferences? _prefs;
  final ApiClientService _apiClient;

  // Cached token data
  String? _cachedToken;
  DateTime? _cachedExpiry;

  /// Singleton instance
  static WebSocketTokenService? _instance;
  static WebSocketTokenService get instance {
    _instance ??= WebSocketTokenService._internal();
    return _instance!;
  }

  WebSocketTokenService._internal() : _apiClient = ApiClientService.instance;

  /// Get SharedPreferences instance (lazy initialization)
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Initialize and load cached token
  Future<void> initialize() async {
    await _loadCachedToken();
    if (kDebugMode) {
      debugPrint('🔐 [OSD WS Token] Service initialized');
    }
  }

  /// Load cached token from storage
  Future<void> _loadCachedToken() async {
    try {
      final prefs = await _getPrefs();
      _cachedToken = prefs.getString(_tokenKey);
      final expiryStr = prefs.getString(_tokenExpiryKey);

      if (expiryStr != null) {
        _cachedExpiry = DateTime.tryParse(expiryStr);
      }

      if (_cachedToken != null && _cachedExpiry != null) {
        if (kDebugMode) {
          debugPrint(
              '🔐 [OSD WS Token] Loaded cached token, expires: $_cachedExpiry');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [OSD WS Token] Failed to load cached token: $e');
      }
    }
  }

  /// Save token to storage
  Future<void> _saveToken(String token, DateTime expiry) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
      _cachedToken = token;
      _cachedExpiry = expiry;
      if (kDebugMode) {
        debugPrint('💾 [OSD WS Token] Token saved, expires: $expiry');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [OSD WS Token] Failed to save token: $e');
      }
    }
  }

  /// Clear stored token
  Future<void> clearToken() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_tokenKey);
      await prefs.remove(_tokenExpiryKey);
      _cachedToken = null;
      _cachedExpiry = null;
      if (kDebugMode) {
        debugPrint('🗑️ [OSD WS Token] Token cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [OSD WS Token] Failed to clear token: $e');
      }
    }
  }

  /// Check if token needs refresh
  bool _needsRefresh() {
    if (_cachedToken == null || _cachedExpiry == null) {
      return true;
    }

    final now = DateTime.now();
    final threshold =
        _cachedExpiry!.subtract(Duration(days: _refreshThresholdDays));

    return now.isAfter(threshold);
  }

  /// Check if token is expired
  bool _isExpired() {
    if (_cachedToken == null || _cachedExpiry == null) {
      return true;
    }
    return DateTime.now().isAfter(_cachedExpiry!);
  }

  /// Get WebSocket token for connection
  ///
  /// Returns a valid token, fetching a new one from the server if needed.
  /// Returns null if authentication fails.
  Future<String?> getToken({
    required String storeId,
    required String deviceId,
    required String organizationId,
    String? displayId,
    bool forceRefresh = false,
  }) async {
    // Return cached token if valid and not forcing refresh
    if (!forceRefresh && !_needsRefresh() && _cachedToken != null) {
      if (kDebugMode) {
        debugPrint(
            '🔐 [OSD WS Token] Using cached token (expires: $_cachedExpiry)');
      }
      return _cachedToken;
    }

    // Fetch new token from server
    if (kDebugMode) {
      debugPrint('🔄 [OSD WS Token] Fetching new token from server...');
    }
    return await _fetchNewToken(storeId, deviceId, organizationId, displayId);
  }

  /// Fetch new token from restaurant-pos backend
  Future<String?> _fetchNewToken(
    String storeId,
    String deviceId,
    String organizationId,
    String? displayId,
  ) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/websocket/token',
        data: {
          'storeId': storeId,
          'deviceId': deviceId,
          'organizationId': organizationId,
          'deviceType': 'sds_device', // Use sds_device type (OSD is similar to SDS - read-only display)
          if (displayId != null) 'displayId': displayId,
        },
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final token = data['token'] as String?;
        final expiresAtStr = data['expiresAt'] as String?;

        if (token != null && expiresAtStr != null) {
          final expiry = DateTime.parse(expiresAtStr);
          await _saveToken(token, expiry);

          if (kDebugMode) {
            debugPrint(
                '✅ [OSD WS Token] New token obtained, expires: $expiry');
          }
          return token;
        }
      }

      if (kDebugMode) {
        debugPrint(
            '❌ [OSD WS Token] Failed to get token: ${response.message}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [OSD WS Token] Error fetching token: $e');
      }

      // If network error but we have a non-expired cached token, use it
      if (!_isExpired() && _cachedToken != null) {
        if (kDebugMode) {
          debugPrint('⚠️ [OSD WS Token] Network error, using cached token');
        }
        return _cachedToken;
      }

      return null;
    }
  }

  /// Refresh token if needed (call periodically)
  Future<bool> refreshIfNeeded({
    required String storeId,
    required String deviceId,
    required String organizationId,
    String? displayId,
  }) async {
    if (!_needsRefresh()) {
      return true; // Token is still valid
    }

    final token =
        await _fetchNewToken(storeId, deviceId, organizationId, displayId);
    return token != null;
  }

  /// Decode token to get payload (for debugging)
  Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      // Add padding if necessary
      final normalizedPayload =
          payload.padRight((payload.length + 3) ~/ 4 * 4, '=');

      final decodedBytes = base64Url.decode(normalizedPayload);
      final decodedString = utf8.decode(decodedBytes);

      return jsonDecode(decodedString) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [OSD WS Token] Failed to decode token: $e');
      }
      return null;
    }
  }

  /// Get token expiration time
  DateTime? getTokenExpiration() {
    return _cachedExpiry;
  }

  /// Check if we have a valid (non-expired) token
  bool hasValidToken() {
    return _cachedToken != null && !_isExpired();
  }
}
