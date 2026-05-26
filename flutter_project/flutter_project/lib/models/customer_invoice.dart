class CustomerInvoice {
  final int? id;
  final int customerId;
  final String invoiceNo;
  final double total;
  final String paymentMethod;
  final String? receiptPath;
  final String status;
  final String? notes;
  final String date;
  final String createdAt;
  final List<CustomerInvoiceItem> items;
  final double? discount;
  final double? amountPaid;
  final double? remaining;
  // Joined from customers table
  final String? customerName;
  final String? customerPhone;
  final String? customerStoreType;

  CustomerInvoice({
    this.id,
    required this.customerId,
    required this.invoiceNo,
    this.total = 0,
    this.paymentMethod = 'in_store',
    this.receiptPath,
    this.status = 'pending',
    this.notes,
    required this.date,
    required this.createdAt,
    this.items = const [],
    this.discount,
    this.amountPaid,
    this.remaining,
    this.customerName,
    this.customerPhone,
    this.customerStoreType,
  });

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'delivered':
        return 'تم التسليم';
      default:
        return 'في الانتظار';
    }
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'vodafone_cash':
        return 'فودافون كاش';
      case 'instapay':
        return 'إنستاباي';
      case 'bank_transfer':
        return 'تحويل بنكي';
      default:
        return 'دفع عند الاستلام';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_id': customerId,
        'store_type': customerStoreType,
        'invoice_no': invoiceNo,
        'total': total,
        'payment_method': paymentMethod,
        'receipt_path': receiptPath,
        'status': status,
        'notes': notes,
        'date': date,
        'created_at': createdAt,
        'discount': discount,
        'amount_paid': amountPaid,
        'remaining': remaining,
      };

  factory CustomerInvoice.fromMap(Map<String, dynamic> m) => CustomerInvoice(
        id: m['id'] as int?,
        customerId: m['customer_id'] as int,
        invoiceNo: m['invoice_no'] as String,
        total: (m['total'] as num? ?? 0).toDouble(),
        paymentMethod: m['payment_method'] as String? ?? 'in_store',
        receiptPath: m['receipt_path'] as String?,
        status: m['status'] as String? ?? 'pending',
        notes: m['notes'] as String?,
        date: m['date'] as String,
        createdAt: m['created_at'] as String,
        discount: (m['discount'] as num?)?.toDouble(),
        amountPaid: (m['amount_paid'] as num?)?.toDouble(),
        remaining: (m['remaining'] as num?)?.toDouble(),
        customerName: m['customer_name'] as String?,
        customerPhone: m['customer_phone'] as String?,
        customerStoreType:
            m['customer_store_type'] as String? ?? m['store_type'] as String?,
      );

  CustomerInvoice copyWith({
    String? status,
    double? discount,
    double? amountPaid,
    double? remaining,
  }) =>
      CustomerInvoice(
        id: id,
        customerId: customerId,
        invoiceNo: invoiceNo,
        total: total,
        paymentMethod: paymentMethod,
        receiptPath: receiptPath,
        status: status ?? this.status,
        notes: notes,
        date: date,
        createdAt: createdAt,
        items: items,
        discount: discount ?? this.discount,
        amountPaid: amountPaid ?? this.amountPaid,
        remaining: remaining ?? this.remaining,
        customerName: customerName,
        customerPhone: customerPhone,
        customerStoreType: customerStoreType,
      );
}

class CustomerInvoiceItem {
  final int? id;
  final int? invoiceId;
  final int? itemId;
  final String itemName;
  final double qty;
  final double unitPrice;
  final double total;

  CustomerInvoiceItem({
    this.id,
    this.invoiceId,
    this.itemId,
    required this.itemName,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoice_id': invoiceId,
        'item_id': itemId,
        'item_name': itemName,
        'qty': qty,
        'unit_price': unitPrice,
        'total': total,
      };

  factory CustomerInvoiceItem.fromMap(Map<String, dynamic> m) =>
      CustomerInvoiceItem(
        id: m['id'] as int?,
        invoiceId: m['invoice_id'] as int?,
        itemId: m['item_id'] as int?,
        itemName: m['item_name'] as String,
        qty: (m['qty'] as num).toDouble(),
        unitPrice: (m['unit_price'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
      );
}
