import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:device_info_plus/device_info_plus.dart';
import 'websocket_token_service.dart';
import '../config/websocket_config.dart';
import '../models/osd_order.dart';

/// OSD WebSocket Service
///
/// Read-only WebSocket service for Order Status Display.
/// Listens for order events and updates the display accordingly.
///
/// Events handled:
/// - order_created: New order (add to "Now Cooking")
/// - order_ready_notification: Order ready (move to "It's Ready")
/// - order_served_notification: Order served (remove from display)
class OsdWebSocketService extends ChangeNotifier {
  static final OsdWebSocketService _instance = OsdWebSocketService._internal();
  factory OsdWebSocketService() => _instance;
  OsdWebSocketService._internal();

  static OsdWebSocketService get instance => _instance;

  // WebSocket connection
  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentDeviceId;
  String? _currentStoreId;
  String? _currentOrganizationId;
  String? _currentDisplayId;

  // Reconnection handling
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _authTimeoutTimer;
  Timer? _connectionTimeoutTimer;
  DateTime? _connectionAttemptStarted;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 30;
  bool _isReconnecting = false;
  bool _isAuthenticating = false;

  // Connection recovery
  bool _wasDisconnected = false;
  DateTime? _lastDisconnectedAt;
  DateTime? _lastConnectedAt;
  bool _isRefreshing = false;

  // Configuration
  final String _serverUrl = WebSocketConfig.serverUrl;
  final Duration _heartbeatInterval = const Duration(seconds: 15);
  final Duration _reconnectBaseDelay = const Duration(seconds: 3);

  // Event callbacks for OSD
  Function(OsdOrder)? onNewOrder; // order_created → "Now Cooking"
  Function(String orderId)? onOrderReady; // order_ready → "It's Ready"
  Function(String orderId)? onOrderServed; // order_served → Remove from display
  Function(String)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  Function()? onDataRefreshRequested; // Recovery callback

  // Statistics
  int _notificationsReceived = 0;
  DateTime? _connectedAt;
  String? _deviceMacAddress;

  // Getters
  bool get isConnected => _isConnected;
  String? get currentDeviceId => _currentDeviceId;
  String? get currentStoreId => _currentStoreId;
  String get serverUrl => _serverUrl;
  int get notificationsReceived => _notificationsReceived;
  DateTime? get connectedAt => _connectedAt;
  bool get wasDisconnected => _wasDisconnected;

