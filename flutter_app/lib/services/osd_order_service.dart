import 'package:flutter/foundation.dart';
import '../models/osd_order.dart';
import '../config/api_endpoints.dart';
import 'api_client_service.dart';
import 'auth_service.dart';

/// OSD Order Service
///
/// Service for fetching orders from the KDS API.
/// Used for:
/// - Initial data load on app start
/// - Recovery after WebSocket disconnection
/// - Manual refresh
///
/// OSD reuses the KDS API (`/api/kds/orders`) for order data.
class OsdOrderService {
  static OsdOrderService? _instance;
  static OsdOrderService get instance {
    _instance ??= OsdOrderService._internal();
    return _instance!;
  }

  OsdOrderService._internal();

  final ApiClientService _apiClient = ApiClientService.instance;
  final AuthService _authService = AuthService.instance;

  /// Fetch all active orders for a store
  ///
  /// Returns orders with display_status in ['pending', 'ready'].
  /// Orders with 'served' status are excluded as they should not be displayed.
  Future<List<OsdOrder>> fetchActiveOrders(String storeId) async {
    try {
      final organizationId = _authService.currentUser?.organizationId;

      // Validate organizationId - check for null AND empty string
      if (organizationId == null || organizationId.isEmpty) {
        debugPrint('❌ [OSD ORDER SERVICE] No organization ID available');
        debugPrint('   Current user: ${_authService.currentUser}');
        debugPrint('   Organization ID value: "$organizationId"');
        return [];
      }

      // Validate storeId
      if (storeId.isEmpty) {
        debugPrint('❌ [OSD ORDER SERVICE] No store ID provided');
        return [];
      }

      debugPrint('📥 [OSD ORDER SERVICE] Fetching active orders for store: $storeId');
      debugPrint('   Organization ID: $organizationId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.osdOrders,
        queryParameters: {
          'organization_id': organizationId,
          'store_id': storeId,
          // Request orders that should be displayed on OSD
          // API uses 'status' parameter (not 'kitchen_status') to filter by display_status.status
          'status': ['pending', 'ready'].join(','),
        },
      );

      if (response.success && response.data != null) {
        final ordersData = response.data!['orders'] as List<dynamic>? ??
            response.data!['data'] as List<dynamic>?;

        if (ordersData != null) {
          final orders = ordersData
              .map((json) => OsdOrder.fromJson(json as Map<String, dynamic>))
              .toList();

          debugPrint('✅ [OSD ORDER SERVICE] Fetched ${orders.length} active orders');

          // Log order breakdown
          final nowCooking = orders.where((o) => o.isNowCooking).length;
          final ready = orders.where((o) => o.isReady).length;
          debugPrint('   📊 Now Cooking: $nowCooking, Ready: $ready');

          return orders;
        }
      }

      debugPrint('⚠️ [OSD ORDER SERVICE] No orders found or request failed');
      debugPrint('   Response: ${response.message}');
      return [];
    } catch (e) {
      debugPrint('❌ [OSD ORDER SERVICE] Error fetching orders: $e');
      return [];
    }
  }

  /// Fetch orders that are in "Now Cooking" status
  ///
  /// Returns orders with display_status = 'pending'.
  Future<List<OsdOrder>> fetchNowCookingOrders(String storeId) async {
    try {
      final organizationId = _authService.currentUser?.organizationId;

      // Validate organizationId - check for null AND empty string
      if (organizationId == null || organizationId.isEmpty) {
        debugPrint('❌ [OSD ORDER SERVICE] No organization ID available');
        return [];
      }

      // Validate storeId
      if (storeId.isEmpty) {
        debugPrint('❌ [OSD ORDER SERVICE] No store ID provided');
        return [];
      }

      debugPrint('📥 [OSD ORDER SERVICE] Fetching "Now Cooking" orders');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.osdOrders,
        queryParameters: {
          'organization_id': organizationId,
          'store_id': storeId,
          // API uses 'status' parameter to filter by display_status.status
          'status': 'pending',
        },
      );

      if (response.success && response.data != null) {
        final ordersData = response.data!['orders'] as List<dynamic>? ??
            response.data!['data'] as List<dynamic>?;

        if (ordersData != null) {
          final orders = ordersData
              .map((json) => OsdOrder.fromJson(json as Map<String, dynamic>))
              .toList();

          debugPrint('✅ [OSD ORDER SERVICE] Fetched ${orders.length} "Now Cooking" orders');
          return orders;
        }
      }

      return [];
    } catch (e) {
      debugPrint('❌ [OSD ORDER SERVICE] Error fetching "Now Cooking" orders: $e');
      return [];
    }
  }

  /// Fetch orders that are "Ready" for pickup
  ///
  /// Returns orders with display_status = 'ready'.
  Future<List<OsdOrder>> fetchReadyOrders(String storeId) async {
    try {
      final organizationId = _authService.currentUser?.organizationId;

      // Validate organizationId - check for null AND empty string
      if (organizationId == null || organizationId.isEmpty) {
        debugPrint('❌ [OSD ORDER SERVICE] No organization ID available');
        return [];
      }

      // Validate storeId
      if (storeId.isEmpty) {
        debugPrint('❌ [OSD ORDER SERVICE] No store ID provided');
        return [];
      }

      debugPrint('📥 [OSD ORDER SERVICE] Fetching "Ready" orders');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.osdOrders,
        queryParameters: {
          'organization_id': organizationId,
          'store_id': storeId,
          // API uses 'status' parameter to filter by display_status.status
          'status': 'ready',
        },
      );

      if (response.success && response.data != null) {
        final ordersData = response.data!['orders'] as List<dynamic>? ??
            response.data!['data'] as List<dynamic>?;

        if (ordersData != null) {
          final orders = ordersData
              .map((json) => OsdOrder.fromJson(json as Map<String, dynamic>))
              .toList();

          debugPrint('✅ [OSD ORDER SERVICE] Fetched ${orders.length} "Ready" orders');
          return orders;
        }
      }

      return [];
    } catch (e) {
      debugPrint('❌ [OSD ORDER SERVICE] Error fetching "Ready" orders: $e');
      return [];
    }
  }

  /// Get a single order by ID
  Future<OsdOrder?> getOrderById(String orderId) async {
    try {
      final organizationId = _authService.currentUser?.organizationId;

      // Validate organizationId - check for null AND empty string
      if (organizationId == null || organizationId.isEmpty) {
        debugPrint('❌ [OSD ORDER SERVICE] No organization ID available');
        return null;
      }

      debugPrint('📥 [OSD ORDER SERVICE] Fetching order: $orderId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiEndpoints.osdOrders}/$orderId',
        queryParameters: {
          'organization_id': organizationId,
        },
      );

      if (response.success && response.data != null) {
        final orderData = response.data!['order'] as Map<String, dynamic>? ??
            response.data!;
        return OsdOrder.fromJson(orderData);
      }

      return null;
    } catch (e) {
      debugPrint('❌ [OSD ORDER SERVICE] Error fetching order $orderId: $e');
      return null;
    }
  }

  /// Check health of the API
  Future<bool> checkHealth() async {
    try {
      final organizationId = _authService.currentUser?.organizationId;

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.osdHealth,
        queryParameters: organizationId != null
            ? {'organization_id': organizationId}
            : null,
      );

      return response.success;
    } catch (e) {
      debugPrint('❌ [OSD ORDER SERVICE] Health check failed: $e');
      return false;
    }
  }
}
