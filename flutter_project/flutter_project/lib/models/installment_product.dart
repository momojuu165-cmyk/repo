bool _parseBool(dynamic v, {bool defaultValue = false}) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is int) return v == 1;
  return defaultValue;
}

// Feature 5: maxInstallmentMonths — admin-configurable per product
class InstallmentProduct {
  final int? id;
  final String name;
  final String? description;
  final String? imagePath;
  final List<String> imagePaths;
  final double purchasePrice;
  final double salePrice;
  final double cashPrice;
  final double installmentPrice;
  final bool showCashPrice;
  final bool showInstallmentPrice;
  final bool isAvailable;
  final String? category;
  final double profitRate;
  final String storeType;
  final int maxInstallmentMonths;
  final String createdAt;
  /// نسبة الشركة من كل عملية بيع أو قسط (يحددها الأدمن)
  final double companyPercentage;
  /// شريحة السعر: wholesale / semi_wholesale / retail
  final String? priceTier;

  InstallmentProduct({
    this.id,
    required this.name,
    this.description,
    this.imagePath,
    this.imagePaths = const [],
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.cashPrice = 0,
    this.installmentPrice = 0,
    this.showCashPrice = true,
    this.showInstallmentPrice = true,
    this.isAvailable = true,
    this.category,
    this.profitRate = 0.10,
    this.storeType = 'installment',
    this.maxInstallmentMonths = 24,
    required this.createdAt,
    this.companyPercentage = 0.0,
    this.priceTier,
  });

  double get profit => salePrice - purchasePrice;
  double get effectiveCashPrice => cashPrice > 0 ? cashPrice : salePrice;
  double get effectiveInstallmentPrice =>
      installmentPrice > 0 ? installmentPrice : salePrice * (1 + profitRate);
  double get installmentTotal => effectiveInstallmentPrice;
  double get profitRatePercent => profitRate * 100;

  double monthlyPayment(int months, {double deposit = 0}) {
    final total = effectiveInstallmentPrice - deposit;
    if (months <= 0) return total;
    return total / months;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'image_path': imagePath,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'cash_price': cashPrice,
        'installment_price': installmentPrice,
        'show_cash_price': showCashPrice,
        'show_installment_price': showInstallmentPrice,
        'is_available': isAvailable,
        'category': category,
        'profit_rate': profitRate,
        'store_type': storeType,
        'max_installment_months': maxInstallmentMonths,
        'created_at': createdAt,
        'company_percentage': companyPercentage,
        'price_tier': priceTier,
      };

  factory InstallmentProduct.fromMap(Map<String, dynamic> m) =>
      InstallmentProduct(
        id: m['id'] as int?,
        name: m['name'] as String,
        description: m['description'] as String?,
        imagePath: m['image_path'] as String?,
        purchasePrice: (m['purchase_price'] as num? ?? 0).toDouble(),
        salePrice: (m['sale_price'] as num? ?? 0).toDouble(),
        cashPrice: (m['cash_price'] as num? ?? 0).toDouble(),
        installmentPrice: (m['installment_price'] as num? ?? 0).toDouble(),
        showCashPrice: _parseBool(m['show_cash_price'], defaultValue: true),
        showInstallmentPrice: _parseBool(m['show_installment_price'], defaultValue: true),
        isAvailable: _parseBool(m['is_available'], defaultValue: true),
        category: m['category'] as String?,
        profitRate: (m['profit_rate'] as num? ?? 0.10).toDouble(),
        storeType: (m['store_type'] ?? 'installment').toString().trim().toLowerCase(),
        maxInstallmentMonths: (m['max_installment_months'] as int? ?? 24),
        createdAt: m['created_at'] as String,
        companyPercentage: (m['company_percentage'] as num? ?? 0).toDouble(),
        priceTier: m['price_tier'] as String?,
      );

  InstallmentProduct copyWith({
    int? id,
    String? name,
    String? description,
    String? imagePath,
    List<String>? imagePaths,
    double? purchasePrice,
    double? salePrice,
    double? cashPrice,
    double? installmentPrice,
    bool? showCashPrice,
    bool? showInstallmentPrice,
    bool? isAvailable,
    String? category,
    double? profitRate,
    String? storeType,
    int? maxInstallmentMonths,
    String? createdAt,
    double? companyPercentage,
    String? priceTier,
  }) =>
      InstallmentProduct(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        imagePath: imagePath ?? this.imagePath,
        imagePaths: imagePaths ?? this.imagePaths,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        salePrice: salePrice ?? this.salePrice,
        cashPrice: cashPrice ?? this.cashPrice,
        installmentPrice: installmentPrice ?? this.installmentPrice,
        showCashPrice: showCashPrice ?? this.showCashPrice,
        showInstallmentPrice: showInstallmentPrice ?? this.showInstallmentPrice,
        isAvailable: isAvailable ?? this.isAvailable,
        category: category ?? this.category,
        profitRate: profitRate ?? this.profitRate,
        storeType: storeType ?? this.storeType,
        maxInstallmentMonths: maxInstallmentMonths ?? this.maxInstallmentMonths,
        createdAt: createdAt ?? this.createdAt,
        companyPercentage: companyPercentage ?? this.companyPercentage,
        priceTier: priceTier ?? this.priceTier,
      );
}
