import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// OSD Order Model
///
/// Simplified order model for Order Status Display.
/// Only contains fields necessary for customer-facing display:
/// - Call Number (primary identifier for customers)
/// - Table Number (for dine-in orders)
/// - Order Number (fallback identifier)
/// - Dining Option (for display differentiation)
/// - Display Status (pending/ready/served) - derived from order_items.display_status
/// - Timestamps (for elapsed time calculation)
class OsdOrder {
  final String id;
  final int? callNumber;
  final int? tableNumber;
  final String? orderNumber;
  final String? diningOption;
  final String displayStatus; // 'pending', 'ready', 'served' - from order_items.display_status
  final String? kitchenStatus; // Legacy field from orders table (for reference only)
  final DateTime createdAt;
  final DateTime? kitchenCompletedAt; // Legacy: When marked ready (from orders table)
  final DateTime? readyAt; // Accurate: When display_status became 'ready' (from order_items.display_status.ready_at)
  final DateTime? servedAt; // When served (removed from display)

  OsdOrder({
    required this.id,
    this.callNumber,
    this.tableNumber,
    this.orderNumber,
    this.diningOption,
    required this.displayStatus,
    this.kitchenStatus,
    required this.createdAt,
    this.kitchenCompletedAt,
    this.readyAt,
    this.servedAt,
  });

  /// Get the display number for the order card based on settings
  /// Uses the configured primary display type with fallbacks
  String get displayNumber {
    final displayType = SettingsService.instance.primaryDisplayType;

    switch (displayType) {
      case PrimaryDisplayType.callNumber:
        if (callNumber != null) {
          return callNumber.toString().padLeft(3, '0');
        }
        // Fallback to table number or order number
        if (tableNumber != null) {
          return 'T${tableNumber.toString()}';
        }
        return _formatOrderNumber();

      case PrimaryDisplayType.tableNumber:
        if (tableNumber != null) {
          return tableNumber.toString();
        }
        // Fallback to call number or order number
        if (callNumber != null) {
          return callNumber.toString().padLeft(3, '0');
        }
        return _formatOrderNumber();

      case PrimaryDisplayType.orderNumber:
        return _formatOrderNumber();
    }
  }

  /// Format order number for display
  /// Handles split order numbers by extracting the parent order number
  /// e.g., "ORD-0001-1" or "ORD-0001-2" → "#0001"
  String _formatOrderNumber() {
    if (orderNumber != null) {
      // Extract parent order number (remove split suffix like "-1", "-2", "-1/2", "-2/2")
      final parentNumber = _extractParentOrderNumber(orderNumber!);

      // Extract last 4 characters if order number is long
      if (parentNumber.length > 4) {
        return '#${parentNumber.substring(parentNumber.length - 4)}';
      }
      return '#$parentNumber';
    }
    return '---';
  }

  /// Extract the parent order number from a potentially split order number
  /// Examples:
  /// - "ORD-0001-1" → "ORD-0001"
  /// - "ORD-0001-2/2" → "ORD-0001"
  /// - "ORD-0001-1/2" → "ORD-0001"
  /// - "ORD-0001" → "ORD-0001" (no change)
  /// - "BOS-0001-1" → "BOS-0001"
  static String _extractParentOrderNumber(String orderNumber) {
    // Split order format: BASE-N or BASE-N/M
    // where BASE is like "ORD-0001" or "BOS-0001"
    // and N, M are single digits (split index/total)
    //
    // We need to match ONLY the split suffix at the end:
    // -1, -2, -1/2, -2/2, -3/3 etc.
    // But NOT the base number like -0001
    //
    // Split suffix pattern: dash followed by 1-2 digits, optionally followed by /digits
    // The key is that split indices are typically small numbers (1-9)
    // while base numbers are 4+ digits (0001, 0002, etc.)
    final splitSuffixPattern = RegExp(r'-(\d{1,2})(/\d+)?$');
    final match = splitSuffixPattern.firstMatch(orderNumber);

    if (match != null) {
      // Check if the matched number is likely a split index (small number)
      // vs part of the base order number (typically 4+ digits)
      final matchedNumber = match.group(1);
      if (matchedNumber != null && matchedNumber.length <= 2) {
        // This looks like a split suffix, remove it
        return orderNumber.substring(0, match.start);
      }
    }

    // No split suffix found, return as-is
    return orderNumber;
  }

