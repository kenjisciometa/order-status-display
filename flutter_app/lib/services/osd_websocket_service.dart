import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  Timer? _tokenRefreshTimer;  // Token auto-refresh timer
  DateTime? _connectionAttemptStarted;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 30;
  bool _isReconnecting = false;
  bool _isAuthenticating = false;
  int _reAuthFailureCount = 0;  // Re-authentication failure counter
  static const int _maxReAuthFailures = 3;  // Max re-auth failures before reconnect
  static const Duration _tokenRefreshInterval = Duration(hours: 6);  // Token refresh interval

  // 案2: ネットワーク状態監視
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasNetworkConnection = true;
  bool _isInitialConnection = true; // 案1: 起動時リトライ用フラグ

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
  Function(String orderId, String targetStatus)? onOrderRestored; // order_restored → Move based on targetStatus
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

  /// 案1: 起動時の接続リトライ強化
  /// アプリ起動時に即座に接続を試みるのではなく、初期接続専用のリトライロジックを実行
  Future<void> connectWithInitialRetry(
    String storeId,
    String? token, {
    String? deviceId,
    String? displayId,
    String? organizationId,
    int maxAttempts = 5,
    Duration baseDelay = const Duration(seconds: 2),
  }) async {
    debugPrint('🚀 [OSD-INITIAL-CONNECT] Starting connection with initial retry (max $maxAttempts attempts)');

    // ネットワーク監視を開始
    _startNetworkMonitoring();

    _isInitialConnection = true;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint('🔄 [OSD-INITIAL-CONNECT] Attempt $attempt/$maxAttempts');

      // ネットワーク接続を確認
      if (!_hasNetworkConnection) {
        debugPrint('⚠️ [OSD-INITIAL-CONNECT] No network connection, waiting...');
        await Future.delayed(baseDelay);
        continue;
      }

      try {
        await connect(
          storeId,
          token,
          deviceId: deviceId,
          displayId: displayId,
          organizationId: organizationId,
        );

        // 接続成功を少し待って確認
        await Future.delayed(const Duration(seconds: 2));

        if (_isConnected) {
          debugPrint('✅ [OSD-INITIAL-CONNECT] Connection succeeded on attempt $attempt');
          _isInitialConnection = false;
          return;
        }
      } catch (e) {
        debugPrint('⚠️ [OSD-INITIAL-CONNECT] Attempt $attempt failed: $e');
      }

      if (attempt < maxAttempts) {
        // 段階的に待機時間を増加（2秒、4秒、6秒...）
        final delay = baseDelay * attempt;
        debugPrint('⏳ [OSD-INITIAL-CONNECT] Waiting ${delay.inSeconds}s before next attempt...');
        await Future.delayed(delay);
      }
    }

    _isInitialConnection = false;
    debugPrint('⚠️ [OSD-INITIAL-CONNECT] All initial attempts exhausted, falling back to normal reconnection logic');

    // 全試行失敗後は通常の再接続ロジックに委ねる
    if (!_isConnected && !_isReconnecting) {
      _scheduleReconnect(
        storeId,
        deviceId: deviceId,
        displayId: displayId,
        organizationId: organizationId,
      );
    }
  }

  /// 案2: ネットワーク状態監視を開始
  void _startNetworkMonitoring() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hadConnection = _hasNetworkConnection;
      _hasNetworkConnection = results.any((r) => r != ConnectivityResult.none);

      debugPrint('📶 [OSD-NETWORK] Connectivity changed: $results (hasConnection: $_hasNetworkConnection)');

      if (_hasNetworkConnection && !hadConnection) {
        // ネットワーク復帰
        debugPrint('📶 [OSD-NETWORK] Network restored');

        if (!_isConnected && !_isReconnecting && !_isInitialConnection) {
          debugPrint('📶 [OSD-NETWORK] Attempting immediate reconnection...');
          _reconnectAttempts = 0; // リトライカウントをリセット

          if (_currentStoreId != null) {
            connect(
              _currentStoreId!,
              null,
              deviceId: _currentDeviceId,
              displayId: _currentDisplayId,
              organizationId: _currentOrganizationId,
            );
          }
        }
      } else if (!_hasNetworkConnection && hadConnection) {
        // ネットワーク喪失
        debugPrint('📵 [OSD-NETWORK] Network lost, pausing reconnection attempts');
        _reconnectTimer?.cancel();
      }
    });

    // 初期状態を確認
    Connectivity().checkConnectivity().then((results) {
      _hasNetworkConnection = results.any((r) => r != ConnectivityResult.none);
      debugPrint('📶 [OSD-NETWORK] Initial connectivity: $results (hasConnection: $_hasNetworkConnection)');
    });
  }

  /// ネットワーク監視を停止
  void _stopNetworkMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
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
          deviceId ?? 'osd_${DateTime.now().millisecondsSinceEpoch}';
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
      // 案5: Socket.IOオプション最適化 - 内蔵の再接続も有効にしてバックアップとする
      _socket = IO.io(
          _serverUrl,
          IO.OptionBuilder()
              .setTransports(['websocket', 'polling'])
              .setReconnectionAttempts(3) // Socket.IOの短期的な自動再接続を有効化（バックアップ）
              .setTimeout(20000)
              .enableForceNew() // 古い接続の影響を排除
              .enableAutoConnect()
              .enableReconnection() // 再接続機能を有効化
              .setReconnectionDelay(1000) // 1秒から開始（より素早い再接続）
              .setReconnectionDelayMax(5000) // 最大5秒（カスタム再接続との併用のため短め）
              .setAuth({'token': jwtToken})
              .setExtraHeaders({
                'x-device-id': deviceMac,
                'x-device-type': 'osd',
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
      _reAuthFailureCount = 0; // Reset re-auth failure count on successful authentication

      _startHeartbeat();
      _startTokenRefreshTimer(); // Start token refresh timer

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

    // Re-authentication successful (token refresh)
    _socket!.on('re-authenticated', (data) {
      _reAuthFailureCount = 0; // Reset re-auth failure counter
      debugPrint('🔄 OSD: Token re-authenticated successfully');
      if (WebSocketConfig.enableDebugLogging) {
        debugPrint('   expiresAt: ${data['expiresAt']}');
      }
    });

    // Re-authentication failed
    _socket!.on('re-authentication_failed', (data) {
      _reAuthFailureCount++;
      debugPrint('🔴 OSD: Re-authentication failed (attempt $_reAuthFailureCount/$_maxReAuthFailures)');
      debugPrint('   Reason: ${data['reason'] ?? 'Unknown'}');

      if (_reAuthFailureCount >= _maxReAuthFailures) {
        debugPrint('❌ OSD: Maximum re-authentication failures reached. Forcing reconnection.');
        // Clear token and force reconnect with fresh token
        WebSocketTokenService.instance.clearToken();
        disconnect();
        if (_currentStoreId != null) {
          _scheduleReconnect(
            _currentStoreId!,
            deviceId: _currentDeviceId,
            displayId: _currentDisplayId,
            organizationId: _currentOrganizationId,
            forceTokenRefresh: true,
          );
        }
      }
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
      debugPrint('🆕 [OSD←POS] New order received via order_created');
      debugPrint('   📱 Raw data type: ${data.runtimeType}');
      debugPrint('   📱 Raw data keys: ${data is Map<String, dynamic> ? data.keys.toList() : 'N/A'}');

      try {
        if (data is Map<String, dynamic>) {
          // Send ACK if required (Reliable Messaging)
          _sendMessageAck(data);

          // Extract orderData from nested structure (same as KDS/SDS)
          final orderData = data['orderData'] as Map<String, dynamic>? ?? data;
          debugPrint('   📦 Extracted orderData keys: ${orderData.keys.toList()}');
          debugPrint('   📦 Order ID: ${orderData['orderId'] ?? orderData['id'] ?? 'N/A'}');
          debugPrint('   📦 Order Number: ${orderData['orderNumber'] ?? orderData['order_number'] ?? 'N/A'}');

          // Try to parse OsdOrder, but don't fail if parsing fails
          // OSD will fetch from DB anyway, so we just need to trigger the callback
          OsdOrder? osdOrder;
          try {
            osdOrder = OsdOrder.fromWebSocketEvent(orderData);
            debugPrint('   ✅ Parsed OsdOrder: ID=${osdOrder.id}, CallNumber=${osdOrder.callNumber}');
          } catch (parseError, parseStackTrace) {
            debugPrint('   ⚠️ OSD: Failed to parse OsdOrder from WebSocket data: $parseError');
            debugPrint('   ⚠️ OSD: This is OK - will fetch from DB instead');
            debugPrint('   ⚠️ OSD: Parse stack trace: $parseStackTrace');

            // Create a minimal OsdOrder with just the ID to trigger DB fetch
            // This ensures _loadOrders() is called even if parsing fails
            final orderId = orderData['orderId'] ?? orderData['order_id'] ?? orderData['id']?.toString() ?? 'unknown';

            // Helper to parse int from dynamic value
            int? parseIntOrNull(dynamic value) {
              if (value == null) return null;
              if (value is int) return value;
              if (value is String) return int.tryParse(value);
              return null;
            }

            osdOrder = OsdOrder(
              id: orderId,
              callNumber: parseIntOrNull(orderData['callNumber'] ?? orderData['call_number']),
              tableNumber: parseIntOrNull(orderData['tableNumber'] ?? orderData['table_number']),
              orderNumber: orderData['orderNumber']?.toString() ?? orderData['order_number']?.toString(),
              diningOption: orderData['diningOption']?.toString() ?? orderData['dining_option']?.toString(),
              displayStatus: 'pending', // Default to pending - DB fetch will get correct status
              createdAt: DateTime.now(),
            );
            debugPrint('   ✅ Created minimal OsdOrder for DB fetch trigger: ID=$orderId');
          }

          if (osdOrder != null) {
            _notificationsReceived++;
            onNewOrder?.call(osdOrder);
            notifyListeners();
            debugPrint('   ✅ onNewOrder callback executed successfully');
          } else {
            debugPrint('   ⚠️ OSD: osdOrder is null, skipping callback');
          }
        } else {
          debugPrint('   ❌ OSD: Invalid data format: ${data.runtimeType}');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ OSD: Error processing order_created: $e');
        debugPrint('   Stack trace: $stackTrace');
        // Even on error, try to trigger DB fetch if we can extract order ID
        try {
          if (data is Map<String, dynamic>) {
            final orderData = data['orderData'] as Map<String, dynamic>? ?? data;
            final orderId = orderData['orderId'] ?? orderData['order_id'] ?? orderData['id']?.toString();
            if (orderId != null) {
              debugPrint('   🔄 OSD: Attempting to trigger DB fetch with orderId: $orderId');
              final minimalOrder = OsdOrder(
                id: orderId.toString(),
                displayStatus: 'pending',
                createdAt: DateTime.now(),
              );
              onNewOrder?.call(minimalOrder);
              debugPrint('   ✅ OSD: DB fetch triggered despite error');
            }
          }
        } catch (fallbackError) {
          debugPrint('   ❌ OSD: Failed to trigger fallback DB fetch: $fallbackError');
        }
      }
    });

    // ORDER READY: order_ready_notification → Move to "It's Ready"
    _socket!.on('order_ready_notification', (data) {
      debugPrint('✅ [OSD←KDS] Order ready notification received');

      try {
        if (data is Map<String, dynamic>) {
          // Send ACK if required (Reliable Messaging)
          _sendMessageAck(data);

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

      try {
        if (data is Map<String, dynamic>) {
          // Send ACK if required (Reliable Messaging)
          _sendMessageAck(data);

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

    // ORDER RESTORED: order_restored_notification → Move based on targetStatus
    // Ready→Pending: Move back to "Now Cooking"
    // Served→Ready: Move back to "It's Ready"
    _socket!.on('order_restored_notification', (data) {
      debugPrint('🔄 [OSD←KDS/SDS] Order restored notification received');

      try {
        if (data is Map<String, dynamic>) {
          // Send ACK if required (Reliable Messaging)
          _sendMessageAck(data);

          final orderId = (data['orderId'] ?? data['order_id']) as String?;
          final targetStatus = (data['targetStatus'] ?? data['target_status'] ?? 'pending') as String;

          if (orderId != null) {
            debugPrint('   📦 Order ID: $orderId → Restoring to "$targetStatus"');
            _notificationsReceived++;
            onOrderRestored?.call(orderId, targetStatus);
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('❌ OSD: Error processing order_restored_notification: $e');
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
        'type': 'osd',
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

  /// Start token refresh timer (6-hour interval)
  void _startTokenRefreshTimer() {
    _stopTokenRefreshTimer();
    debugPrint('🔄 OSD: Starting token refresh timer (${_tokenRefreshInterval.inHours}h interval)');

    _tokenRefreshTimer = Timer.periodic(_tokenRefreshInterval, (_) {
      _refreshTokenAndReauthenticate();
    });
  }

  /// Stop token refresh timer
  void _stopTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  /// Refresh token and re-authenticate without disconnecting
  Future<void> _refreshTokenAndReauthenticate() async {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ OSD: Cannot refresh token - not connected');
      return;
    }

    if (_currentStoreId == null || _currentDeviceId == null || _currentOrganizationId == null) {
      debugPrint('⚠️ OSD: Cannot refresh token - missing connection parameters');
      return;
    }

    debugPrint('🔄 OSD: Refreshing token and re-authenticating...');

    try {
      // Get fresh token from server
      final wsTokenService = WebSocketTokenService.instance;
      final newToken = await wsTokenService.getToken(
        storeId: _currentStoreId!,
        deviceId: _currentDeviceId!,
        organizationId: _currentOrganizationId!,
        displayId: _currentDisplayId,
        forceRefresh: true,
      );

      if (newToken == null) {
        debugPrint('❌ OSD: Failed to obtain new token for re-authentication');
        _reAuthFailureCount++;
        if (_reAuthFailureCount >= _maxReAuthFailures) {
          debugPrint('❌ OSD: Maximum re-authentication failures reached. Forcing reconnection.');
          WebSocketTokenService.instance.clearToken();
          disconnect();
          _scheduleReconnect(
            _currentStoreId!,
            deviceId: _currentDeviceId,
            displayId: _currentDisplayId,
            organizationId: _currentOrganizationId,
            forceTokenRefresh: true,
          );
        }
        return;
      }

      // Send re-authenticate event
      final reAuthData = {
        'token': newToken,
        'deviceId': _currentDeviceId,
        'storeId': _currentStoreId,
        'organizationId': _currentOrganizationId,
        'type': 'osd',
      };

      _socket!.emit('re-authenticate', reAuthData);
      debugPrint('🔄 OSD: Re-authentication request sent');

    } catch (e) {
      debugPrint('❌ OSD: Token refresh error: $e');
      _reAuthFailureCount++;
      if (_reAuthFailureCount >= _maxReAuthFailures) {
        debugPrint('❌ OSD: Maximum re-authentication failures reached. Forcing reconnection.');
        disconnect();
        if (_currentStoreId != null) {
          _scheduleReconnect(
            _currentStoreId!,
            deviceId: _currentDeviceId,
            displayId: _currentDisplayId,
            organizationId: _currentOrganizationId,
            forceTokenRefresh: true,
          );
        }
      }
    }
  }

  /// Send message acknowledgment for Reliable Messaging
  ///
  /// The WebSocket server uses Reliable Messaging which requires ACKs
  /// for messages with `_requiresAck: true`. Without ACKs, the server
  /// will retry sending the same message multiple times (maxRetries=3-5).
  ///
  /// This is the same ACK mechanism used by KDS and SDS:
  /// - KDS: `kds_websocket_service.dart` lines 275-287, 570-571, 730-731, 1376-1377
  /// - SDS: `sds_websocket_service.dart` lines 747-758, 491-492, 769-770, 936-937, 959-960, 982-983
  ///
  /// The ACK flow:
  /// 1. Server sends message with `_messageId` and `_requiresAck: true`
  /// 2. Client receives message and sends `message_ack` event
  /// 3. Server marks message as delivered and stops retry attempts
  ///
  /// Events that require ACK (from ReliableMessaging.js):
  /// - order_created (from BOS/POS)
  /// - order_ready_notification (from KDS)
  /// - order_served_notification (from SDS)
  /// - order_restored_notification (from KDS/SDS)
  /// - session_updated, order_status_update, etc.
  void _sendMessageAck(Map<String, dynamic> data) {
    final messageId = data['_messageId'] as String?;
    final requiresAck = data['_requiresAck'] as bool? ?? false;

    if (messageId != null && requiresAck && _socket?.connected == true) {
      _socket!.emit('message_ack', {
        '_messageId': messageId, // Must use '_messageId' to match server expectation
        'deviceId': _currentDeviceId,
        'status': 'received',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('   📤 ACK sent for _messageId: $messageId');
    }
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
  Future<void> disconnect({bool stopNetworkMonitoring = false}) async {
    debugPrint('OSD: Disconnecting from WebSocket server');

    _stopHeartbeat();
    _stopTokenRefreshTimer();
    _reconnectTimer?.cancel();
    _authTimeoutTimer?.cancel();
    _connectionTimeoutTimer?.cancel();

    // ネットワーク監視を停止（完全切断時のみ）
    if (stopNetworkMonitoring) {
      _stopNetworkMonitoring();
    }

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
      'has_network_connection': _hasNetworkConnection,
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
        'order_restored_notification',
        'automatic_reconnection',
        'heartbeat_monitoring',
        'network_state_monitoring', // 案2追加
        'initial_connection_retry', // 案1追加
      ],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  @override
  void dispose() {
    _stopNetworkMonitoring();
    disconnect(stopNetworkMonitoring: true);
    super.dispose();
  }
}
