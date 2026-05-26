// Note: DB column is 'item_name' (not product_name) and 'total_price' (not total_installment_price).
// The Dart fields are kept as-is for API compatibility; only toMap/fromMap keys are updated.
class Installment {
  final int? id;
  final int customerId;
  final int? itemId;
  final int? invoiceId;
  final String productName;       // stored as item_name in DB
  final String? guarantorName;
  final String? guarantorPhone;
  final String? guarantorAddress;
  final double purchasePrice;
  final double salePrice;
  final double totalInstallmentPrice; // stored as total_price in DB
  final double downPayment;
  final int numInstallments;
  final double monthlyAmount;
  final String startDate;
  final String? endDate;
  final String status;
  final String createdAt;
  final String storeType; // 'installment' | 'electrical' | custom slug
  final int? partnerGroupId; // which group this sale belongs to
  final double? installmentRate; // configurable rate applied

  Installment({
    this.id,
    required this.customerId,
    this.itemId,
    this.invoiceId,
    required this.productName,
    this.guarantorName,
    this.guarantorPhone,
    this.guarantorAddress,
    required this.purchasePrice,
    required this.salePrice,
    required this.totalInstallmentPrice,
    this.downPayment = 0,
    required this.numInstallments,
    required this.monthlyAmount,
    required this.startDate,
    this.endDate,
    this.status = 'active',
    required this.createdAt,
    this.storeType = 'installment',
    this.partnerGroupId,
    this.installmentRate,
  });

  double get profit => salePrice - purchasePrice;
  double get remaining => totalInstallmentPrice - downPayment;

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_id': customerId,
        'item_id': itemId,
        'invoice_id': invoiceId,
        'item_name': productName,             // DB column: item_name
        'guarantor_name': guarantorName,
        'guarantor_phone': guarantorPhone,
        'guarantor_address': guarantorAddress,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'total_price': totalInstallmentPrice, // DB column: total_price
        'down_payment': downPayment,
        'remaining_amount': remaining,
        'num_installments': numInstallments,
        'monthly_amount': monthlyAmount,
        'start_date': startDate,
        'end_date': endDate,
        'status': status,
        'created_at': createdAt,
        'store_type': storeType,
        if (partnerGroupId != null) 'partner_group_id': partnerGroupId,
        if (installmentRate != null) 'installment_rate': installmentRate,
      };

  factory Installment.fromMap(Map<String, dynamic> m) => Installment(
        id: m['id'] as int?,
        customerId: m['customer_id'] as int,
        itemId: m['item_id'] as int?,
        invoiceId: m['invoice_id'] as int?,
        productName: (m['item_name'] ?? m['product_name'] ?? '') as String,
        guarantorName: m['guarantor_name'] as String?,
        guarantorPhone: m['guarantor_phone'] as String?,
        guarantorAddress: m['guarantor_address'] as String?,
        purchasePrice: (m['purchase_price'] as num? ?? 0).toDouble(),
        salePrice: (m['sale_price'] as num? ?? 0).toDouble(),
        totalInstallmentPrice:
            ((m['total_price'] ?? m['total_installment_price'] ?? 0) as num).toDouble(),
        downPayment: (m['down_payment'] as num? ?? 0).toDouble(),
        numInstallments: m['num_installments'] as int,
        monthlyAmount: (m['monthly_amount'] as num).toDouble(),
        startDate: m['start_date'] as String,
        endDate: m['end_date'] as String?,
        status: m['status'] as String? ?? 'active',
        createdAt: m['created_at'] as String,
        storeType: m['store_type'] as String? ?? 'installment',
        partnerGroupId: m['partner_group_id'] as int?,
        installmentRate: (m['installment_rate'] as num?)?.toDouble(),
      );
}

class InstallmentPayment {
  final int? id;
  final int installmentId;
  final String dueDate;
  final double amount;
  final String? paidDate;    // actual payment date
  final String? notes;
  final String status;       // pending | paid | overdue | postponed | partial
  final String? postponeReason;
  final double carriedAmount; // amount carried over from partial payment
  final double paidAmount;   // amount actually paid (for partial)

  InstallmentPayment({
    this.id,
    required this.installmentId,
    required this.dueDate,
    required this.amount,
    this.paidDate,
    this.notes,
    this.status = 'pending',
    this.postponeReason,
    this.carriedAmount = 0.0,
    this.paidAmount = 0.0,
  });

  bool get isPaid => status == 'paid';
  bool get isPostponed => status == 'postponed';
  bool get isPartial => status == 'partial';
  bool get isOverdue =>
      status == 'pending' && DateTime.now().isAfter(DateTime.parse(dueDate));

  /// Color for the payment status indicator
  static int statusColor(String status, String dueDate) {
    switch (status) {
      case 'paid':
        return 0xFF2E7D32; // green
      case 'postponed':
        return 0xFFF9A825; // amber/yellow
      case 'partial':
        return 0xFFE65100; // orange
      case 'overdue':
        return 0xFFB71C1C; // red
      default:
        // pending — check if overdue
        try {
          if (DateTime.now().isAfter(DateTime.parse(dueDate))) {
            return 0xFFB71C1C; // red (overdue pending)
          }
        } catch (_) {}
        return 0xFF546E7A; // blue-grey (upcoming)
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'installment_id': installmentId,
        'due_date': dueDate,
        'amount': amount,
        'paid_date': paidDate,
        'notes': notes,
        'status': status,
        'postpone_reason': postponeReason,
        'carried_amount': carriedAmount,
        'paid_amount': paidAmount,
      };

  factory InstallmentPayment.fromMap(Map<String, dynamic> m) =>
      InstallmentPayment(
        id: m['id'] as int?,
        installmentId: m['installment_id'] as int,
        dueDate: m['due_date'] as String,
        amount: (m['amount'] as num).toDouble(),
        paidDate: m['paid_date'] as String?,
        notes: m['notes'] as String?,
        status: m['status'] as String? ?? 'pending',
        postponeReason: m['postpone_reason'] as String?,
        carriedAmount: (m['carried_amount'] as num? ?? 0).toDouble(),
        paidAmount: (m['paid_amount'] as num? ?? 0).toDouble(),
      );

  InstallmentPayment copyWith({
    String? status,
    String? paidDate,
    String? postponeReason,
    double? carriedAmount,
    double? paidAmount,
  }) =>
      InstallmentPayment(
        id: id,
        installmentId: installmentId,
        dueDate: dueDate,
        amount: amount,
        paidDate: paidDate ?? this.paidDate,
        notes: notes,
        status: status ?? this.status,
        postponeReason: postponeReason ?? this.postponeReason,
        carriedAmount: carriedAmount ?? this.carriedAmount,
        paidAmount: paidAmount ?? this.paidAmount,
      );
}
