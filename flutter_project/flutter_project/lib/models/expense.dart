class Expense {
  final int? id;
  final String type;
  final double amount;
  final String description;
  final int? treasuryId;
  final String date;
  final int? createdBy;
  final String createdAt;
  final String? section;

  Expense({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.treasuryId,
    required this.date,
    this.createdBy,
    required this.createdAt,
    this.section,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'description': description,
        'treasury_id': treasuryId,
        'date': date,
        'created_by': createdBy,
        'created_at': createdAt,
        'section': section,
      };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as int?,
        type: m['type'] as String,
        amount: (m['amount'] as num).toDouble(),
        description: m['description'] as String,
        treasuryId: m['treasury_id'] as int?,
        date: m['date'] as String,
        createdBy: m['created_by'] as int?,
        createdAt: m['created_at'] as String,
        section: m['section'] as String?,
      );
}
