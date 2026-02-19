import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// API endpoint constants for the OSD (Order Status Display) Flutter app
///
/// This file defines all API endpoints used by the application,
/// ensuring consistency and making it easy to update endpoints.
///
/// OSD reuses the KDS API (`/api/kds/orders`) for order data retrieval.
/// No dedicated OSD API is needed.
class ApiEndpoints {
  // Base URLs for different environments
  static String get _devBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://pos.sciometa.com';
  static String get _stagingBaseUrl =>
      dotenv.env['API_STAGING_BASE_URL'] ?? 'https://staging.sciometa.com';
  static String get _prodBaseUrl =>
      dotenv.env['API_PROD_BASE_URL'] ?? 'https://pos.sciometa.com';

  /// Get the base URL based on the current environment
  static String get baseUrl {
    final environment = dotenv.env['FLUTTER_ENV'] ?? 'development';

    switch (environment.toLowerCase()) {
      case 'production':
        debugPrint('🌐 [OSD API] Base URL (production): $_prodBaseUrl');
        return _prodBaseUrl;
      case 'staging':
        debugPrint('🌐 [OSD API] Base URL (staging): $_stagingBaseUrl');
        return _stagingBaseUrl;
      case 'development':
      default:
        debugPrint('🌐 [OSD API] Base URL (development): $_devBaseUrl');
        return _devBaseUrl;
    }
  }

  // Authentication endpoints (relative paths - baseUrl is set in Dio)
  static const String signUp = '/api/auth/signup';
  static const String signIn = '/api/auth/login';
  static const String signInWithGoogleNative = '/api/auth/google-native';
  static const String signOut = '/api/auth/logout';
  static const String refreshToken = '/api/auth/refresh';
  static const String resetPassword = '/api/auth/reset-password';
  static const String profile = '/api/profile';

  // Display Preset endpoints (unified display configuration using display_category_presets)
  static const String displayPresets = '/api/display-category-presets';
  static String displayPresetById(String id) => '/api/display-category-presets/$id';

  // OSD Display endpoints
  static const String osdDisplays = '/api/display-category-presets';
  static String osdDisplayById(String id) => '/api/display-category-presets/$id';

  // OSD Order API - Reuses KDS orders endpoint (shared infrastructure)
  // OSD only reads orders, does not update them
  static const String osdOrders = '/api/kds/orders';

  // OSD Order History API - For recovery after reconnection
  static const String osdOrderHistory = '/api/kds/orders/history';

  // OSD Analytics API (read-only)
  static const String osdAnalytics = '/api/kds/analytics';

  // OSD Health Check API
  static const String osdHealth = '/api/kds/health';

  // OSD Dining Options API (for display styling)
  static const String osdDiningOptions = '/api/kds/dining-options';

  // OSD Header Colors API (for display styling)
  static const String osdSettingsColors = '/api/kds/settings/colors';

  // OSD Display Config API (uses display_category_presets table)
  static String osdDisplayConfig(String displayId) =>
      '/api/display-category-presets/$displayId';

  // Store endpoints
  static const String stores = '/api/stores';
  static String getStoreById(String id) => '/api/stores/$id';

  // Health check
  static const String health = '/api/health';

  /// Validate if a URL is a valid API endpoint
  static bool isValidEndpoint(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  /// Get timeout duration for different endpoint types
  static Duration getTimeout(String endpoint) {
    if (endpoint.contains('/analytics/') || endpoint.contains('/reports/')) {
      return const Duration(minutes: 2); // Longer timeout for reports
    }
    if (endpoint.contains('/upload/')) {
      return const Duration(minutes: 1); // Longer timeout for uploads
    }
    return const Duration(seconds: 30); // Default timeout
  }
}

/// HTTP headers commonly used across the app
class ApiHeaders {
  static const String contentType = 'Content-Type';
  static const String authorization = 'Authorization';
  static const String accept = 'Accept';
  static const String userAgent = 'User-Agent';
  static const String xRequestId = 'X-Request-ID';
  static const String xDeviceId = 'X-Device-ID';
  static const String xDisplayId = 'X-Display-ID';

  /// Default headers for all requests
  static Map<String, String> get defaultHeaders => {
        contentType: 'application/json',
        accept: 'application/json',
        userAgent: 'SciornetaOSD-Flutter/1.0.0',
      };

  /// Get authenticated headers with bearer token
  static Map<String, String> getAuthenticatedHeaders(String token) => {
        ...defaultHeaders,
        authorization: 'Bearer $token',
      };

  /// Get headers with device and display information
  static Map<String, String> getOsdHeaders(String deviceId, String displayId,
          [String? requestId]) =>
      {
        ...defaultHeaders,
        xDeviceId: deviceId,
        xDisplayId: displayId,
        if (requestId != null) xRequestId: requestId,
      };
}