  /// Get stable device identifier
  Future<String> _getDeviceMacAddress() async {
    if (_deviceMacAddress != null) {
      return _deviceMacAddress!;
    }

    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        _deviceMacAddress = androidInfo.id;
        debugPrint(
            'OSD: Android device ID obtained: ${_deviceMacAddress!.substring(0, 8)}...');
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        _deviceMacAddress = iosInfo.identifierForVendor ??
            'ios_unknown_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint(
            'OSD: iOS identifierForVendor obtained: ${_deviceMacAddress!.substring(0, 8)}...');
      } else {
        _deviceMacAddress =
            'platform_unknown_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint(
            'OSD: Platform fallback identifier: ${_deviceMacAddress!.substring(0, 8)}...');
      }
    } catch (e) {
      debugPrint('OSD: Failed to get stable device identifier: $e');
      _deviceMacAddress =
          'error_fallback_${DateTime.now().millisecondsSinceEpoch}';
    }

    return _deviceMacAddress!;
  }

  /// Connect to WebSocket server
  Future<void> connect(
    String storeId,
    String? token, {
    String? deviceId,
    String? displayId,
    String? organizationId,
    bool forceTokenRefresh = false,
  }) async {
    if (WebSocketConfig.enableDebugLogging) {
      debugPrint('OSD: Connecting to WebSocket server');
      debugPrint('Connect parameters: storeId=$storeId, deviceId=$deviceId');
    }

    if (_isConnected && _currentStoreId == storeId) {
      if (WebSocketConfig.enableDebugLogging) {
        debugPrint('Already connected to store $storeId');
      }
      Future.microtask(() => onConnected?.call());
      return;
    }

    await disconnect();

    try {
      debugPrint('OSD: Connecting to WebSocket server: $_serverUrl');
      debugPrint('Store ID: $storeId, Device ID: ${deviceId ?? 'auto-generated'}');

      // Store connection parameters
      _currentStoreId = storeId;
      _currentOrganizationId = organizationId;
      _currentDeviceId =
          deviceId ?? 'osd_device_${DateTime.now().millisecondsSinceEpoch}';
      _currentDisplayId = displayId;

      // Get JWT token from server
      String? jwtToken;
      if (organizationId != null) {
        final wsTokenService = WebSocketTokenService.instance;
        await wsTokenService.initialize();
        jwtToken = await wsTokenService.getToken(
          storeId: storeId,
          deviceId: _currentDeviceId!,
          organizationId: organizationId,
          displayId: displayId,
          forceRefresh: forceTokenRefresh,
        );
      }

      if (jwtToken == null) {
        debugPrint('❌ OSD: Failed to obtain WebSocket token');
        onError?.call('Failed to obtain authentication token');
        return;
      }

      debugPrint('✅ OSD: Obtained JWT token from server');

      // Get stable device identifier
      final deviceMac = await _getDeviceMacAddress();

      // Create Socket.IO connection
      _socket = IO.io(
          _serverUrl,
          IO.OptionBuilder()
              .setTransports(['websocket', 'polling'])
              .setReconnectionAttempts(0)
              .setTimeout(20000)
              .enableForceNew()
              .enableAutoConnect()
              .setReconnectionDelay(3000)
              .setReconnectionDelayMax(10000)
              .setAuth({'token': jwtToken})
              .setExtraHeaders({
                'x-device-id': deviceMac,
                'x-device-type': 'sds_device', // Use sds_device type (OSD is similar to SDS)
              })
              .build());

      // Setup event handlers
      _setupSocketHandlers(jwtToken, deviceMac);

      // Record connection attempt start time
      _connectionAttemptStarted = DateTime.now();

      // Initiate connection
      _socket!.connect();

      // Set up connection timeout
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!_isConnected) {
          debugPrint('❌ [OSD-CONNECTION-TIMEOUT] Connection timeout');
          onError?.call('Connection timeout to WebSocket server');
          _forceWebSocketReset(storeId,
              deviceId: deviceId, organizationId: organizationId);
        }
      });
    } catch (error) {
      debugPrint('OSD: WebSocket connection failed: $error');
      onError?.call('Connection failed: $error');
      _scheduleReconnect(storeId,
          deviceId: deviceId,
          displayId: displayId,
          organizationId: organizationId);
    }
  }

  /// Setup WebSocket event handlers
  void _setupSocketHandlers(String jwtToken, String deviceMac) {
    if (_socket == null) return;

    // Connection established
    _socket!.on('connect', (_) {
      debugPrint('OSD: WebSocket connected');
      _sendAuthenticationData(jwtToken, deviceMac);
      _startAuthenticationTimeout();
    });

    // Authentication successful
    _socket!.on('authenticated', (data) {
      _authTimeoutTimer?.cancel();
      _connectionTimeoutTimer?.cancel();
      _isAuthenticating = false;

      debugPrint('✅ OSD: WebSocket authenticated successfully');
      _isConnected = true;
      _connectedAt = DateTime.now();
      _lastConnectedAt = DateTime.now();
      _reconnectAttempts = 0;
      _isReconnecting = false;

      _startHeartbeat();

      // Recovery: fetch latest data after reconnection
      if (_wasDisconnected && !_isRefreshing) {
        final disconnectDuration = _lastDisconnectedAt != null
            ? DateTime.now().difference(_lastDisconnectedAt!).inSeconds
            : 0;
        debugPrint(
            '📥 [OSD-AUTHENTICATED] Reconnected (disconnect: ${disconnectDuration}s) → Refreshing data');
        _triggerDataRefresh();
      }

      onConnected?.call();
      notifyListeners();
    });

    // Authentication failed
    _socket!.on('authentication_failed', (data) {
      debugPrint('❌ OSD: WebSocket authentication failed');
      WebSocketTokenService.instance.clearToken();
      disconnect();
      _scheduleReconnect(_currentStoreId!,
          deviceId: _currentDeviceId, organizationId: _currentOrganizationId);
    });

    // Disconnected
    _socket!.on('disconnect', (reason) {
      _isConnected = false;
      _connectedAt = null;
      _stopHeartbeat();

      _wasDisconnected = true;
      _lastDisconnectedAt = DateTime.now();

      debugPrint('🔌 [OSD-DISCONNECT] WebSocket disconnected: $reason');
      onDisconnected?.call();
      notifyListeners();

      // Auto-reconnect
      if (reason == 'transport error' ||
          reason == 'transport close' ||
          reason == 'ping timeout' ||
          reason == 'io server disconnect') {
        _scheduleReconnect(_currentStoreId!,
            deviceId: _currentDeviceId,
            displayId: _currentDisplayId,
            organizationId: _currentOrganizationId);
      }
    });

    // Connection error
    _socket!.on('connect_error', (error) {
      debugPrint('OSD: WebSocket connection error: $error');
      if (!_isReconnecting) {
        onError?.call('WebSocket connection error');
      }
      _scheduleReconnect(_currentStoreId!,
          deviceId: _currentDeviceId,
          displayId: _currentDisplayId,
          organizationId: _currentOrganizationId);
    });

    // Heartbeat response
    _socket!.on('heartbeat_ack', (data) {
      if (_wasDisconnected && !_isRefreshing) {
        debugPrint('📥 [OSD-HEARTBEAT-ACK] Connection recovered → Refreshing data');
        _triggerDataRefresh();
        _wasDisconnected = false;
      }
    });

    // ========================================
    // OSD-specific event handlers
    // ========================================

    // NEW ORDER: order_created → Add to "Now Cooking"
    _socket!.on('order_created', (data) {
      debugPrint('🆕 [OSD←BOS] New order received via order_created');
      debugPrint('   📱 Data: $data');

      try {
        if (data is Map<String, dynamic>) {
          final orderData =
              data['orderData'] as Map<String, dynamic>? ?? data;
          final osdOrder = OsdOrder.fromWebSocketEvent(orderData);

          debugPrint('   📦 Order ID: ${osdOrder.id}');
          debugPrint('   📞 Call Number: ${osdOrder.callNumber}');

          _notificationsReceived++;
          onNewOrder?.call(osdOrder);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('❌ OSD: Error processing order_created: $e');
      }
    });

    // ORDER READY: order_ready_notification → Move to "It's Ready"
    _socket!.on('order_ready_notification', (data) {
      debugPrint('✅ [OSD←KDS] Order ready notification received');
      debugPrint('   📱 Data: $data');

      try {
        if (data is Map<String, dynamic>) {
          final orderId = (data['orderId'] ?? data['order_id']) as String?;

          if (orderId != null) {
            debugPrint('   📦 Order ID: $orderId → Moving to "It\'s Ready"');
            _notificationsReceived++;
            onOrderReady?.call(orderId);
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('❌ OSD: Error processing order_ready_notification: $e');
      }
    });

    // ORDER SERVED: order_served_notification → Remove from display
    _socket!.on('order_served_notification', (data) {
      debugPrint('🍽️ [OSD←SDS] Order served notification received');
      debugPrint('   📱 Data: $data');

      try {
        if (data is Map<String, dynamic>) {
          final orderId = (data['orderId'] ?? data['order_id']) as String?;

          if (orderId != null) {
            debugPrint('   📦 Order ID: $orderId → Removing from display');
            _notificationsReceived++;
            onOrderServed?.call(orderId);
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('❌ OSD: Error processing order_served_notification: $e');
      }
    });

    // Generic error handler
    _socket!.on('error', (error) {
      debugPrint('OSD WebSocket: Socket error: $error');
      onError?.call('Socket error: $error');
    });
  }

  /// Send authentication data
  void _sendAuthenticationData(String jwtToken, String deviceMac) {
    if (_socket?.connected != true || _isAuthenticating) return;

    try {
      final authData = {
        'deviceId': _currentDeviceId,
        'storeId': _currentStoreId,
        'organizationId': _currentOrganizationId,
        'displayId': _currentDisplayId,
        'token': jwtToken,
        'type': 'sds_device', // Use sds_device type (OSD is similar to SDS - read-only display)
        'stableDeviceId': deviceMac,
      };

      debugPrint('🔐 OSD: Sending authentication data');
      _socket!.emit('authenticate', authData);
    } catch (e) {
      debugPrint('❌ OSD: Failed to send authentication data: $e');
    }
  }

  /// Start authentication timeout
  void _startAuthenticationTimeout() {
    if (_isAuthenticating) return;

    _isAuthenticating = true;
    _authTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!_isConnected && _isAuthenticating) {
        debugPrint('❌ OSD: Authentication timeout');
        _isAuthenticating = false;
        onError?.call('Authentication timeout');
        disconnect();
        _scheduleReconnect(_currentStoreId!,
            deviceId: _currentDeviceId, organizationId: _currentOrganizationId);
      }
    });
  }

  /// Start heartbeat
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_isConnected && _socket != null) {
        _socket!.emit('heartbeat', {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'device_id': _currentDeviceId,
          'store_id': _currentStoreId,
          'type': 'osd_heartbeat'
        });
      }
    });
  }

  /// Stop heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Schedule reconnection
  void _scheduleReconnect(
    String storeId, {
    String? deviceId,
    String? displayId,
    String? organizationId,
    bool forceTokenRefresh = false,
  }) {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('OSD: Maximum reconnection attempts reached');
      onError?.call('Maximum reconnection attempts reached');
      _isReconnecting = false;
      return;
    }

    final delay = Duration(
        seconds:
            (_reconnectBaseDelay.inSeconds * (1 << _reconnectAttempts)).clamp(2, 30));

    _reconnectAttempts++;
    _isReconnecting = true;

    debugPrint(
        'OSD: Scheduling reconnection in ${delay.inSeconds}s (attempt $_reconnectAttempts/$maxReconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      connect(storeId, null,
          deviceId: deviceId,
          displayId: displayId,
          organizationId: organizationId,
          forceTokenRefresh: forceTokenRefresh);
    });
  }

  /// Force WebSocket reset
  Future<void> _forceWebSocketReset(
    String storeId, {
    String? deviceId,
    String? organizationId,
  }) async {
    debugPrint('💥 [OSD-FORCE-RESET] Forcing WebSocket reset');

    _heartbeatTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _authTimeoutTimer?.cancel();

    if (_socket != null) {
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (e) {
        debugPrint('⚠️ [OSD-FORCE-RESET] Socket disposal error: $e');
      }
      _socket = null;
    }

    _isConnected = false;
    _isReconnecting = false;
    _isAuthenticating = false;
    _connectedAt = null;

    await Future.delayed(const Duration(milliseconds: 500));
    await connect(storeId, null,
        deviceId: deviceId, organizationId: organizationId);
  }

  /// Trigger data refresh (recovery)
  void _triggerDataRefresh() {
    if (_isRefreshing) return;

    _isRefreshing = true;
    debugPrint('🔄 [OSD-DATA-REFRESH] Triggering data refresh');

    onDataRefreshRequested?.call();

    Future.delayed(const Duration(seconds: 1), () {
      _isRefreshing = false;
    });
  }

  /// Disconnect
  Future<void> disconnect() async {
    debugPrint('OSD: Disconnecting from WebSocket server');

    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _authTimeoutTimer?.cancel();
    _connectionTimeoutTimer?.cancel();

    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    _isConnected = false;
    _isReconnecting = false;
    _isAuthenticating = false;
    _currentStoreId = null;
    _currentOrganizationId = null;
    _currentDeviceId = null;
    _currentDisplayId = null;
    _connectedAt = null;
    _reconnectAttempts = 0;

    notifyListeners();
  }

  /// Get connection diagnostics
  Map<String, dynamic> getDiagnostics() {
    final uptime = _connectedAt != null
        ? DateTime.now().difference(_connectedAt!).inSeconds
        : null;

    return {
      'service_type': 'osd_websocket',
      'server_url': _serverUrl,
      'is_connected': _isConnected,
      'store_id': _currentStoreId,
      'device_id': _currentDeviceId,
      'organization_id': _currentOrganizationId,
      'connected_at': _connectedAt?.toIso8601String(),
      'uptime_seconds': uptime,
      'notifications_received': _notificationsReceived,
      'reconnect_attempts': _reconnectAttempts,
      'was_disconnected': _wasDisconnected,
      'features': [
        'order_created',
        'order_ready_notification',
        'order_served_notification',
        'automatic_reconnection',
        'heartbeat_monitoring',
      ],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
