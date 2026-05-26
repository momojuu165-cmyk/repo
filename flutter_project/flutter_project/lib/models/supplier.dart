class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? email;
  final String? taxNumber;
  final String? section;
  final double balance;
  final double debt;
  final bool isActive;
  final String? notes;
  final String createdAt;

  Supplier({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.email,
    this.taxNumber,
    this.section,
    this.balance = 0.0,
    this.debt = 0.0,
    this.isActive = true,
    this.notes,
    required this.createdAt,
  });

  static bool _parseBool(dynamic v, {bool defaultValue = true}) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is int) return v != 0;
    return defaultValue;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'email': email,
        'tax_number': taxNumber,
        'section': section,
        'balance': balance,
        // Supabase column may be INTEGER or BOOLEAN — send int to be safe
        'is_active': isActive ? 1 : 0,
        'notes': notes,
        'created_at': createdAt,
      };

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        address: m['address'] as String?,
        email: m['email'] as String?,
        taxNumber: m['tax_number'] as String?,
        section: m['section'] as String?,
        balance: (m['balance'] as num? ?? 0).toDouble(),
        debt: (m['debt'] as num? ?? 0).toDouble(),
        isActive: _parseBool(m['is_active']),
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? email,
    String? taxNumber,
    String? section,
    double? balance,
    double? debt,
    bool? isActive,
    String? notes,
    String? createdAt,
  }) =>
      Supplier(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        email: email ?? this.email,
        taxNumber: taxNumber ?? this.taxNumber,
        section: section ?? this.section,
        balance: balance ?? this.balance,
        debt: debt ?? this.debt,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
}

class SupplierProduct {
  final int? id;
  final int supplierId;
  final String productName;
  final double unitPrice;
  final String? unit;
  final String? notes;
  final String lastSuppliedAt;

  SupplierProduct({
    this.id,
    required this.supplierId,
    required this.productName,
    required this.unitPrice,
    this.unit,
    this.notes,
    required this.lastSuppliedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplier_id': supplierId,
        'product_name': productName,
        'unit_price': unitPrice,
        'unit': unit,
        'notes': notes,
        'last_supplied_at': lastSuppliedAt,
      };

  factory SupplierProduct.fromMap(Map<String, dynamic> m) => SupplierProduct(
        id: m['id'] as int?,
        supplierId: m['supplier_id'] as int,
        productName: m['product_name'] as String,
        unitPrice: (m['unit_price'] as num? ?? 0).toDouble(),
        unit: m['unit'] as String?,
        notes: m['notes'] as String?,
        lastSuppliedAt: m['last_supplied_at'] as String,
      );
}

class SupplierReceipt {
  final int? id;
  final int supplierId;
  final String date;
  final String? notes;
  final String? imagePath;
  final String createdAt;

  SupplierReceipt({
    this.id,
    required this.supplierId,
    required this.date,
    this.notes,
    this.imagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplier_id': supplierId,
        'date': date,
        'notes': notes,
        'image_path': imagePath,
        'created_at': createdAt,
      };

  factory SupplierReceipt.fromMap(Map<String, dynamic> m) => SupplierReceipt(
        id: m['id'] as int?,
        supplierId: m['supplier_id'] as int,
        date: m['date'] as String,
        notes: m['notes'] as String?,
        imagePath: m['image_path'] as String?,
        createdAt: m['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );
}
