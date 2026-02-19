import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/auth_state.dart';
import '../models/display_preset.dart';
import '../config/api_endpoints.dart';
import 'api_client_service.dart';
import 'settings_service.dart';
import 'google_auth_service.dart';

/// Key for storing the last selected display ID in SharedPreferences
const String _lastSelectedDisplayIdKey = 'last_selected_display_id';

/// Authentication service for OSD (Order Status Display)
/// Handles login, logout, session management, and display fetching
class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= AuthService._internal();
    return _instance!;
  }

  AuthService._internal();

  final ApiClientService _apiClient = ApiClientService.instance;

  AuthState _currentState = const AuthState.unknown();
  User? _currentUser;
  List<DisplayPreset> _availableDisplays = [];
  DisplayPreset? _selectedDisplay;

  /// Current authentication state
  AuthState get currentState => _currentState;

  /// Current authenticated user
  User? get currentUser => _currentUser;

  /// Available OSD displays for the user
  List<DisplayPreset> get availableDisplays => _availableDisplays;

  /// Selected OSD display
  DisplayPreset? get selectedDisplay => _selectedDisplay;

  void _updateState(AuthState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      notifyListeners();
    }
  }

  /// Initialize the auth service
  /// Check for stored credentials and auto-login if enabled
  Future<void> initialize() async {
    try {
      await _apiClient.initialize();

      // Check if auto-login is enabled
      final autoLoginEnabled = await _apiClient.isAutoLoginEnabled();
      if (!autoLoginEnabled) {
        debugPrint('🔐 [OSD AUTH] Auto-login disabled, showing login screen');
        _updateState(const AuthState.unauthenticated());
        return;
      }

      // Check for stored credentials
      final email = await _apiClient.getStoredEmail();
      final password = await _apiClient.getStoredPassword();

      if (email != null && password != null) {
        debugPrint(
            '🔐 [OSD AUTH] Found stored credentials, attempting auto-login');
        await signInWithEmailPassword(
            email: email, password: password, autoLogin: true);
      } else {
        // Check for existing token
        final token = await _apiClient.getAuthToken();
        if (token != null) {
          debugPrint('🔐 [OSD AUTH] Found stored token, validating...');
          final isValid = await _validateToken();
          if (isValid) {
            debugPrint('✅ [OSD AUTH] Token valid, session restored');
            return;
          }
        }
        _updateState(const AuthState.unauthenticated());
      }
    } catch (e) {
      debugPrint('❌ [OSD AUTH] Initialization error: $e');
      _updateState(const AuthState.unauthenticated());
    }
  }

  /// Validate stored token
  Future<bool> _validateToken() async {
    try {
      final response =
          await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.profile);

      if (response.success && response.data != null) {
        final userData = response.data!['user'] as Map<String, dynamic>?;
        if (userData != null) {
          _currentUser = User.fromJson(userData);
          _updateState(AuthState.authenticated(_currentUser!));
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ [OSD AUTH] Token validation error: $e');
      return false;
    }
  }

  /// Sign in with email and password
  Future<AuthState> signInWithEmailPassword({
    required String email,
    required String password,
    bool rememberMe = false,
    bool autoLogin = false,
  }) async {
    try {
      if (!autoLogin) {
        _updateState(const AuthState.loading());
      }

      debugPrint('🔐 [OSD AUTH] Attempting login with email: $email');

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.signIn,
        data: {
          'email': email,
          'password': password,
          'deviceId': _apiClient.deviceId ?? 'osd',
        },
      );

      debugPrint('🔐 [OSD AUTH] Login response success: ${response.success}');

      if (response.success && response.data != null) {
        final data = response.data!;

        // Extract session and user data
        final sessionData = data['session'] as Map<String, dynamic>?;
        final userProfileData = data['user'] as Map<String, dynamic>?;

        if (sessionData != null && userProfileData != null) {
          final accessToken = sessionData['access_token'] as String?;
          final refreshToken = sessionData['refresh_token'] as String?;

          if (accessToken != null) {
            // Store the API tokens
            await _apiClient.setAuthToken(accessToken, refreshToken);

            // Handle remember me / auto-login
            if (rememberMe && !autoLogin) {
              await _apiClient.setAutoLoginEnabled(true);
              await _apiClient.storeCredentials(email, password);
              debugPrint('💾 [OSD AUTH] Credentials stored for auto-login');
            }

            // Create user object
            _currentUser = User.fromJson(userProfileData);
            final authState = AuthState.authenticated(_currentUser!);
            _updateState(authState);

            debugPrint(
                '✅ [OSD AUTH] Login successful for user: ${_currentUser!.email}');
            return authState;
          }
        }
      }

      final serverError =
          response.data?['error'] ?? response.message ?? 'Authentication failed';
      debugPrint('❌ [OSD AUTH] Login failed: $serverError');

      // Check for rate limit error
      final isRateLimited = response.statusCode == 429 ||
          response.meta?['rate_limit_error'] == true ||
          serverError.toLowerCase().contains('rate limit');

      String errorMessage;
      if (isRateLimited) {
        final retryAfter = response.meta?['retry_after'] as int? ?? 60;
        errorMessage =
            'Too many login attempts. Please try again in $retryAfter seconds.';
      } else {
        // Security best practice: Don't reveal whether email or password was incorrect
        errorMessage =
            'Invalid email or password. Please check your credentials and try again.';
      }

      final authState = AuthState.unauthenticated(errorMessage);
      _updateState(authState);
      return authState;
    } catch (e) {
      debugPrint('❌ [OSD AUTH] Login exception: $e');

      // Check if exception message contains rate limit info
      final errorStr = e.toString().toLowerCase();
      String errorMessage;
      if (errorStr.contains('429') ||
          errorStr.contains('rate limit') ||
          errorStr.contains('too many')) {
        errorMessage = 'Too many login attempts. Please try again later.';
      } else {
        // Security best practice: Don't reveal whether email or password was incorrect
        errorMessage =
            'Invalid email or password. Please check your credentials and try again.';
      }

      final authState = AuthState.unauthenticated(errorMessage);
      _updateState(authState);
      return authState;
    }
  }

  /// Fetch available displays for the user
  /// Uses the unified display_category_presets API
  Future<List<DisplayPreset>> fetchOsdDisplays() async {
    try {
      if (_currentUser == null || _currentUser!.organizationId == null) {
        debugPrint('❌ [OSD AUTH] No user or organization ID available');
        return [];
      }

      debugPrint(
          '🔍 [OSD AUTH] Fetching displays for org: ${_currentUser!.organizationId}');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.displayPresets,
        queryParameters: {
          'organization_id': _currentUser!.organizationId,
          'active_only': 'true',
          'include_categories': 'true',
        },
      );

      if (response.success && response.data != null) {
        final displaysData = response.data!['presets'] as List<dynamic>?;

        if (displaysData != null) {
          _availableDisplays = displaysData
              .map((d) => DisplayPreset.fromJson(d as Map<String, dynamic>))
              .where((d) => d.active)
              .toList();

          debugPrint(
              '✅ [OSD AUTH] Found ${_availableDisplays.length} OSD displays');
          notifyListeners();
          return _availableDisplays;
        }
      }

      debugPrint('❌ [OSD AUTH] Failed to fetch OSD displays');
      return [];
    } catch (e) {
      debugPrint('❌ [OSD AUTH] Error fetching OSD displays: $e');
      return [];
    }
  }

  /// Select an OSD display and configure SettingsService
  Future<void> selectDisplay(DisplayPreset display) async {
    _selectedDisplay = display;
    debugPrint('✅ [OSD AUTH] Selected display: ${display.name} (${display.id})');

    // Save the selected display ID to SharedPreferences for auto-selection on next launch
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSelectedDisplayIdKey, display.id);
      debugPrint('💾 [OSD AUTH] Saved last selected display ID: ${display.id}');
    } catch (e) {
      debugPrint('⚠️ [OSD AUTH] Failed to save last selected display ID: $e');
    }

    // Configure SettingsService with the selected display info
    final settingsService = SettingsService.instance;
    final storeId = display.storeId ?? '';
    final organizationId = _currentUser?.organizationId ?? '';

    debugPrint('📝 [OSD AUTH] Configuring SettingsService:');
    debugPrint('   Display ID: ${display.id}');
    debugPrint('   Display Name: ${display.name}');
    debugPrint('   Store ID: $storeId');
    debugPrint('   Organization ID: $organizationId');

    await settingsService.setDeviceConfiguration(
      displayId: display.id,
      deviceName: display.name,
      organizationId: organizationId,
      storeId: storeId,
    );

    debugPrint('✅ [OSD AUTH] SettingsService configured successfully');
    notifyListeners();
  }

  /// Clear selected display
  void clearSelectedDisplay() {
    _selectedDisplay = null;
    notifyListeners();
  }

  /// Get the display to auto-select based on:
  /// 1. Previously selected display (from SharedPreferences)
  /// 2. Default display (if single store)
  /// Returns null if selection screen should be shown
  Future<DisplayPreset?> getAutoSelectDisplay(List<DisplayPreset> displays) async {
    if (displays.isEmpty) return null;

    // If only one display, always auto-select it
    if (displays.length == 1) {
      debugPrint('🎯 [OSD AUTH] Auto-select: Only one display available');
      return displays.first;
    }

    // Try to find previously selected display
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDisplayId = prefs.getString(_lastSelectedDisplayIdKey);

      if (lastDisplayId != null) {
        final remembered = displays.where((d) => d.id == lastDisplayId).firstOrNull;
        if (remembered != null && remembered.active) {
          debugPrint('🎯 [OSD AUTH] Auto-select: Using previously selected display: ${remembered.name}');
          return remembered;
        } else {
          debugPrint('ℹ️ [OSD AUTH] Previously selected display not found or inactive');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [OSD AUTH] Failed to read last selected display ID: $e');
    }

    // Check if all displays belong to the same store
    final uniqueStoreIds = displays.map((d) => d.storeId).toSet();

    if (uniqueStoreIds.length == 1) {
      // Single store: look for default display
      final defaultDisplay = displays.where((d) => d.isDefault).firstOrNull;
      if (defaultDisplay != null) {
        debugPrint('🎯 [OSD AUTH] Auto-select: Using default display for single store: ${defaultDisplay.name}');
        return defaultDisplay;
      }
    } else {
      debugPrint('ℹ️ [OSD AUTH] Multiple stores detected (${uniqueStoreIds.length}), showing selection screen');
    }

    // No auto-selection possible
    debugPrint('ℹ️ [OSD AUTH] No auto-select criteria met, showing selection screen');
    return null;
  }

  /// Clear the saved last selected display ID
  Future<void> clearLastSelectedDisplay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSelectedDisplayIdKey);
      debugPrint('🗑️ [OSD AUTH] Cleared last selected display ID');
    } catch (e) {
      debugPrint('⚠️ [OSD AUTH] Failed to clear last selected display ID: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      debugPrint('🔐 [OSD AUTH] Signing out...');

      // Clear all stored data
      await _apiClient.clearAllData();

      // Reset state
      _currentUser = null;
      _availableDisplays = [];
      _selectedDisplay = null;

      _updateState(const AuthState.unauthenticated());
      debugPrint('✅ [OSD AUTH] Sign out complete');
    } catch (e) {
      debugPrint('❌ [OSD AUTH] Sign out error: $e');
      _updateState(const AuthState.unauthenticated());
    }
  }

  /// Check if auto-login is enabled
  Future<bool> isAutoLoginEnabled() async {
    return await _apiClient.isAutoLoginEnabled();
  }

  /// Disable auto-login (but keep user logged in)
  Future<void> disableAutoLogin() async {
    await _apiClient.clearCredentials();
    debugPrint('🔐 [OSD AUTH] Auto-login disabled');
  }

  /// Check if Google Sign-In is supported on this platform
  bool get isGoogleSignInSupported => Platform.isAndroid;

  /// Sign in with Google (Android only)
  Future<AuthState> signInWithGoogle() async {
    try {
      if (!Platform.isAndroid) {
        debugPrint('⚠️ [OSD AUTH] Google Sign-In only supported on Android');
        final errorState = const AuthState.unauthenticated(
          'Google Sign-In is only available on Android devices.',
        );
        _updateState(errorState);
        return errorState;
      }

      _updateState(const AuthState.loading());
      debugPrint('🔐 [OSD AUTH] Starting Google sign-in flow');

      // 1) Execute native Google sign-in to obtain tokens
      final tokens = await GoogleAuthService.signInAndGetTokens();

      // User cancelled the Google sign-in dialog
      if (tokens == null) {
        debugPrint('⚠️ [OSD AUTH] Google sign-in cancelled by user');
        final cancelledState = const AuthState.unauthenticated(
          'Google sign-in was cancelled.',
        );
        _updateState(cancelledState);
        return cancelledState;
      }

      debugPrint('🔐 [OSD AUTH] Google tokens acquired - sending to backend');

      // 2) Send tokens to backend for Supabase session + profile creation
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.signInWithGoogleNative,
        data: {
          'id_token': tokens.idToken,
          'access_token': tokens.accessToken,
          if (tokens.email != null) 'email': tokens.email,
          'deviceId': _apiClient.deviceId ?? 'osd',
        },
      );

      debugPrint('🔐 [OSD AUTH] Google login response success: ${response.success}');

      if (response.success && response.data != null) {
        final data = response.data!;

        final sessionData = data['session'] as Map<String, dynamic>?;
        final userProfileData = data['user'] as Map<String, dynamic>?;

        if (sessionData != null && userProfileData != null) {
          final accessToken = sessionData['access_token'] as String?;
          final refreshToken = sessionData['refresh_token'] as String?;

          if (accessToken != null) {
            await _apiClient.setAuthToken(accessToken, refreshToken);

            // Create user object
            _currentUser = User.fromJson(userProfileData);
            final authState = AuthState.authenticated(_currentUser!);
            _updateState(authState);

            debugPrint(
                '✅ [OSD AUTH] Google login successful for user: ${_currentUser!.email}');
            return authState;
          }
        }
      }

      final serverError =
          response.data?['error'] ?? response.message ?? 'Google authentication failed';
      debugPrint('❌ [OSD AUTH] Google login failed: $serverError');

      final errorState = AuthState.unauthenticated(serverError);
      _updateState(errorState);
      return errorState;
    } catch (e) {
      debugPrint('❌ [OSD AUTH] Google login exception: $e');
      final errorState =
          AuthState.unauthenticated('Google sign-in failed: $e');
      _updateState(errorState);
      return errorState;
    }
  }
}
