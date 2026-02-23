/// OSD Display model
/// Represents a display device for Order Status Display system
/// Uses display_category_presets table (unified model for KDS/SDS/OSD)
class OsdDisplay {
  final String id;
  final String name;
  final String? storeId;
  final String? storeName;
  final String? organizationId;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OsdDisplay({
    required this.id,
    required this.name,
    this.storeId,
    this.storeName,
    this.organizationId,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory OsdDisplay.fromJson(Map<String, dynamic> json) {
    // Extract store info from nested store object or direct store_name field
    String? storeName;
    final storeData = json['store'];
    if (storeData is Map<String, dynamic>) {
      storeName = storeData['name'] as String?;
    }
    storeName ??= json['store_name'] as String?;

    return OsdDisplay(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed Display',
      storeId: json['store_id'] as String?,
      storeName: storeName,
      organizationId: json['organization_id'] as String?,
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'store_id': storeId,
      'store_name': storeName,
      'organization_id': organizationId,
      'active': active,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'OsdDisplay(id: $id, name: $name, store: $storeName)';
  }
}
