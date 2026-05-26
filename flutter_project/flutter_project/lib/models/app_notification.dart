// Notification model — supports user-specific, role-based, and broadcast delivery.
// referenceId / referenceType carry navigation metadata without exposing PII in the body.
class AppNotification {
  final int? id;
  final int? userId;
  final String? userRole;     // 'admin' | 'manager' | 'customer' | 'partner'
  final String title;
  final String body;
  final String type;          // 'request' | 'invoice' | 'installment' | 'payment' | 'general'
  final bool isRead;
  final String createdAt;
  final int? referenceId;     // e.g. request id, invoice id — for deep-linking
  final String? referenceType; // 'request' | 'invoice' | 'installment' | 'payment'

  AppNotification({
    this.id,
    this.userId,
    this.userRole,
    required this.title,
    required this.body,
    this.type = 'general',
    this.isRead = false,
    required this.createdAt,
    this.referenceId,
    this.referenceType,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'user_role': userRole,
        'title': title,
        'body': body,
        'type': type,
        'is_read': isRead ? 1 : 0,
        'created_at': createdAt,
        'reference_id': referenceId,
        'reference_type': referenceType,
      };

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    return false;
  }

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as int?,
        userId: m['user_id'] as int?,
        userRole: m['user_role'] as String?,
        title: m['title'] as String,
        body: m['body'] as String,
        type: m['type'] as String? ?? 'general',
        isRead: _parseBool(m['is_read']),
        createdAt: m['created_at'] as String,
        referenceId: m['reference_id'] as int?,
        referenceType: m['reference_type'] as String?,
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        userId: userId,
        userRole: userRole,
        title: title,
        body: body,
        type: type,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        referenceId: referenceId,
        referenceType: referenceType,
      );
}
