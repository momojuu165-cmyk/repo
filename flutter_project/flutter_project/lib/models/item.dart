bool _parseBool(dynamic v, {bool defaultValue = false}) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is int) return v == 1;
  return defaultValue;
}

class Item {
  final int? id;
  final String? barcode;
  final String name;
  final int? groupId;
  final int? warehouseId;
  final double priceWholesale;
  final double priceSemiWholesale;
  final double priceRetail;
  final double priceSpecial;
  final double purchasePrice;
  final double cashPrice;
  final bool showCashPrice;
  final bool showInstallmentPrice;
  final double quantity;
  final String? unit;
  final String? category;
  final String? warrantyDate;
  final String? warrantyType;
  final String? notes;
  final String? imagePath;
  final List<String> imagePaths;
  final bool isBlocked;
  final String storeType;
  final double discountRate;
  final String createdAt;

  Item({
    this.id,
    this.barcode,
    required this.name,
    this.groupId,
    this.warehouseId,
    this.priceWholesale = 0,
    this.priceSemiWholesale = 0,
    this.priceRetail = 0,
    this.priceSpecial = 0,
    this.purchasePrice = 0,
    this.cashPrice = 0,
    this.showCashPrice = true,
    this.showInstallmentPrice = true,
    this.quantity = 0,
    this.unit,
    this.category,
    this.warrantyDate,
    this.warrantyType,
    this.notes,
    this.imagePath,
    this.imagePaths = const [],
    this.isBlocked = false,
    this.storeType = 'electrical',
    this.discountRate = 0,
    required this.createdAt,
  });

  double priceForType(String priceType) {
    double base;
    switch (priceType) {
      case 'wholesale':
        base = priceWholesale;
        break;
      case 'semi_wholesale':
        base = priceSemiWholesale;
        break;
      case 'special':
        base = priceSpecial;
        break;
      default:
        base = priceRetail;
    }
    if (discountRate > 0) {
      base = base * (1 - discountRate / 100);
    }
    return base;
  }

  double get discountedRetail => priceRetail * (1 - discountRate / 100);
  double get effectiveCashPrice => cashPrice > 0 ? cashPrice : priceRetail;
  double get salePrice => priceRetail;

  Map<String, dynamic> toMap() => {
        'id': id,
        'barcode': barcode,
        'name': name,
        'group_id': groupId,
        'warehouse_id': warehouseId,
        'price_wholesale': priceWholesale,
        'price_semi_wholesale': priceSemiWholesale,
        'price_retail': priceRetail,
        'price_special': priceSpecial,
        'purchase_price': purchasePrice,
        'cash_price': cashPrice,
        'show_cash_price': showCashPrice,
        'show_installment_price': showInstallmentPrice,
        'quantity': quantity,
        'unit': unit,
        'category': category,
        'warranty_date': warrantyDate,
        'warranty_type': warrantyType,
        'notes': notes,
        'image_path': imagePath,
        'is_blocked': isBlocked,
        'store_type': storeType,
        'discount_rate': discountRate,
        'created_at': createdAt,
      };

  factory Item.fromMap(Map<String, dynamic> m) => Item(
        id: m['id'] as int?,
        barcode: m['barcode'] as String?,
        name: m['name'] as String,
        groupId: m['group_id'] as int?,
        warehouseId: m['warehouse_id'] as int?,
        priceWholesale: (m['price_wholesale'] as num? ?? 0).toDouble(),
        priceSemiWholesale:
            (m['price_semi_wholesale'] as num? ?? 0).toDouble(),
        priceRetail: (m['price_retail'] as num? ?? 0).toDouble(),
        priceSpecial: (m['price_special'] as num? ?? 0).toDouble(),
        purchasePrice: (m['purchase_price'] as num? ?? 0).toDouble(),
        cashPrice: (m['cash_price'] as num? ?? 0).toDouble(),
        showCashPrice: _parseBool(m['show_cash_price'], defaultValue: true),
        showInstallmentPrice: _parseBool(m['show_installment_price'], defaultValue: true),
        quantity: (m['quantity'] as num? ?? 0).toDouble(),
        unit: m['unit'] as String?,
        category: m['category'] as String?,
        warrantyDate: m['warranty_date'] as String?,
        warrantyType: m['warranty_type'] as String?,
        notes: m['notes'] as String?,
        imagePath: m['image_path'] as String?,
        isBlocked: _parseBool(m['is_blocked']),
        storeType: (m['store_type'] ?? 'electrical').toString().trim().toLowerCase(),
        discountRate: (m['discount_rate'] as num? ?? 0).toDouble(),
        createdAt: m['created_at'] as String,
      );

  Item copyWith({
    int? id,
    String? barcode,
    String? name,
    int? groupId,
    int? warehouseId,
    double? priceWholesale,
    double? priceSemiWholesale,
    double? priceRetail,
    double? priceSpecial,
    double? purchasePrice,
    double? cashPrice,
    bool? showCashPrice,
    bool? showInstallmentPrice,
    double? quantity,
    String? unit,
    String? category,
    String? warrantyDate,
    String? warrantyType,
    String? notes,
    String? imagePath,
    List<String>? imagePaths,
    bool? isBlocked,
    String? storeType,
    double? discountRate,
    String? createdAt,
  }) =>
      Item(
        id: id ?? this.id,
        barcode: barcode ?? this.barcode,
        name: name ?? this.name,
        groupId: groupId ?? this.groupId,
        warehouseId: warehouseId ?? this.warehouseId,
        priceWholesale: priceWholesale ?? this.priceWholesale,
        priceSemiWholesale: priceSemiWholesale ?? this.priceSemiWholesale,
        priceRetail: priceRetail ?? this.priceRetail,
        priceSpecial: priceSpecial ?? this.priceSpecial,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        cashPrice: cashPrice ?? this.cashPrice,
        showCashPrice: showCashPrice ?? this.showCashPrice,
        showInstallmentPrice: showInstallmentPrice ?? this.showInstallmentPrice,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        category: category ?? this.category,
        warrantyDate: warrantyDate ?? this.warrantyDate,
        warrantyType: warrantyType ?? this.warrantyType,
        notes: notes ?? this.notes,
        imagePath: imagePath ?? this.imagePath,
        imagePaths: imagePaths ?? this.imagePaths,
        isBlocked: isBlocked ?? this.isBlocked,
        storeType: storeType ?? this.storeType,
        discountRate: discountRate ?? this.discountRate,
        createdAt: createdAt ?? this.createdAt,
      );
}
