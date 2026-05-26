class ItemGroup {
  final int? id;
  final String name;
  final int? parentId;
  final String storeType;

  ItemGroup({
    this.id,
    required this.name,
    this.parentId,
    this.storeType = 'electrical',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parent_id': parentId,
        'store_type': storeType,
      };

  factory ItemGroup.fromMap(Map<String, dynamic> m) => ItemGroup(
        id: m['id'] as int?,
        name: m['name'] as String,
        parentId: m['parent_id'] as int?,
        storeType: m['store_type'] as String? ?? 'electrical',
      );
}
