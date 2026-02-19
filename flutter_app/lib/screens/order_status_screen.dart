import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/osd_order.dart';
import '../services/osd_websocket_service.dart';
import '../services/osd_order_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../widgets/order_card.dart';
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

  // Track when orders became ready (for highlighting recently ready orders)
  final Map<String, DateTime> _orderReadyTimes = {};

  // Services
  late OsdWebSocketService _webSocketService;
  late OsdOrderService _orderService;
  late SettingsService _settingsService;
  late AudioService _audioService;

  // State
  bool _isLoading = true;
  bool _isConnected = false;
  String? _errorMessage;
  Timer? _clockTimer; // UI update timer for elapsed time display (KDS-style)
  Timer? _highlightTimer; // Timer to update highlight state

  // Kiosk mode: Auto-hide mouse cursor
  bool _showCursor = true;
  Timer? _cursorHideTimer;
  static const _cursorHideDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _highlightTimer?.cancel();
    _cursorHideTimer?.cancel();
    _webSocketService.disconnect();
    super.dispose();
  }

  /// Initialize services and connect to WebSocket
  ///
  /// OSD PURE WEBSOCKET MODE (KDS-style):
  /// - WebSocket events trigger DB fetch (no event data used directly)
  /// - No periodic refresh polling
  /// - Clock timer only for UI elapsed time updates
  Future<void> _initializeServices() async {
    _webSocketService = OsdWebSocketService.instance;
    _orderService = OsdOrderService.instance;
    _settingsService = SettingsService.instance;
    _audioService = AudioService.instance;

    // Setup WebSocket callbacks (KDS-style: events trigger DB fetch)
    _setupWebSocketCallbacks();

    // Load initial data from DB
    await _loadOrders();

    // Connect to WebSocket
    await _connectWebSocket();

    // Start UI timers (KDS-style: clock timer only, no polling)
    _startTimers();
  }

  /// Setup WebSocket event callbacks (KDS-style: events trigger DB fetch)
  ///
  /// OSD PURE WEBSOCKET MODE:
  /// - WebSocket events are used as TRIGGERS only
  /// - Actual data is always fetched from DB via API
  /// - This ensures data accuracy (no callNumber: null issues)
  void _setupWebSocketCallbacks() {
    // order_created → Trigger DB fetch (new order added)
    _webSocketService.onNewOrder = (order) {
      debugPrint('🆕 [OSD WebSocket] order_created event received');
      debugPrint('   📦 Order ID from event: ${order.id}');
      debugPrint('   🔄 Triggering DB fetch (KDS-style)...');
      _loadOrders(); // Fetch fresh data from DB
    };

    // order_ready_notification → Trigger DB fetch (order moved to ready)
    _webSocketService.onOrderReady = (orderId) {
      debugPrint('✅ [OSD WebSocket] order_ready_notification event received');
      debugPrint('   📦 Order ID: $orderId');
      debugPrint('   🔄 Triggering DB fetch (KDS-style)...');

      // Track when this order became ready (for highlighting)
      _orderReadyTimes[orderId] = DateTime.now();

      // Play sound immediately (don't wait for DB fetch)
      if (_settingsService.playReadySound) {
        _audioService.playOrderReadySound();
      }

      _loadOrders(); // Fetch fresh data from DB
    };

    // order_served_notification → Trigger DB fetch (order removed from display)
    _webSocketService.onOrderServed = (orderId) {
      debugPrint('🍽️ [OSD WebSocket] order_served_notification event received');
      debugPrint('   📦 Order ID: $orderId');
      debugPrint('   🔄 Triggering DB fetch (KDS-style)...');

      // Clean up tracking
      _orderReadyTimes.remove(orderId);

      _loadOrders(); // Fetch fresh data from DB
    };

    // order_restored_notification → Trigger DB fetch (order status restored)
    _webSocketService.onOrderRestored = (orderId, targetStatus) {
      debugPrint('🔄 [OSD WebSocket] order_restored_notification event received');
      debugPrint('   📦 Order ID: $orderId → $targetStatus');
      debugPrint('   🔄 Triggering DB fetch (KDS-style)...');
      _loadOrders(); // Fetch fresh data from DB
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
      debugPrint('🔄 [OSD UI] Data refresh requested (reconnection recovery)');
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
  /// 案1: connectWithInitialRetryを使用して起動時の接続を安定化
  Future<void> _connectWebSocket() async {
    final storeId = _settingsService.storeId;
    final organizationId = _settingsService.organizationId;
    final displayId = _settingsService.displayId;

    if (storeId == null || organizationId == null) {
      debugPrint('❌ [OSD UI] Missing store/organization ID');
      return;
    }

    // 起動時リトライ強化: 最大5回、段階的に待機時間を増加しながら接続を試みる
    await _webSocketService.connectWithInitialRetry(
      storeId,
      null,
      deviceId: displayId,
      displayId: displayId,
      organizationId: organizationId,
      maxAttempts: 5,
      baseDelay: const Duration(seconds: 2),
    );
  }

  /// Load orders from API (KDS-style: Single Source of Truth)
  ///
  /// This method fetches all active orders from the database.
  /// Called on:
  /// - Initial load
  /// - WebSocket events (order_created, order_ready, order_served, order_restored)
  /// - Reconnection recovery
  Future<void> _loadOrders() async {
    final storeId = _settingsService.storeId;
    if (storeId == null) return;

    debugPrint('📥 [OSD DB] Fetching orders from database...');

    // Only show loading indicator on initial load
    if (_nowCookingOrders.isEmpty && _readyOrders.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

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

      debugPrint('✅ [OSD DB] Loaded ${_nowCookingOrders.length} cooking, ${_readyOrders.length} ready');

      // Debug: Log order details
      for (final order in _nowCookingOrders) {
        debugPrint('   🍳 Cooking: ${order.displayNumber} (id=${order.id}, callNumber=${order.callNumber})');
      }
      for (final order in _readyOrders) {
        debugPrint('   ✅ Ready: ${order.displayNumber} (id=${order.id}, callNumber=${order.callNumber})');
      }
    } catch (e) {
      debugPrint('❌ [OSD DB] Error loading orders: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load orders';
      });
    }
  }

  /// Start UI timers (KDS-style: PURE WEBSOCKET MODE)
  ///
  /// OSD PURE WEBSOCKET MODE:
  /// - NO POLLING: WebSocket events trigger DB fetch for all updates
  /// - Clock timer: 500ms interval for smooth elapsed time display updates
  /// - Highlight timer: 5s interval for recently ready order highlight cleanup
  void _startTimers() {
    debugPrint('✅ OSD PURE WEBSOCKET MODE: No polling - WebSocket events trigger DB fetch');

    // Clock timer: Only needed when elapsed time display is enabled
    // Uses 1-second interval (sufficient for minute-based display like "<1m", "5m")
    final needsClockTimer = _settingsService.showElapsedTimeNowCooking ||
        _settingsService.showElapsedTimeReady;

    _clockTimer?.cancel();
    if (needsClockTimer) {
      debugPrint('   ⏱️ Clock timer started (elapsed time display is ON)');
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      debugPrint('   ⏱️ Clock timer not needed (elapsed time display is OFF)');
    }

    // Highlight timer for recently ready order highlight cleanup
    _highlightTimer?.cancel();
    _highlightTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _orderReadyTimes.isNotEmpty) {
        // Clean up expired entries
        final now = DateTime.now();
        final highlightDuration = _settingsService.highlightDuration;
        final expiredOrders = <String>[];
        for (final entry in _orderReadyTimes.entries) {
          if (now.difference(entry.value) > highlightDuration) {
            expiredOrders.add(entry.key);
          }
        }
        if (expiredOrders.isNotEmpty) {
          setState(() {
            for (final orderId in expiredOrders) {
              _orderReadyTimes.remove(orderId);
            }
          });
        }
      }
    });
  }

  /// Check if an order should be highlighted (recently became ready)
  bool _isOrderHighlighted(String orderId) {
    final readyTime = _orderReadyTimes[orderId];
    if (readyTime == null) return false;
    return DateTime.now().difference(readyTime) <= _settingsService.highlightDuration;
  }

  /// Reset cursor hide timer (called on mouse movement)
  void _resetCursorHideTimer() {
    // Show cursor immediately when mouse moves
    if (!_showCursor) {
      setState(() {
        _showCursor = true;
      });
    }

    // Cancel existing timer and start a new one
    _cursorHideTimer?.cancel();
    _cursorHideTimer = Timer(_cursorHideDelay, () {
      if (mounted) {
        setState(() {
          _showCursor = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    // Always use light mode (white-based UI like KDS)
    const isDarkMode = false;

    return MouseRegion(
      cursor: _showCursor ? SystemMouseCursors.basic : SystemMouseCursors.none,
      onHover: (_) => _resetCursorHideTimer(),
      onEnter: (_) => _resetCursorHideTimer(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Stack(
          children: [
            // Main content (full screen)
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2196F3),
                    ),
                  )
                : _buildMainContent(isDarkMode, settingsService.showElapsedTimeNowCooking, settingsService.showElapsedTimeReady),

            // Connection indicator (top-right corner)
            Positioned(
              top: 8,
              right: 8,
              child: _buildConnectionIndicator(isDarkMode),
            ),

            // Settings button (top-left corner)
            Positioned(
              top: 8,
              left: 8,
              child: _buildSettingsButton(isDarkMode),
            ),
          ],
        ),
      ),
    );
  }

  /// Build connection status indicator (small dot)
  Widget _buildConnectionIndicator(bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        // Show connection details on tap
        _showConnectionDetails();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDarkMode ? Colors.black : Colors.white).withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Connection dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? Colors.green : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: (_isConnected ? Colors.green : Colors.red).withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build settings button (gear icon)
  Widget _buildSettingsButton(bool isDarkMode) {
    return GestureDetector(
      onTap: _openSettings,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDarkMode ? Colors.black : Colors.white).withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.settings,
          size: 20,
          color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
        ),
      ),
    );
  }

  /// Show connection details dialog
  void _showConnectionDetails() {
    // Always use light mode (white-based UI like KDS)
    const isDarkMode = false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isConnected ? 'Connected' : 'Disconnected',
              style: const TextStyle(
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Text(
                'Error: $_errorMessage',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Now Cooking: ${_nowCookingOrders.length}',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
            Text(
              'Ready: ${_readyOrders.length}',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadOrders();
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDarkMode, bool showElapsedTimeNowCooking, bool showElapsedTimeReady) {
    // Filter orders based on display type setting
    // Only show orders that have the required data for the selected display type
    final filteredNowCookingOrders =
        _nowCookingOrders.where((o) => o.shouldDisplay).toList();
    final filteredReadyOrders =
        _readyOrders.where((o) => o.shouldDisplay).toList();

    debugPrint('🔄 [OSD UI] Building content: nowCooking=${_nowCookingOrders.length}→${filteredNowCookingOrders.length}, ready=${_readyOrders.length}→${filteredReadyOrders.length}');

    return Row(
      children: [
        // Left Column: "Now Cooking"
        Expanded(
          child: _buildColumn(
            title: 'Now Cooking',
            orders: filteredNowCookingOrders,
            backgroundColor: isDarkMode ? const Color(0xFF0F3460) : const Color(0xFFE3F2FD),
            accentColor: const Color(0xFFFF9800),
            emptyMessage: 'No orders being prepared',
            isDarkMode: isDarkMode,
            showElapsedTime: showElapsedTimeNowCooking, // Controlled by settings
          ),
        ),

        // Divider
        Container(
          width: 2,
          color: isDarkMode
              ? const Color(0xFF00D9FF).withOpacity(0.3)
              : const Color(0xFF2196F3).withOpacity(0.3),
        ),

        // Right Column: "It's Ready"
        Expanded(
          child: _buildColumn(
            title: "It's Ready",
            orders: filteredReadyOrders,
            backgroundColor: isDarkMode ? const Color(0xFF16213E) : const Color(0xFFE8F5E9),
            accentColor: const Color(0xFF4CAF50),
            emptyMessage: 'No orders ready for pickup',
            isReady: true,
            isDarkMode: isDarkMode,
            showElapsedTime: showElapsedTimeReady, // Controlled by settings
          ),
        ),
      ],
    );
  }

  Widget _buildColumn({
    required String title,
    required List<OsdOrder> orders,
    required Color backgroundColor,
    required Color accentColor,
    required String emptyMessage,
    bool isReady = false,
    bool isDarkMode = true,
    bool showElapsedTime = true,
  }) {
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          // Header - Compact with title and count side by side
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withOpacity(isDarkMode ? 0.3 : 0.4),
                  accentColor.withOpacity(isDarkMode ? 0.1 : 0.2),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 12),
                // Count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(16),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isReady ? Icons.check_circle_outline : Icons.restaurant,
                          size: 144,
                          color: textColor.withOpacity(0.3),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              emptyMessage,
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w500,
                                color: textColor.withOpacity(0.5),
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : isReady
                    ? _buildReadyColumnContent(orders, isDarkMode, showElapsedTime)
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.0, // Width is 2x height (half height cards)
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return OrderCard(
                            order: order,
                            isReady: false,
                            isDarkMode: isDarkMode,
                            showElapsedTime: showElapsedTime,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
    // Restart timers after settings change (elapsed time display may have changed)
    _startTimers();
  }

  /// Build the "It's Ready" column content with highlighted orders at the top
  Widget _buildReadyColumnContent(List<OsdOrder> orders, bool isDarkMode, bool showElapsedTime) {
    // Separate highlighted (recently ready) orders from normal ones
    final highlightedOrders = <OsdOrder>[];
    final normalOrders = <OsdOrder>[];

    for (final order in orders) {
      if (_isOrderHighlighted(order.id)) {
        highlightedOrders.add(order);
      } else {
        normalOrders.add(order);
      }
    }

    // If no highlighted orders, show normal grid
    if (highlightedOrders.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.0,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return OrderCard(
            order: order,
            isReady: true,
            isDarkMode: isDarkMode,
            showElapsedTime: showElapsedTime,
          );
        },
      );
    }

    // Show highlighted orders prominently at the top
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Highlighted orders - Large, prominent display
          // Show up to 3 highlighted orders in a row
          _buildHighlightedOrdersSection(highlightedOrders, isDarkMode, showElapsedTime),

          // Divider if there are normal orders
          if (normalOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Earlier',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Normal orders - Smaller grid
          if (normalOrders.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.0,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: normalOrders.length,
              itemBuilder: (context, index) {
                final order = normalOrders[index];
                return OrderCard(
                  order: order,
                  isReady: true,
                  isDarkMode: isDarkMode,
                  showElapsedTime: showElapsedTime,
                );
              },
            ),
        ],
      ),
    );
  }

  /// Build the highlighted orders section with large, prominent cards
  Widget _buildHighlightedOrdersSection(
      List<OsdOrder> highlightedOrders, bool isDarkMode, bool showElapsedTime) {
    // Display highlighted orders in a row (up to 3 per row)
    // Each highlighted card is larger and more prominent
    // For 4+ orders, maintain 1/3 size for consistency
    final rows = <Widget>[];

    // Determine layout based on total count
    // 1 order: 1 per row (full width)
    // 2 orders: 2 per row (half width each)
    // 3+ orders: always 3 per row (1/3 width each)
    final ordersPerRow = highlightedOrders.length <= 2 ? highlightedOrders.length : 3;

    for (var i = 0; i < highlightedOrders.length; i += ordersPerRow) {
      final rowOrders = highlightedOrders.skip(i).take(ordersPerRow).toList();
      final actualItemsInRow = rowOrders.length;

      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + ordersPerRow < highlightedOrders.length ? 8 : 0),
          child: Row(
            children: [
              // Actual order cards
              ...rowOrders.asMap().entries.map((entry) {
                final index = entry.key;
                final order = entry.value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : 4,
                      right: index == actualItemsInRow - 1 && actualItemsInRow == ordersPerRow ? 0 : 4,
                    ),
                    child: AspectRatio(
                      aspectRatio: highlightedOrders.length == 1 ? 2.5 : 1.5, // Taller for highlighted
                      child: OrderCard(
                        order: order,
                        isReady: true,
                        isDarkMode: isDarkMode,
                        isHighlighted: true,
                        showElapsedTime: showElapsedTime,
                      ),
                    ),
                  ),
                );
              }),
              // Add empty spacers to maintain 1/3 size for 4+ orders (when row has fewer than 3 items)
              if (highlightedOrders.length >= 3)
                ...List.generate(ordersPerRow - actualItemsInRow, (_) => const Expanded(child: SizedBox())),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}
