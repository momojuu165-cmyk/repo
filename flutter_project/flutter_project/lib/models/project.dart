class Project {
  final int? id;
  final String projectNo;
  final String type;
  final String date;
  final String status;
  final String? description;
  final String createdAt;

  Project({
    this.id,
    required this.projectNo,
    required this.type,
    required this.date,
    this.status = 'active',
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_no': projectNo,
        'type': type,
        'date': date,
        'status': status,
        'description': description,
        'created_at': createdAt,
      };

  factory Project.fromMap(Map<String, dynamic> m) => Project(
        id: m['id'] as int?,
        projectNo: m['project_no'] as String,
        type: m['type'] as String,
        date: m['date'] as String,
        status: m['status'] as String? ?? 'active',
        description: m['description'] as String?,
        createdAt: m['created_at'] as String,
      );
}

class ProjectItem {
  final int? id;
  final int projectId;
  final String type;
  final double amount;
  final String description;
  final String date;

  ProjectItem({
    this.id,
    required this.projectId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'type': type,
        'amount': amount,
        'description': description,
        'date': date,
      };

  factory ProjectItem.fromMap(Map<String, dynamic> m) => ProjectItem(
        id: m['id'] as int?,
        projectId: m['project_id'] as int,
        type: m['type'] as String,
        amount: (m['amount'] as num).toDouble(),
        description: m['description'] as String,
        date: m['date'] as String,
      );
}
