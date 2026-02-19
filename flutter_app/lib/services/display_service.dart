import 'package:flutter/foundation.dart';
import '../config/api_endpoints.dart';
import 'api_client_service.dart';
import 'auth_service.dart';

/// Display model for OSD (Order Status Display)
class OsdDisplay {
  final String id;
  final String name;
  final String organizationId;
  final String? storeId;
  final String? storeName;
  final bool active;
  final List<String>? categories;
  final String? categoryPresetId;
  final String? categoryPresetName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OsdDisplay({
    required this.id,
    required this.name,
    required this.organizationId,
    this.storeId,
    this.storeName,
    this.active = true,
    this.categories,
    this.categoryPresetId,
    this.categoryPresetName,
    this.createdAt,
    this.updatedAt,
  });

  factory OsdDisplay.fromJson(Map<String, dynamic> json) {
    // Extract preset info from nested preset object
    String? categoryPresetId = json['category_preset_id'] as String?;
    String? categoryPresetName;
    final presetData = json['preset'];
    if (presetData is Map<String, dynamic>) {
      categoryPresetName = presetData['name'] as String?;
      categoryPresetId ??= presetData['id'] as String?;
    }

    return OsdDisplay(
      id: json['id'] as String,
      name: json['name'] as String,
      organizationId: json['organization_id'] as String,
      storeId: json['store_id'] as String?,
      storeName: json['store_name'] as String? ?? json['store']?['name'] as String?,
      active: json['active'] as bool? ?? true,
      categories: (json['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      categoryPresetId: categoryPresetId,
      categoryPresetName: categoryPresetName,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

/// Display Service for OSD
///
/// Manages display configuration including:
/// - Fetching available displays for the organization (from display_category_presets)
/// - Creating new OSD display registrations
/// - Updating display settings
class DisplayService {
  static DisplayService? _instance;
  static DisplayService get instance {
    _instance ??= DisplayService._internal();
    return _instance!;
  }

  DisplayService._internal();

  final ApiClientService _apiClient = ApiClientService.instance;
  final AuthService _authService = AuthService.instance;

  /// Fetch all available OSD displays for the organization
  ///
  /// Uses the display-category-presets API (unified display configuration)
  Future<List<OsdDisplay>> fetchDisplays({String? storeId}) async {
    try {
      final organizationId = _authService.currentUser?.organizationId;

      if (organizationId == null || organizationId.isEmpty) {
        debugPrint('❌ [DISPLAY SERVICE] No organization ID available');
        return [];
      }

      debugPrint('📥 [DISPLAY SERVICE] Fetching OSD displays for org: $organizationId');

      // Use display-category-presets API for OSD displays
      final queryParams = <String, String>{
        'organization_id': organizationId,
        'include_preset': 'true',
      };

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.osdDisplays,
        queryParameters: queryParams,
      );

      if (response.success && response.data != null) {
        final displaysData = response.data!['presets'] as List<dynamic>?;

        if (displaysData != null) {
          var displays = displaysData
              .map((json) => OsdDisplay.fromJson(json as Map<String, dynamic>))
              .where((d) => d.active) // Only active displays
              .toList();

          // Filter by store if specified
          if (storeId != null && storeId.isNotEmpty) {
            displays = displays.where((d) => d.storeId == storeId).toList();
          }

          debugPrint('✅ [DISPLAY SERVICE] Fetched ${displays.length} OSD displays');
          return displays;
        }
      }

      debugPrint('⚠️ [DISPLAY SERVICE] No displays found or request failed');
      debugPrint('   Response: ${response.message}');
      return [];
    } catch (e) {
      debugPrint('❌ [DISPLAY SERVICE] Error fetching displays: $e');
      return [];
    }
  }

  /// Get a specific display by ID
  Future<OsdDisplay?> getDisplayById(String displayId) async {
    try {
      debugPrint('📥 [DISPLAY SERVICE] Fetching display: $displayId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.osdDisplayById(displayId),
      );

      if (response.success && response.data != null) {
        final displayData = response.data!['preset'] as Map<String, dynamic>? ??
            response.data!;
        return OsdDisplay.fromJson(displayData);
      }

      return null;
    } catch (e) {
      debugPrint('❌ [DISPLAY SERVICE] Error fetching display $displayId: $e');
      return null;
    }
  }

  /// Create a new OSD display registration
  Future<OsdDisplay?> createDisplay({
    required String name,
    required String storeId,
    String? categoryPresetId,
    List<String>? categories,
  }) async {
    try {
      final organizationId = _authService.currentUser?.organizationId;

      if (organizationId == null || organizationId.isEmpty) {
        debugPrint('❌ [DISPLAY SERVICE] No organization ID available');
        return null;
      }

      debugPrint('📤 [DISPLAY SERVICE] Creating new OSD display: $name');

      final body = <String, dynamic>{
        'name': name,
        'organization_id': organizationId,
        'store_id': storeId,
        'active': true,
      };

      if (categoryPresetId != null) {
        body['category_preset_id'] = categoryPresetId;
      } else if (categories != null) {
        body['selectedCategories'] = categories;
      }

      // Use the display-category-presets endpoint for creating OSD displays
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.osdDisplays,
        data: body,
      );

      if (response.success && response.data != null) {
        // Try 'preset' (new API) or legacy keys for compatibility
        final displayData = response.data!['preset'] as Map<String, dynamic>? ??
            response.data!['kitchenDisplay'] as Map<String, dynamic>? ??
            response.data!['serverDisplay'] as Map<String, dynamic>? ??
            response.data!;
        debugPrint('✅ [DISPLAY SERVICE] Created new display: ${displayData['id']}');
        return OsdDisplay.fromJson(displayData);
      }

      debugPrint('⚠️ [DISPLAY SERVICE] Failed to create display: ${response.message}');
      return null;
    } catch (e) {
      debugPrint('❌ [DISPLAY SERVICE] Error creating display: $e');
      return null;
    }
  }
}
