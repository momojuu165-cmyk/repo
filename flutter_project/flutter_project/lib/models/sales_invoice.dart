class SalesInvoice {
  final int? id;
  final String invoiceNo;
  final int? customerId;
  final int? employeeId;
  final String date;
  final double subtotal;
  final double discount;
  final double total;
  final String paymentType;
  final double amountPaid;
  final double remaining;
  final String status;
  final String? notes;
  final String createdAt;

  SalesInvoice({
    this.id,
    required this.invoiceNo,
    this.customerId,
    this.employeeId,
    required this.date,
    this.subtotal = 0,
    this.discount = 0,
    this.total = 0,
    this.paymentType = 'cash',
    this.amountPaid = 0,
    this.remaining = 0,
    this.status = 'paid',
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoice_no': invoiceNo,
        'customer_id': customerId,
        'employee_id': employeeId,
        'date': date,
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'payment_type': paymentType,
        'amount_paid': amountPaid,
        'remaining': remaining,
        'status': status,
        'notes': notes,
        'created_at': createdAt,
      };

  factory SalesInvoice.fromMap(Map<String, dynamic> m) => SalesInvoice(
        id: m['id'] as int?,
        invoiceNo: m['invoice_no'] as String,
        customerId: m['customer_id'] as int?,
        employeeId: m['employee_id'] as int?,
        date: m['date'] as String,
        subtotal: (m['subtotal'] as num? ?? 0).toDouble(),
        discount: (m['discount'] as num? ?? 0).toDouble(),
        total: (m['total'] as num? ?? 0).toDouble(),
        paymentType: m['payment_type'] as String? ?? 'cash',
        amountPaid: (m['amount_paid'] as num? ?? 0).toDouble(),
        remaining: (m['remaining'] as num? ?? 0).toDouble(),
        status: m['status'] as String? ?? 'paid',
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as String,
      );
}

class SalesInvoiceItem {
  final int? id;
  final int invoiceId;
  final int itemId;
  final String itemName;
  final String? barcode;
  final double qty;
  final double costPrice;
  final String priceType;
  final double unitPrice;
  final double discount;
  final double total;

  SalesInvoiceItem({
    this.id,
    required this.invoiceId,
    required this.itemId,
    required this.itemName,
    this.barcode,
    required this.qty,
    this.costPrice = 0,
    this.priceType = 'retail',
    required this.unitPrice,
    this.discount = 0,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoice_id': invoiceId,
        'item_id': itemId,
        'item_name': itemName,
        'barcode': barcode,
        'qty': qty,
        'cost_price': costPrice,
        'price_type': priceType,
        'unit_price': unitPrice,
        'discount': discount,
        'total': total,
      };

  factory SalesInvoiceItem.fromMap(Map<String, dynamic> m) => SalesInvoiceItem(
        id: m['id'] as int?,
        invoiceId: m['invoice_id'] as int,
        itemId: m['item_id'] as int,
        itemName: m['item_name'] as String,
        barcode: m['barcode'] as String?,
        qty: (m['qty'] as num).toDouble(),
        costPrice: (m['cost_price'] as num? ?? 0).toDouble(),
        priceType: m['price_type'] as String? ?? 'retail',
        unitPrice: (m['unit_price'] as num).toDouble(),
        discount: (m['discount'] as num? ?? 0).toDouble(),
        total: (m['total'] as num).toDouble(),
      );
}
