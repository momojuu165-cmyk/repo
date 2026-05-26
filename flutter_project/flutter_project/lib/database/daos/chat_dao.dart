import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/chat_message.dart';

class ChatDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<int> insert(ChatMessage msg) async {
    try {

    final map = msg.toMap()..remove('id');
    // Let exceptions propagate so callers can show the user an error message
    final result = await _client
        .from('chat_messages')
        .insert(map)
        .select('id')
        .single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<List<ChatMessage>> getConversation(int userId1, int userId2) async {
    try {

    final r = await _client
        .from('chat_messages')
        .select()
        .or('and(sender_id.eq.$userId1,receiver_id.eq.$userId2),and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
        .order('created_at', ascending: true);
    return r.map((m) => ChatMessage.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<Map<String, dynamic>>> getPartnerChatList(int adminId) async {
    // Get all active partner users
    final partners = await _client
        .from('users')
        .select('id, name, phone')
        .eq('role', 'partner')
        .eq('is_active', true);

    final result = <Map<String, dynamic>>[];
    for (final partner in partners) {
      final partnerId = partner['id'] as int;
      // Get last message
      final messages = await _client
          .from('chat_messages')
          .select('message, created_at')
          .or('and(sender_id.eq.$partnerId,receiver_id.eq.$adminId),and(sender_id.eq.$adminId,receiver_id.eq.$partnerId)')
          .order('created_at', ascending: false)
          .limit(1);
      // Get unread count
      // is_read is INTEGER (0/1) in DB — never filter with boolean
      final unread = await _client
          .from('chat_messages')
          .select('id')
          .eq('sender_id', partnerId)
          .eq('receiver_id', adminId)
          .eq('is_read', 0);

      result.add({
        'id': partner['id'],
        'name': partner['name'],
        'phone': partner['phone'],
        'last_message': messages.isNotEmpty ? messages.first['message'] : null,
        'last_at': messages.isNotEmpty ? messages.first['created_at'] : null,
        'unread_count': unread.length,
      });
    }
    // Sort by last_at descending
    result.sort((a, b) {
      final aAt = a['last_at'] as String? ?? '';
      final bAt = b['last_at'] as String? ?? '';
      return bAt.compareTo(aAt);
    });
    return result;
  }

  Future<void> markAsRead(int senderId, int receiverId) async {
    try {

    // is_read is INTEGER (0/1) in DB — never send a boolean
    await _client
        .from('chat_messages')
        .update({'is_read': 1})
        .eq('sender_id', senderId)
        .eq('receiver_id', receiverId)
        .eq('is_read', 0);
    } catch (_) {}
}

  Future<int> getUnreadCount(int userId) async {
    try {

    final r = await _client
        .from('chat_messages')
        .select('id')
        .eq('receiver_id', userId)
        .eq('is_read', 0);
    return r.length;
    } catch (_) {
      return -1;
    }
}
}
