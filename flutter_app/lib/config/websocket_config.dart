/// WebSocket Configuration for OSD (Order Status Display)
///
/// Centralized configuration for custom WebSocket server connection
import 'shared_environment_config.dart';
import 'unified_websocket_config.dart';

class WebSocketConfig {
  // Connection Settings - using shared module
  static Duration get connectionTimeout =>
      UnifiedWebSocketConfig.connectionTimeout;
  static Duration get heartbeatInterval =>
      UnifiedWebSocketConfig.heartbeatInterval;
  static int get maxReconnectAttempts =>
      UnifiedWebSocketConfig.maxReconnectAttempts;
  static Duration get reconnectBaseDelay =>
      UnifiedWebSocketConfig.reconnectBaseDelay;

  // Get server URL based on environment - using shared module
  static String get serverUrl => UnifiedWebSocketConfig.serverUrl;

  // Debug mode detection
  static bool get isDebugMode {
    bool debugMode = false;
    assert(debugMode = true);
    return debugMode;
  }

  // Feature flags
  static const bool useCustomWebSocket = true; // Enable custom WebSocket
  static const bool useSupabaseRealtime = false; // Disable Supabase Realtime
  static const bool enableHeartbeat = true;
  static const bool enableAutoReconnect = true;
  static bool get enableDebugLogging =>
      SharedEnvironmentConfig.enableVerboseLogging;

  // Fallback configuration - using shared module
  static bool get useFallbackPolling =>
      UnifiedWebSocketConfig.useFallbackPolling;
  static Duration get fallbackPollingInterval =>
      UnifiedWebSocketConfig.fallbackPollingInterval;

  // Performance settings - using shared module
  static int get maxNotificationQueueSize =>
      UnifiedWebSocketConfig.maxNotificationQueueSize;
  static Duration get notificationProcessingDelay =>
      UnifiedWebSocketConfig.notificationProcessingDelay;

  // Security settings - using shared module
  static bool get validateServerCertificate =>
      UnifiedWebSocketConfig.validateServerCertificate;
  static List<String> get allowedOrigins =>
      UnifiedWebSocketConfig.allowedOrigins;

  // OSD-specific settings (using SDS device type for WebSocket compatibility)
  static const String deviceRole = 'sds_device'; // OSD uses sds_device type (similar read-only display)
  static const List<String> defaultPermissions = [
    'read_orders', // OSD only reads orders, no update permissions
  ];
  static const String issuer = 'osd-system';
  static const String audience = 'osd-devices';
}
