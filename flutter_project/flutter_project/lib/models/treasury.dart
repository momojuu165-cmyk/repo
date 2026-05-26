class Treasury {
  final int? id;
  final String name;
  final String type;
  final double balance;
  final int? employeeId;

  Treasury({
    this.id,
    required this.name,
    this.type = 'main',
    this.balance = 0,
    this.employeeId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'balance': balance,
        'employee_id': employeeId,
      };

  factory Treasury.fromMap(Map<String, dynamic> m) => Treasury(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: m['type'] as String? ?? 'main',
        balance: (m['balance'] as num? ?? 0).toDouble(),
        employeeId: m['employee_id'] as int?,
      );

  Treasury copyWith({double? balance}) =>
      Treasury(
        id: id,
        name: name,
        type: type,
        balance: balance ?? this.balance,
        employeeId: employeeId,
      );
}

class TreasuryMovement {
  final int? id;
  final int treasuryId;
  final String type;
  final double amount;
  final String? reference;
  final String? description;
  final String date;
  final int? createdBy;
  final String createdAt;

  TreasuryMovement({
    this.id,
    required this.treasuryId,
    required this.type,
    required this.amount,
    this.reference,
    this.description,
    required this.date,
    this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'treasury_id': treasuryId,
        'type': type,
        'amount': amount,
        'reference': reference,
        'description': description,
        'date': date,
        'created_by': createdBy,
        'created_at': createdAt,
      };

  factory TreasuryMovement.fromMap(Map<String, dynamic> m) => TreasuryMovement(
        id: m['id'] as int?,
        treasuryId: m['treasury_id'] as int,
        type: m['type'] as String,
        amount: (m['amount'] as num).toDouble(),
        reference: m['reference'] as String?,
        description: m['description'] as String?,
        date: m['date'] as String,
        createdBy: m['created_by'] as int?,
        createdAt: m['created_at'] as String,
      );
}
