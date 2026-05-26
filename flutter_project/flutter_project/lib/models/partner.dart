class Partner {
  final int? id;
  final String name;
  final int shares;
  final String? phone;
  final String? email;
  final double capitalContribution;
  final bool isActive;
  final String createdAt;

  Partner({
    this.id,
    required this.name,
    required this.shares,
    this.phone,
    this.email,
    this.capitalContribution = 0,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'shares': shares,
        'phone': phone,
        'email': email,
        'capital_contribution': capitalContribution,
        'is_active': isActive,
        'created_at': createdAt,
      };

  static bool _parseBool(dynamic v, {bool defaultValue = true}) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is int) return v != 0;
    return defaultValue;
  }

  factory Partner.fromMap(Map<String, dynamic> m) => Partner(
        id: m['id'] as int?,
        name: m['name'] as String,
        shares: m['shares'] as int? ?? 0,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        capitalContribution:
            (m['capital_contribution'] as num? ?? 0).toDouble(),
        isActive: _parseBool(m['is_active']),
        createdAt: m['created_at'] as String,
      );
}

class PartnerTransaction {
  final int? id;
  final String description;
  final double amount;
  final String type;
  final String date;
  final String? relatedTo;
  final String createdAt;

  PartnerTransaction({
    this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    this.relatedTo,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'amount': amount,
        'type': type,
        'date': date,
        'related_to': relatedTo,
        'created_at': createdAt,
      };

  factory PartnerTransaction.fromMap(Map<String, dynamic> m) =>
      PartnerTransaction(
        id: m['id'] as int?,
        description: m['description'] as String,
        amount: (m['amount'] as num).toDouble(),
        type: m['type'] as String,
        date: m['date'] as String,
        relatedTo: m['related_to'] as String?,
        createdAt: m['created_at'] as String,
      );
}
