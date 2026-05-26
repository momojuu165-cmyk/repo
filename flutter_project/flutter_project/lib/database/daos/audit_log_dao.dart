import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight audit trail for critical operations.
/// Each entry records who did what, when, and before/after values.
class AuditLogDao {
  SupabaseClient get _client => Supabase.instance.client;

  static const _table = 'audit_logs';

  /// Log a user action.
  Future<void> log({
    required String action,          // e.g. 'DELETE_INVOICE', 'UPDATE_PRICE'
    required String entity,          // e.g. 'invoice', 'installment_payment'
    int? entityId,
    int? performedByUserId,
    String? performedByName,
    Map<String, dynamic>? before,    // state before the change
    Map<String, dynamic>? after,     // state after the change
    String? notes,
  }) async {
    try {
      await _client.from(_table).insert({
        'action': action,
        'entity': entity,
        'entity_id': entityId,
        'performed_by_user_id': performedByUserId,
        'performed_by_name': performedByName,
        'before_data': before?.toString(),
        'after_data': after?.toString(),
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Never crash the app for audit failures
    }
  }

  Future<List<Map<String, dynamic>>> getRecent({int limit = 100, String? entity}) async {
    try {
      var q = _client.from(_table).select('*');
      if (entity != null) q = (q as dynamic).eq('entity', entity);
      final rows = await (q as dynamic)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getForEntity(String entity, int entityId) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('entity', entity)
          .eq('entity_id', entityId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getByUser(int userId) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('performed_by_user_id', userId)
          .order('created_at', ascending: false)
          .limit(200);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }
}
