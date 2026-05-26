bool _parseBool(dynamic v, {bool defaultValue = false}) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is int) return v == 1;
  if (v is num) return v != 0;
  if (v is String) {
    final lower = v.toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') {
      return true;
    }
    if (lower == 'false' || lower == '0' || lower == 'no') {
      return false;
    }
  }
  return defaultValue;
}

class Department {
  final int? id;
  final String name;
  final String storeType;
  final String? description;
  final bool isActive;
  final bool isSystem;
  final String createdAt;

  Department({
    this.id,
    required this.name,
    required this.storeType,
    this.description,
    this.isActive = true,
    this.isSystem = false,
    required this.createdAt,
  });

  factory Department.fromMap(Map<String, dynamic> m) => Department(
        id: m['id'] as int?,
        name: (m['name'] ?? '').toString().trim(),
        storeType: (m['store_type'] ?? '').toString().trim().toLowerCase(),
        description: m['description']?.toString(),
        isActive: _parseBool(m['is_active'], defaultValue: true),
        isSystem: _parseBool(m['is_system'], defaultValue: false),
        createdAt: m['created_at']?.toString() ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'store_type': storeType,
        'description': description,
        'is_active': isActive,
        'is_system': isSystem,
        'created_at': createdAt,
      };

  Department copyWith({
    int? id,
    String? name,
    String? storeType,
    String? description,
    bool? isActive,
    bool? isSystem,
    String? createdAt,
  }) =>
      Department(
        id: id ?? this.id,
        name: name ?? this.name,
        storeType: storeType ?? this.storeType,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        isSystem: isSystem ?? this.isSystem,
        createdAt: createdAt ?? this.createdAt,
      );
}
