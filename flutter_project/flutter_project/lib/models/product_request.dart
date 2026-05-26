class ProductRequest {
  final int? id;
  final int customerId;
  final int? itemId;
  final String productName;
  final double qty;
  final String status;
  final String paymentMethod;
  final String? receiptPath;
  final double adminDiscount;
  final double depositAmount;
  final int? numInstallments;
  final String date;
  final String? notes;
  final String createdAt;
  final String? storeType;

  ProductRequest({
    this.id,
    required this.customerId,
    this.itemId,
    required this.productName,
    this.qty = 1,
    this.status = 'pending',
    required this.paymentMethod,
    this.receiptPath,
    this.adminDiscount = 0,
    this.depositAmount = 0,
    this.numInstallments,
    required this.date,
    this.notes,
    required this.createdAt,
    this.storeType,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_id': customerId,
        'item_id': itemId,
        'product_name': productName,
        'qty': qty,
        'status': status,
        'payment_method': paymentMethod,
        'receipt_path': receiptPath,
        'admin_discount': adminDiscount,
        'deposit_amount': depositAmount,
        'num_installments': numInstallments,
        'date': date,
        'notes': notes,
        'created_at': createdAt,
        'store_type': storeType,
      };

  factory ProductRequest.fromMap(Map<String, dynamic> m) => ProductRequest(
        id: m['id'] as int?,
        customerId: m['customer_id'] as int,
        itemId: m['item_id'] as int?,
        productName: m['product_name'] as String,
        qty: (m['qty'] as num? ?? 1).toDouble(),
        status: m['status'] as String? ?? 'pending',
        paymentMethod: m['payment_method'] as String,
        receiptPath: m['receipt_path'] as String?,
        adminDiscount: (m['admin_discount'] as num? ?? 0).toDouble(),
        depositAmount: (m['deposit_amount'] as num? ?? 0).toDouble(),
        numInstallments: m['num_installments'] as int?,
        date: (m['date'] as String?) ??
            ((m['created_at'] as String?)?.substring(0, 10)) ??
            DateTime.now().toIso8601String().substring(0, 10),
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as String,
        storeType: m['store_type'] as String?,
      );

  ProductRequest copyWith({
    String? status,
    double? adminDiscount,
    String? receiptPath,
    String? storeType,
  }) =>
      ProductRequest(
        id: id,
        customerId: customerId,
        itemId: itemId,
        productName: productName,
        qty: qty,
        status: status ?? this.status,
        paymentMethod: paymentMethod,
        receiptPath: receiptPath ?? this.receiptPath,
        adminDiscount: adminDiscount ?? this.adminDiscount,
        depositAmount: depositAmount,
        numInstallments: numInstallments,
        date: date,
        notes: notes,
        createdAt: createdAt,
        storeType: storeType ?? this.storeType,
      );
}