  /// Get the parent order number (for grouping split orders)
  /// Returns the order number without split suffix
  String? get parentOrderNumber {
    if (orderNumber == null) return null;
    return _extractParentOrderNumber(orderNumber!);
  }

  /// Check if this order is a split order
  bool get isSplitOrder {
    if (orderNumber == null) return false;
    // Split suffix: -N or -N/M where N is 1-2 digits
    final splitSuffixPattern = RegExp(r'-(\d{1,2})(/\d+)?$');
    final match = splitSuffixPattern.firstMatch(orderNumber!);
    if (match != null) {
      final matchedNumber = match.group(1);
      // Only consider it a split if the suffix is a small number (1-2 digits)
      return matchedNumber != null && matchedNumber.length <= 2;
    }
    return false;
  }

  /// Get display label based on settings (e.g., "", "Table", "Order")
  String get displayLabel {
    final displayType = SettingsService.instance.primaryDisplayType;

    switch (displayType) {
      case PrimaryDisplayType.callNumber:
        if (callNumber != null) return '';
        if (tableNumber != null) return 'Table';
        return '';

      case PrimaryDisplayType.tableNumber:
        if (tableNumber != null) return 'Table';
        if (callNumber != null) return '';
        return '';

      case PrimaryDisplayType.orderNumber:
        return 'Order';
    }
  }

  /// Check if order should be displayed based on current display type setting
  /// Returns true if the order has the required data for the selected display type
  bool get shouldDisplay {
    final displayType = SettingsService.instance.primaryDisplayType;

    switch (displayType) {
      case PrimaryDisplayType.callNumber:
        // Only show orders with call number when call number is selected
        return callNumber != null;

      case PrimaryDisplayType.tableNumber:
        // Only show orders with table number when table number is selected
        return tableNumber != null;

      case PrimaryDisplayType.orderNumber:
        // Always show for order number (all orders have order number or ID)
        return true;
    }
  }

  /// Check if order is in "Now Cooking" status
  /// Uses displayStatus (from order_items.display_status) for accurate determination
  bool get isNowCooking =>
      displayStatus == 'pending' || displayStatus == 'in_progress';

  /// Check if order is in "Ready" status
  /// Uses displayStatus (from order_items.display_status) for accurate determination
  bool get isReady => displayStatus == 'ready';

  /// Check if order has been served
  /// Uses displayStatus (from order_items.display_status) for accurate determination
  bool get isServed => displayStatus == 'served' || servedAt != null;

