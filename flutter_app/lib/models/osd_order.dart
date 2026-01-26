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
  final DateTime? kitchenCompletedAt; // When marked ready
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
  String _formatOrderNumber() {
    if (orderNumber != null) {
      // Extract last 4 characters if order number is long
      if (orderNumber!.length > 4) {
        return '#${orderNumber!.substring(orderNumber!.length - 4)}';
      }
      return '#$orderNumber';
    }
    return '---';
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
  Duration get elapsedSinceReady {
    if (kitchenCompletedAt == null) return Duration.zero;
    final diff = DateTime.now().difference(kitchenCompletedAt!);
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

  /// Check if order should flash (waiting too long in ready status)
  bool get shouldFlash => isReady && elapsedSinceReady.inMinutes >= 5;

  /// Create from KDS API JSON response
  ///
  /// The API returns orders with order_items array. Each item has display_status.
  /// We derive the order's displayStatus from the first item's display_status.
  /// This matches how the API filters orders (by order_items.display_status.status).
  factory OsdOrder.fromJson(Map<String, dynamic> json) {
    // Derive displayStatus from order_items.display_status
    // The API filters by order_items.display_status.status, so all items
    // in a returned order should have the same display_status
    String derivedDisplayStatus = 'pending';

    final orderItems = json['order_items'] as List<dynamic>?;
    if (orderItems != null && orderItems.isNotEmpty) {
      // Get display_status from first item
      final firstItem = orderItems[0] as Map<String, dynamic>?;
      if (firstItem != null) {
        final displayStatusObj = firstItem['display_status'];
        if (displayStatusObj is Map<String, dynamic>) {
          derivedDisplayStatus = displayStatusObj['status'] as String? ?? 'pending';
        } else if (displayStatusObj is String) {
          derivedDisplayStatus = displayStatusObj;
        }
      }
    }

    return OsdOrder(
      id: json['id'] as String,
      callNumber: json['call_number'] as int?,
      tableNumber: json['table_number'] as int?,
      orderNumber: json['order_number'] as String?,
      diningOption: json['dining_option'] as String?,
      displayStatus: derivedDisplayStatus,
      kitchenStatus: json['kitchen_status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      kitchenCompletedAt: json['kitchen_completed_at'] != null
          ? DateTime.parse(json['kitchen_completed_at'] as String)
          : null,
      servedAt: json['served_at'] != null
          ? DateTime.parse(json['served_at'] as String)
          : null,
    );
  }

  /// Create from WebSocket event data
  factory OsdOrder.fromWebSocketEvent(Map<String, dynamic> data) {
    // WebSocket events may have different field names
    // Try to get displayStatus from various possible field names
    String derivedDisplayStatus = 'pending';

    // Check for display_status in order_items (if present)
    final orderItems = data['order_items'] ?? data['orderItems'];
    if (orderItems is List && orderItems.isNotEmpty) {
      final firstItem = orderItems[0] as Map<String, dynamic>?;
      if (firstItem != null) {
        final displayStatusObj = firstItem['display_status'] ?? firstItem['displayStatus'];
        if (displayStatusObj is Map<String, dynamic>) {
          derivedDisplayStatus = (displayStatusObj['status'] as String?) ?? 'pending';
        } else if (displayStatusObj is String) {
          derivedDisplayStatus = displayStatusObj;
        }
      }
    } else {
      // Fallback: use displayStatus or kitchen_status from the event data
      derivedDisplayStatus = (data['displayStatus'] ??
              data['display_status'] ??
              data['kitchenStatus'] ??
              data['kitchen_status'] ??
              'pending') as String;
    }

    return OsdOrder(
      id: (data['orderId'] ?? data['order_id'] ?? data['id']) as String,
      callNumber:
          (data['callNumber'] ?? data['call_number']) as int?,
      tableNumber:
          (data['tableNumber'] ?? data['table_number']) as int?,
      orderNumber:
          (data['orderNumber'] ?? data['order_number']) as String?,
      diningOption:
          (data['diningOption'] ?? data['dining_option']) as String?,
      displayStatus: derivedDisplayStatus,
      kitchenStatus:
          (data['kitchenStatus'] ?? data['kitchen_status']) as String?,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : (data['created_at'] != null
              ? DateTime.parse(data['created_at'] as String)
              : DateTime.now()),
      kitchenCompletedAt: (data['kitchenCompletedAt'] ??
                  data['kitchen_completed_at']) !=
              null
          ? DateTime.parse((data['kitchenCompletedAt'] ??
              data['kitchen_completed_at']) as String)
          : null,
      servedAt: (data['servedAt'] ?? data['served_at']) != null
          ? DateTime.parse(
              (data['servedAt'] ?? data['served_at']) as String)
          : null,
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
