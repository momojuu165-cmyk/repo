bool _parseBool(dynamic v, {bool defaultValue = false}) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is int) return v == 1;
  return defaultValue;
}

class ElectricalBundle {
    final int? id;
    final String name;
    final String? description;
    final double discountRate;
    final bool isActive;
    final String createdAt;
    final List<ElectricalBundleItem> items;

    ElectricalBundle({
      this.id,
      required this.name,
      this.description,
      this.discountRate = 0,
      this.isActive = true,
      required this.createdAt,
      this.items = const [],
    });

    double get totalOriginalPrice => items.fold(0, (s, i) => s + i.originalPrice);
    double get totalDiscountedPrice => totalOriginalPrice * (1 - discountRate / 100);
    double get savings => totalOriginalPrice - totalDiscountedPrice;

    Map<String, dynamic> toMap() => {
      'id': id, 'name': name, 'description': description,
      'discount_rate': discountRate, 'is_active': isActive, 'created_at': createdAt,
    };

    factory ElectricalBundle.fromMap(Map<String, dynamic> m) => ElectricalBundle(
      id: m['id'] as int?,
      name: m['name'] as String,
      description: m['description'] as String?,
      discountRate: (m['discount_rate'] as num? ?? 0).toDouble(),
      isActive: _parseBool(m['is_active'], defaultValue: true),
      createdAt: m['created_at'] as String,
    );
  }

  class ElectricalBundleItem {
    final int? id;
    final int bundleId;
    final int? itemId;
    final String itemName;
    final double originalPrice;
    final String? imagePath;

    ElectricalBundleItem({
      this.id,
      required this.bundleId,
      this.itemId,
      required this.itemName,
      required this.originalPrice,
      this.imagePath,
    });

    Map<String, dynamic> toMap() {
      final m = <String, dynamic>{
        'id': id, 'bundle_id': bundleId,
        'item_name': itemName, 'original_price': originalPrice,
        'image_path': imagePath,
      };
      if (itemId != null) m['item_id'] = itemId;
      return m;
    }

    factory ElectricalBundleItem.fromMap(Map<String, dynamic> m) => ElectricalBundleItem(
      id: m['id'] as int?,
      bundleId: m['bundle_id'] as int,
      itemId: m['item_id'] as int?,
      itemName: m['item_name'] as String,
      originalPrice: (m['original_price'] as num).toDouble(),
      imagePath: m['image_path'] as String?,
    );
  }
