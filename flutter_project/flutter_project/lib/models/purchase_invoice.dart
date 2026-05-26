class PurchaseInvoice {
  final int? id;
  final String invoiceNo;
  final int? supplierId;
  final int? warehouseId;
  final String date;
  final double total;
  final double discount;
  final String currency;
  final String? notes;
  final String status;
  final String createdAt;

  PurchaseInvoice({
    this.id,
    required this.invoiceNo,
    this.supplierId,
    this.warehouseId,
    required this.date,
    this.total = 0,
    this.discount = 0,
    this.currency = 'EGP',
    this.notes,
    this.status = 'completed',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoice_no': invoiceNo,
        'supplier_id': supplierId,
        'warehouse_id': warehouseId,
        'date': date,
        'total': total,
        'discount': discount,
        'currency': currency,
        'notes': notes,
        'status': status,
        'created_at': createdAt,
      };

  factory PurchaseInvoice.fromMap(Map<String, dynamic> m) => PurchaseInvoice(
        id: m['id'] as int?,
        invoiceNo: m['invoice_no'] as String,
        supplierId: m['supplier_id'] as int?,
        warehouseId: m['warehouse_id'] as int?,
        date: m['date'] as String,
        total: (m['total'] as num? ?? 0).toDouble(),
        discount: (m['discount'] as num? ?? 0).toDouble(),
        currency: m['currency'] as String? ?? 'EGP',
        notes: m['notes'] as String?,
        status: m['status'] as String? ?? 'completed',
        createdAt: m['created_at'] as String,
      );
}

class PurchaseInvoiceItem {
  final int? id;
  final int invoiceId;
  final int? itemId;
  final String itemName;
  final String? barcode;
  final double qty;
  final double unitCost;
  final double discount;
  final double total;

  PurchaseInvoiceItem({
    this.id,
    required this.invoiceId,
    this.itemId,
    required this.itemName,
    this.barcode,
    required this.qty,
    required this.unitCost,
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
        'unit_cost': unitCost,
        'discount': discount,
        'total': total,
      };

  factory PurchaseInvoiceItem.fromMap(Map<String, dynamic> m) =>
      PurchaseInvoiceItem(
        id: m['id'] as int?,
        invoiceId: m['invoice_id'] as int,
        itemId: m['item_id'] as int?,
        itemName: m['item_name'] as String,
        barcode: m['barcode'] as String?,
        qty: (m['qty'] as num).toDouble(),
        unitCost: (m['unit_cost'] as num).toDouble(),
        discount: (m['discount'] as num? ?? 0).toDouble(),
        total: (m['total'] as num).toDouble(),
      );
}
