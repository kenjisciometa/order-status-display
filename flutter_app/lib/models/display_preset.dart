/// Display Preset model (unified model for KDS/SDS/OSD)
/// Replaces kitchen_displays / server_displays / osd_display with display_category_presets
/// Presets are shared across all display types
class DisplayPreset {
  final String id;
  final String name;
  final String? storeId;
  final String? storeName;
  final String? organizationId;
  final String? description;
  final List<DisplayCategory> categories;
  final List<String> categoryIds;
  final bool isDefault;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DisplayPreset({
    required this.id,
    required this.name,
    this.storeId,
    this.storeName,
    this.organizationId,
    this.description,
    this.categories = const [],
    this.categoryIds = const [],
    this.isDefault = false,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory DisplayPreset.fromJson(Map<String, dynamic> json) {
    // Parse categories from preset data
    List<DisplayCategory> categories = [];
    final categoriesData = json['categories'];

    if (categoriesData is List) {
      for (final item in categoriesData) {
        if (item is Map<String, dynamic>) {
          categories.add(DisplayCategory.fromJson(item));
        } else if (item is String) {
          // If it's just an ID, create a category with unknown name
          categories.add(DisplayCategory(id: item, name: 'Unknown'));
        }
      }
    }

    // Parse category_ids array
    List<String> categoryIds = [];
    final categoryIdsData = json['category_ids'];
    if (categoryIdsData is List) {
      categoryIds = categoryIdsData.map((e) => e.toString()).toList();
    }

    // Extract store info from nested store object or direct store_name field
    String? storeName;
    final storeData = json['store'];
    if (storeData is Map<String, dynamic>) {
      storeName = storeData['name'] as String?;
    }
    storeName ??= json['store_name'] as String?;

    return DisplayPreset(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed Display',
      storeId: json['store_id'] as String?,
      storeName: storeName,
      organizationId: json['organization_id'] as String?,
      description: json['description'] as String?,
      categories: categories,
      categoryIds: categoryIds,
      isDefault: json['is_default'] as bool? ?? false,
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
      'description': description,
      'category_ids': categoryIds,
      'categories': categories.map((c) => c.toJson()).toList(),
      'is_default': isDefault,
      'active': active,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Get category names as a comma-separated string
  String get categoryNames {
    if (categories.isEmpty) return 'すべて';
    return categories.map((c) => c.name).join(', ');
  }

  @override
  String toString() {
    return 'DisplayPreset(id: $id, name: $name, store: $storeName, categories: ${categories.length})';
  }
}

/// Display category model
class DisplayCategory {
  final String id;
  final String name;
  final String? description;
  final String? color;
  final bool isActive;

  const DisplayCategory({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.isActive = true,
  });

  factory DisplayCategory.fromJson(Map<String, dynamic> json) {
    return DisplayCategory(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      description: json['description'] as String?,
      color: json['color'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'is_active': isActive,
    };
  }

  @override
  String toString() {
    return 'DisplayCategory(id: $id, name: $name)';
  }
}
