import 'dart:async';
import 'package:flutter/material.dart';
import '../models/osd_order.dart';
import '../services/osd_websocket_service.dart';
import '../services/osd_order_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../widgets/order_card.dart';
import '../widgets/connection_status_bar.dart';
import 'settings_screen.dart';

/// Order Status Screen
///
/// Main display screen showing two columns:
/// - Left: "Now Cooking" (調理中) - Orders being prepared
/// - Right: "It's Ready" (お待たせしました) - Orders ready for pickup
class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({super.key});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  // Orders
  final List<OsdOrder> _nowCookingOrders = [];
  final List<OsdOrder> _readyOrders = [];

  // Services
  late OsdWebSocketService _webSocketService;
  late OsdOrderService _orderService;
  late SettingsService _settingsService;
  late AudioService _audioService;

  // State
  bool _isLoading = true;
  bool _isConnected = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _webSocketService.disconnect();
    super.dispose();
  }

  /// Initialize services and connect to WebSocket
  Future<void> _initializeServices() async {
    _webSocketService = OsdWebSocketService.instance;
    _orderService = OsdOrderService.instance;
    _settingsService = SettingsService.instance;
    _audioService = AudioService.instance;

    // Setup WebSocket callbacks
    _setupWebSocketCallbacks();

    // Load initial data
    await _loadOrders();

    // Connect to WebSocket
    await _connectWebSocket();

    // Setup periodic refresh as fallback
    _setupPeriodicRefresh();
  }

  /// Setup WebSocket event callbacks
  void _setupWebSocketCallbacks() {
    // New order created → Add to "Now Cooking"
    _webSocketService.onNewOrder = (order) {
      debugPrint('📥 [OSD UI] New order received: ${order.displayNumber}');
      setState(() {
        // Add to "Now Cooking" if not already present
        if (!_nowCookingOrders.any((o) => o.id == order.id)) {
          _nowCookingOrders.insert(0, order);
        }
      });
    };

    // Order ready → Move to "It's Ready"
    _webSocketService.onOrderReady = (orderId) {
      debugPrint('📥 [OSD UI] Order ready: $orderId');
      setState(() {
        // Find order in "Now Cooking"
        final orderIndex =
            _nowCookingOrders.indexWhere((o) => o.id == orderId);
        if (orderIndex != -1) {
          // Move to "It's Ready"
          final order = _nowCookingOrders.removeAt(orderIndex);
          final readyOrder = order.copyWith(
            displayStatus: 'ready',
            kitchenCompletedAt: DateTime.now(),
          );
          _readyOrders.insert(0, readyOrder);

          // Play sound
          if (_settingsService.playReadySound) {
            _audioService.playOrderReadySound();
          }
        } else {
          // Order not in "Now Cooking", might need to fetch from API
          _refreshSingleOrder(orderId);
        }
      });
    };

    // Order served → Remove from display
    _webSocketService.onOrderServed = (orderId) {
      debugPrint('📥 [OSD UI] Order served: $orderId');
      setState(() {
        _readyOrders.removeWhere((o) => o.id == orderId);
        _nowCookingOrders.removeWhere((o) => o.id == orderId);
      });
    };

    // Connection status
    _webSocketService.onConnected = () {
      debugPrint('✅ [OSD UI] WebSocket connected');
      setState(() {
        _isConnected = true;
        _errorMessage = null;
      });
    };

    _webSocketService.onDisconnected = () {
      debugPrint('❌ [OSD UI] WebSocket disconnected');
      setState(() {
        _isConnected = false;
      });
    };

    // Data refresh (recovery after reconnection)
    _webSocketService.onDataRefreshRequested = () {
      debugPrint('🔄 [OSD UI] Data refresh requested');
      _loadOrders();
    };

    // Error handling
    _webSocketService.onError = (error) {
      debugPrint('❌ [OSD UI] WebSocket error: $error');
      setState(() {
        _errorMessage = error;
      });
    };
  }

  /// Connect to WebSocket server
  Future<void> _connectWebSocket() async {
    final storeId = _settingsService.storeId;
    final organizationId = _settingsService.organizationId;
    final displayId = _settingsService.displayId;

    if (storeId == null || organizationId == null) {
      debugPrint('❌ [OSD UI] Missing store/organization ID');
      return;
    }

    await _webSocketService.connect(
      storeId,
      null,
      deviceId: displayId,
      displayId: displayId,
      organizationId: organizationId,
    );
  }

  /// Load orders from API
  Future<void> _loadOrders() async {
    final storeId = _settingsService.storeId;
    if (storeId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final orders = await _orderService.fetchActiveOrders(storeId);

      setState(() {
        _nowCookingOrders.clear();
        _readyOrders.clear();

        for (final order in orders) {
          if (order.isNowCooking) {
            _nowCookingOrders.add(order);
          } else if (order.isReady) {
            _readyOrders.add(order);
          }
        }

        // Sort by creation time
        _nowCookingOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _readyOrders.sort((a, b) {
          final aTime = a.kitchenCompletedAt ?? a.createdAt;
          final bTime = b.kitchenCompletedAt ?? b.createdAt;
          return aTime.compareTo(bTime);
        });

        _isLoading = false;
        _errorMessage = null;
      });

      debugPrint(
          '✅ [OSD UI] Loaded ${_nowCookingOrders.length} cooking, ${_readyOrders.length} ready');
    } catch (e) {
      debugPrint('❌ [OSD UI] Error loading orders: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load orders';
      });
    }
  }

  /// Refresh a single order from API
  Future<void> _refreshSingleOrder(String orderId) async {
    final order = await _orderService.getOrderById(orderId);
    if (order == null) return;

    setState(() {
      if (order.isNowCooking) {
        if (!_nowCookingOrders.any((o) => o.id == order.id)) {
          _nowCookingOrders.add(order);
        }
      } else if (order.isReady) {
        // Remove from "Now Cooking" if present
        _nowCookingOrders.removeWhere((o) => o.id == order.id);
        // Add to "Ready" if not present
        if (!_readyOrders.any((o) => o.id == order.id)) {
          _readyOrders.insert(0, order);
          if (_settingsService.playReadySound) {
            _audioService.playOrderReadySound();
          }
        }
      }
    });
  }

  /// Setup periodic refresh as fallback
  void _setupPeriodicRefresh() {
    final interval = _settingsService.autoRefreshInterval;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: interval), (_) {
      if (!_isConnected) {
        debugPrint('🔄 [OSD UI] Periodic refresh (WebSocket disconnected)');
        _loadOrders();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Column(
        children: [
          // Connection status bar
          ConnectionStatusBar(
            isConnected: _isConnected,
            onSettingsTap: () => _openSettings(),
            errorMessage: _errorMessage,
          ),

          // Main content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00D9FF),
                    ),
                  )
                : _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Row(
      children: [
        // Left Column: "Now Cooking"
        Expanded(
          child: _buildColumn(
            title: 'Now Cooking',
            subtitle: 'Preparing Your Order',
            orders: _nowCookingOrders,
            backgroundColor: const Color(0xFF0F3460),
            accentColor: const Color(0xFFFF9800),
            emptyMessage: 'No orders being prepared',
          ),
        ),

        // Divider
        Container(
          width: 2,
          color: const Color(0xFF00D9FF).withOpacity(0.3),
        ),

        // Right Column: "It's Ready"
        Expanded(
          child: _buildColumn(
            title: "It's Ready",
            subtitle: 'Please Pick Up',
            orders: _readyOrders,
            backgroundColor: const Color(0xFF16213E),
            accentColor: const Color(0xFF4CAF50),
            emptyMessage: 'No orders ready for pickup',
            isReady: true,
          ),
        ),
      ],
    );
  }

  Widget _buildColumn({
    required String title,
    required String subtitle,
    required List<OsdOrder> orders,
    required Color backgroundColor,
    required Color accentColor,
    required String emptyMessage,
    bool isReady = false,
  }) {
    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withOpacity(0.3),
                  accentColor.withOpacity(0.1),
                ],
              ),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${orders.length}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Order cards
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Text(
                      emptyMessage,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return OrderCard(
                        order: order,
                        isReady: isReady,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }
}
