class PartnerGroup {
  final int? id;
  final String name;
  final String? description;
  final double startingBalance;
  /// نسبة رسوم الإدارة الخاصة بهذه المجموعة.
  /// null = استخدام القيمة الافتراضية من الإعدادات العامة
  final double? managementFeeRate;
  final String createdAt;

  PartnerGroup({
    this.id,
    required this.name,
    this.description,
    this.startingBalance = 0.0,
    this.managementFeeRate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'starting_balance': startingBalance,
    'management_fee_rate': managementFeeRate,
    'created_at': createdAt,
  };

  factory PartnerGroup.fromMap(Map<String, dynamic> m) => PartnerGroup(
    id: m['id'] as int?,
    name: m['name'] as String,
    description: m['description'] as String?,
    startingBalance: (m['starting_balance'] as num? ?? 0).toDouble(),
    managementFeeRate: (m['management_fee_rate'] as num?)?.toDouble(),
    createdAt: m['created_at'] as String,
  );
}

class PartnerGroupMember {
  final int? id;
  final int groupId;
  final int? customerId;
  final int? userId;
  /// عدد الأسهم — يُستخدم بدلاً من نسبة ثابتة لحساب توزيع الأرباح
  final int numberOfShares;
  /// رأس المال الفردي (مجموع استثمارات الشريك)
  final double capitalAmount;
  final String? customerName;
  final String? customerPhone;

  PartnerGroupMember({
    this.id,
    required this.groupId,
    this.customerId,
    this.userId,
    this.numberOfShares = 1,
    this.capitalAmount = 0.0,
    this.customerName,
    this.customerPhone,
  });

  /// نسبة الربح = (أسهمه / إجمالي الأسهم) × 100
  double sharePercentage(int totalShares) {
    if (totalShares == 0) return 0;
    return (numberOfShares / totalShares) * 100;
  }

  /// للتوافق مع الكود القديم — يُحسب ديناميكياً بعد معرفة إجمالي الأسهم
  double get profitPercentage => 0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'group_id': groupId,
    'customer_id': customerId,
    'user_id': userId,
    'number_of_shares': numberOfShares,
    'capital_amount': capitalAmount,
  };

  factory PartnerGroupMember.fromMap(Map<String, dynamic> m) => PartnerGroupMember(
    id: m['id'] as int?,
    groupId: m['group_id'] as int,
    customerId: m['customer_id'] as int?,
    userId: m['user_id'] as int?,
    numberOfShares: (m['number_of_shares'] as num? ?? m['profit_percentage'] as num? ?? 1).toInt(),
    capitalAmount: (m['capital_amount'] as num? ?? 0).toDouble(),
    customerName: m['customer_name'] as String?,
    customerPhone: m['customer_phone'] as String?,
  );
}

// ── GroupCashFlow ─────────────────────────────────────────────────────────────
class GroupCashFlow {
  final int? id;
  final int groupId;
  final String type; // 'in' | 'out'
  final double amount;
  final String? description;
  final String date;
  final String createdAt;

  GroupCashFlow({
    this.id,
    required this.groupId,
    required this.type,
    required this.amount,
    this.description,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'group_id': groupId,
    'type': type,
    'amount': amount,
    'description': description,
    'date': date,
    'created_at': createdAt,
  };

  factory GroupCashFlow.fromMap(Map<String, dynamic> m) => GroupCashFlow(
    id: m['id'] as int?,
    groupId: m['group_id'] as int,
    type: m['type'] as String,
    amount: (m['amount'] as num? ?? 0).toDouble(),
    description: m['description'] as String?,
    date: m['date'] as String,
    createdAt: m['created_at'] as String,
  );
}
