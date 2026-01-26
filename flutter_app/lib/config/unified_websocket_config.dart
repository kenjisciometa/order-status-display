/// Unified WebSocket Configuration Module
/// OSD (Order Status Display) WebSocket Connection Settings
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'shared_environment_config.dart';

class UnifiedWebSocketConfig {
  // Environment-specific URL settings
  static String get serverUrl {
    final env = SharedEnvironmentConfig.environment;
    debugPrint('🔍 [OSD-WEBSOCKET-CONFIG] Environment detected: $env');

    switch (env) {
      case 'production':
        final url = _getProductionUrl();
        debugPrint('🔍 [OSD-WEBSOCKET-CONFIG] Using production URL: $url');
        return url;
      case 'staging':
        final url = _getStagingUrl();
        debugPrint('🔍 [OSD-WEBSOCKET-CONFIG] Using staging URL: $url');
        return url;
      default:
        final url = _getDevelopmentUrl();
        debugPrint('🔍 [OSD-WEBSOCKET-CONFIG] Using development URL: $url');
        return url;
    }
  }

  // Production environment URL
  static String _getProductionUrl() {
    final envUrl = dotenv.env['WEBSOCKET_PRODUCTION_URL'];
    debugPrint(
        '🔍 [OSD-WEBSOCKET-CONFIG] dotenv WEBSOCKET_PRODUCTION_URL: $envUrl');
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    const systemUrl = String.fromEnvironment('WEBSOCKET_PRODUCTION_URL');
    debugPrint(
        '🔍 [OSD-WEBSOCKET-CONFIG] String.fromEnvironment WEBSOCKET_PRODUCTION_URL: $systemUrl');
    if (systemUrl.isNotEmpty) return systemUrl;

    debugPrint(
        '🔍 [OSD-WEBSOCKET-CONFIG] Using default production URL: wss://websocket.sciometa.com');
    return 'wss://websocket.sciometa.com';
  }

  // Staging environment URL
  static String _getStagingUrl() {
    const systemUrl = String.fromEnvironment('WEBSOCKET_STAGING_URL');
    if (systemUrl.isNotEmpty) return systemUrl;

    return 'wss://api-staging.yourdomain.com';
  }

  // Platform-compatible development URL
  static String _getDevelopmentUrl() {
    // First check dotenv settings
    final customUrl = dotenv.env['WEBSOCKET_DEV_URL'];
    if (customUrl != null && customUrl.isNotEmpty) return customUrl;

    // Also check build-time environment variables (fallback)
    const customUrlBuildTime = String.fromEnvironment('WEBSOCKET_DEV_URL',
        defaultValue: 'wss://dev.sciometa.com');
    if (customUrlBuildTime.isNotEmpty) return customUrlBuildTime;

    // Get port and IP address from dotenv
    final portFromEnv = dotenv.env['WEBSOCKET_PORT'] ?? '3005';
    final ipFromEnv = dotenv.env['DEV_SERVER_IP'];

    // Fallback from build-time environment variables
    const portFromBuild =
        String.fromEnvironment('WEBSOCKET_PORT', defaultValue: '3005');
    const ipFromBuild =
        String.fromEnvironment('DEV_SERVER_IP', defaultValue: 'localhost');

    // Determine final port and IP
    final port = portFromEnv.isNotEmpty ? portFromEnv : portFromBuild;
    final devServerIp =
        (ipFromEnv != null && ipFromEnv.isNotEmpty) ? ipFromEnv : ipFromBuild;

    // Default development environment settings
    if (kIsWeb) return 'http://localhost:$port';
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://$devServerIp:$port';
    }
    return 'http://localhost:$port';
  }

  // Environment-specific performance settings
  static Duration get connectionTimeout =>
      SharedEnvironmentConfig.connectionTimeout;

  static int get maxReconnectAttempts =>
      SharedEnvironmentConfig.maxReconnectAttempts;

  // WebSocket-specific settings
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const Duration reconnectBaseDelay = Duration(seconds: 2);

  // Protocol settings
  static String get protocol {
    if (SharedEnvironmentConfig.isProduction) return 'wss';
    return serverUrl.startsWith('https') ? 'wss' : 'ws';
  }

  // Security settings
  static const bool validateServerCertificate = true;

  static List<String> get allowedOrigins {
    if (SharedEnvironmentConfig.isDevelopment) {
      return [
        'localhost',
        '10.119.243.127',
        '10.15.10.168',
        'yourdomain.com',
        '*.yourdomain.com'
      ];
    }
    return ['yourdomain.com', '*.yourdomain.com'];
  }

  // Performance optimization settings
  static const int maxNotificationQueueSize = 100;
  static const Duration notificationProcessingDelay =
      Duration(milliseconds: 100);

  // Fallback settings
  static const bool useFallbackPolling = true;
  static const Duration fallbackPollingInterval = Duration(seconds: 5);
}
