bool _parseBoolPL(dynamic v, {bool defaultValue = false}) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is int) return v == 1;
  return defaultValue;
}

class CustomerPointsLog {
  final int? id;
  final int customerId;
  final int? invoiceId;
  final String invoiceNo;
  final String date;
  final int pointsEarned;
  final double pointValue;
  final String pointCurrency;
  final bool isSettled;
  final String? settledAt;
  final String? notes;
  final String createdAt;

  const CustomerPointsLog({
    this.id,
    required this.customerId,
    this.invoiceId,
    required this.invoiceNo,
    required this.date,
    required this.pointsEarned,
    this.pointValue = 1.0,
    this.pointCurrency = 'piasters',
    this.isSettled = false,
    this.settledAt,
    this.notes,
    required this.createdAt,
  });

  double get valueInEgp =>
      pointCurrency == 'piasters' ? pointValue / 100.0 : pointValue;

  double get totalValueEgp => pointsEarned * valueInEgp;

  String get currencyLabel => pointCurrency == 'piasters' ? 'قرش' : 'جنيه';

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_id': customerId,
        'invoice_id': invoiceId,
        'invoice_no': invoiceNo,
        'date': date,
        'points_earned': pointsEarned,
        'point_value': pointValue,
        'point_currency': pointCurrency,
        'is_settled': isSettled,
        'settled_at': settledAt,
        'notes': notes,
        'created_at': createdAt,
      };

  factory CustomerPointsLog.fromMap(Map<String, dynamic> m) =>
      CustomerPointsLog(
        id: m['id'] as int?,
        customerId: m['customer_id'] as int,
        invoiceId: m['invoice_id'] as int?,
        invoiceNo: m['invoice_no'] as String? ?? '',
        date: m['date'] as String? ?? '',
        pointsEarned: (m['points_earned'] as num? ?? 0).toInt(),
        pointValue: (m['point_value'] as num? ?? 1.0).toDouble(),
        pointCurrency: m['point_currency'] as String? ?? 'piasters',
        isSettled: _parseBoolPL(m['is_settled']),
        settledAt: m['settled_at'] as String?,
        notes: m['notes'] as String?,
        createdAt:
            m['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );
}
