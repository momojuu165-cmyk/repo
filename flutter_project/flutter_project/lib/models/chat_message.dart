// Point 9: Chat message model
class ChatMessage {
  final int? id;
  final int senderId;
  final int receiverId;
  final String senderName;
  final String message;
  final bool isRead;
  final String createdAt;

  ChatMessage({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'sender_name': senderName,
        'message': message,
        'is_read': isRead ? 1 : 0,
        'created_at': createdAt,
      };

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    return false;
  }

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as int?,
        senderId: m['sender_id'] as int,
        receiverId: m['receiver_id'] as int,
        senderName: m['sender_name'] as String? ?? '',
        message: m['message'] as String,
        isRead: _parseBool(m['is_read']),
        createdAt: m['created_at'] as String,
      );
}