  /// Get elapsed time since order was created
  Duration get elapsedTime {
    final diff = DateTime.now().difference(createdAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Get elapsed time since order became ready
  /// Uses readyAt (from order_items.display_status.ready_at) for accuracy
  /// Falls back to kitchenCompletedAt if readyAt is not available
  Duration get elapsedSinceReady {
    final readyTime = readyAt ?? kitchenCompletedAt;
    if (readyTime == null) return Duration.zero;
    final diff = DateTime.now().difference(readyTime);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Get order priority based on elapsed time
  OsdOrderPriority get priority {
    final minutes = isReady ? elapsedSinceReady.inMinutes : elapsedTime.inMinutes;
    if (minutes < 5) return OsdOrderPriority.normal;
    if (minutes < 10) return OsdOrderPriority.attention;
    return OsdOrderPriority.urgent;
  }

  /// Get priority color
  Color get priorityColor {
    switch (priority) {
      case OsdOrderPriority.normal:
        return const Color(0xFF4CAF50); // Green
      case OsdOrderPriority.attention:
        return const Color(0xFFFF9800); // Orange
      case OsdOrderPriority.urgent:
        return const Color(0xFFF44336); // Red
    }
  }

  /// Create from KDS API JSON response
  ///
  /// The API returns orders with order_items array. Each item has display_status.
  /// We derive the order's displayStatus and readyAt from the first item's display_status.
  /// This matches how the API filters orders (by order_items.display_status.status).
  factory OsdOrder.fromJson(Map<String, dynamic> json) {
    // Derive displayStatus and readyAt from order_items.display_status
    // The API filters by order_items.display_status.status, so all items
    // in a returned order should have the same display_status
    String derivedDisplayStatus = 'pending';
    DateTime? derivedReadyAt;

    final orderItems = json['order_items'] as List<dynamic>?;
    if (orderItems != null && orderItems.isNotEmpty) {
      // Get display_status from first item
      final firstItem = orderItems[0] as Map<String, dynamic>?;
      if (firstItem != null) {
        final displayStatusObj = firstItem['display_status'];
        if (displayStatusObj is Map<String, dynamic>) {
          derivedDisplayStatus = displayStatusObj['status'] as String? ?? 'pending';
          // Parse ready_at from display_status JSONB
          final readyAtStr = displayStatusObj['ready_at'] as String?;
          if (readyAtStr != null) {
            derivedReadyAt = DateTime.tryParse(readyAtStr);
          }
        } else if (displayStatusObj is String) {
          derivedDisplayStatus = displayStatusObj;
        }
      }
    }

    // Parse ID - handle various formats
    final rawId = json['id'];
    final parsedId = rawId?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';

    // Parse createdAt - handle various formats
    DateTime parsedCreatedAt = DateTime.now();
    final rawCreatedAt = json['created_at'];
    if (rawCreatedAt != null) {
      if (rawCreatedAt is String) {
        parsedCreatedAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
      } else if (rawCreatedAt is int) {
        parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
      }
    }

    // Parse kitchenCompletedAt
    DateTime? parsedKitchenCompletedAt;
    final rawKitchenCompletedAt = json['kitchen_completed_at'];
    if (rawKitchenCompletedAt != null && rawKitchenCompletedAt is String) {
      parsedKitchenCompletedAt = DateTime.tryParse(rawKitchenCompletedAt);
    }

    // Parse servedAt
    DateTime? parsedServedAt;
    final rawServedAt = json['served_at'];
    if (rawServedAt != null && rawServedAt is String) {
      parsedServedAt = DateTime.tryParse(rawServedAt);
    }

    return OsdOrder(
      id: parsedId,
      callNumber: _parseIntOrNull(json['call_number']),
      tableNumber: _parseIntOrNull(json['table_number']),
      orderNumber: json['order_number']?.toString(),
      diningOption: json['dining_option']?.toString(),
      displayStatus: derivedDisplayStatus,
      kitchenStatus: json['kitchen_status']?.toString(),
      createdAt: parsedCreatedAt,
      kitchenCompletedAt: parsedKitchenCompletedAt,
      readyAt: derivedReadyAt,
      servedAt: parsedServedAt,
    );
  }

  /// Create from WebSocket event data
  factory OsdOrder.fromWebSocketEvent(Map<String, dynamic> data) {
    debugPrint('🔧 [OsdOrder.fromWebSocketEvent] Parsing data keys: ${data.keys.toList()}');

    // WebSocket events may have different field names
    // Try to get displayStatus and readyAt from various possible field names
    String derivedDisplayStatus = 'pending';
    DateTime? derivedReadyAt;

    // Check for display_status in order_items (if present)
    final orderItems = data['order_items'] ?? data['orderItems'];
    if (orderItems is List && orderItems.isNotEmpty) {
      final firstItem = orderItems[0] as Map<String, dynamic>?;
      if (firstItem != null) {
        final displayStatusObj = firstItem['display_status'] ?? firstItem['displayStatus'];
        if (displayStatusObj is Map<String, dynamic>) {
          derivedDisplayStatus = (displayStatusObj['status'] as String?) ?? 'pending';
          // Parse ready_at from display_status JSONB
          final readyAtStr = (displayStatusObj['ready_at'] ?? displayStatusObj['readyAt']) as String?;
          if (readyAtStr != null) {
            derivedReadyAt = DateTime.tryParse(readyAtStr);
          }
        } else if (displayStatusObj is String) {
          derivedDisplayStatus = displayStatusObj;
        }
      }
    } else {
      // Fallback: use displayStatus or kitchen_status from the event data
      final statusValue = data['displayStatus'] ??
              data['display_status'] ??
              data['kitchenStatus'] ??
              data['kitchen_status'];
      if (statusValue is String) {
        derivedDisplayStatus = statusValue;
      }
    }

    // Debug: Log the raw values before parsing
    final rawCallNumber = data['callNumber'] ?? data['call_number'];
    final rawTableNumber = data['tableNumber'] ?? data['table_number'];
    final rawOrderNumber = data['orderNumber'] ?? data['order_number'];
    debugPrint('🔧 [OsdOrder.fromWebSocketEvent] Raw callNumber: $rawCallNumber (type: ${rawCallNumber?.runtimeType})');
    debugPrint('🔧 [OsdOrder.fromWebSocketEvent] Raw tableNumber: $rawTableNumber (type: ${rawTableNumber?.runtimeType})');
    debugPrint('🔧 [OsdOrder.fromWebSocketEvent] Raw orderNumber: $rawOrderNumber (type: ${rawOrderNumber?.runtimeType})');

    final parsedCallNumber = _parseIntOrNull(rawCallNumber);
    final parsedTableNumber = _parseIntOrNull(rawTableNumber);
    final parsedOrderNumber = rawOrderNumber?.toString();
    debugPrint('🔧 [OsdOrder.fromWebSocketEvent] Parsed callNumber: $parsedCallNumber');
    debugPrint('🔧 [OsdOrder.fromWebSocketEvent] Parsed tableNumber: $parsedTableNumber');
    debugPrint('🔧 [OsdOrder.fromWebSocketEvent] Parsed orderNumber: $parsedOrderNumber');

    // Parse ID - handle various formats
    final rawId = data['orderId'] ?? data['order_id'] ?? data['id'];
    final parsedId = rawId?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('🔧 [OsdOrder.fromWebSocketEvent] Parsed ID: $parsedId');

    // Parse createdAt - handle various formats
    DateTime parsedCreatedAt = DateTime.now();
    final rawCreatedAt = data['createdAt'] ?? data['created_at'];
    if (rawCreatedAt != null) {
      if (rawCreatedAt is String) {
        parsedCreatedAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
      } else if (rawCreatedAt is int) {
        // Handle timestamp in milliseconds
        parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
      }
    }

    // Parse kitchenCompletedAt
    DateTime? parsedKitchenCompletedAt;
    final rawKitchenCompletedAt = data['kitchenCompletedAt'] ?? data['kitchen_completed_at'];
    if (rawKitchenCompletedAt != null && rawKitchenCompletedAt is String) {
      parsedKitchenCompletedAt = DateTime.tryParse(rawKitchenCompletedAt);
    }

    // Parse servedAt
    DateTime? parsedServedAt;
    final rawServedAt = data['servedAt'] ?? data['served_at'];
    if (rawServedAt != null && rawServedAt is String) {
      parsedServedAt = DateTime.tryParse(rawServedAt);
    }

    return OsdOrder(
      id: parsedId,
      callNumber: parsedCallNumber,
      tableNumber: parsedTableNumber,
      orderNumber: parsedOrderNumber,
      diningOption:
          (data['diningOption'] ?? data['dining_option'])?.toString(),
      displayStatus: derivedDisplayStatus,
      kitchenStatus:
          (data['kitchenStatus'] ?? data['kitchen_status'])?.toString(),
      createdAt: parsedCreatedAt,
      kitchenCompletedAt: parsedKitchenCompletedAt,
      readyAt: derivedReadyAt,
      servedAt: parsedServedAt,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'call_number': callNumber,
      'table_number': tableNumber,
      'order_number': orderNumber,
      'dining_option': diningOption,
      'display_status': displayStatus,
      'kitchen_status': kitchenStatus,
      'created_at': createdAt.toIso8601String(),
      'kitchen_completed_at': kitchenCompletedAt?.toIso8601String(),
      'ready_at': readyAt?.toIso8601String(),
      'served_at': servedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  OsdOrder copyWith({
    String? id,
    int? callNumber,
    int? tableNumber,
    String? orderNumber,
    String? diningOption,
    String? displayStatus,
    String? kitchenStatus,
    DateTime? createdAt,
    DateTime? kitchenCompletedAt,
    DateTime? readyAt,
    DateTime? servedAt,
  }) {
    return OsdOrder(
      id: id ?? this.id,
      callNumber: callNumber ?? this.callNumber,
      tableNumber: tableNumber ?? this.tableNumber,
      orderNumber: orderNumber ?? this.orderNumber,
      diningOption: diningOption ?? this.diningOption,
      displayStatus: displayStatus ?? this.displayStatus,
      kitchenStatus: kitchenStatus ?? this.kitchenStatus,
      createdAt: createdAt ?? this.createdAt,
      kitchenCompletedAt: kitchenCompletedAt ?? this.kitchenCompletedAt,
      readyAt: readyAt ?? this.readyAt,
      servedAt: servedAt ?? this.servedAt,
    );
  }

  @override
  String toString() {
    return 'OsdOrder(id: $id, displayNumber: $displayNumber, displayStatus: $displayStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OsdOrder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Helper to parse int from dynamic value (handles String or int)
  static int? _parseIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Order priority levels for display styling
enum OsdOrderPriority {
  normal,
  attention,
  urgent,
}

/// Order display column types
enum OsdColumn {
  nowCooking, // "Now Cooking"
  ready, // "It's Ready"
}
