import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/customer_points_log.dart';

class CustomerPointsDao {
  SupabaseClient get _client => Supabase.instance.client;

  static const _table = 'customer_points_log';

  Future<int> insert(CustomerPointsLog entry) async {
    final map = entry.toMap()..remove('id');
    final result =
        await _client.from(_table).insert(map).select('id').single();
    return result['id'] as int;
  }

  Future<List<CustomerPointsLog>> getByCustomer(int customerId) async {
    final r = await _client
        .from(_table)
        .select()
        .eq('customer_id', customerId)
        .order('date', ascending: false);
    return (r as List)
        .map<CustomerPointsLog>(
            (m) => CustomerPointsLog.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<int> getTotalUnsettledPoints(int customerId) async {
    final r = await _client
        .from(_table)
        .select('points_earned')
        .eq('customer_id', customerId)
        .eq('is_settled', false);
    return (r as List).fold<int>(
        0, (s, m) => s + ((m['points_earned'] as num?) ?? 0).toInt());
  }

  Future<Map<int, int>> getTotalsPerCustomer() async {
    final result = <int, int>{};
    final r = await _client
        .from(_table)
        .select('customer_id, points_earned')
        .eq('is_settled', false);
    for (final m in (r as List)) {
      final cid = m['customer_id'] as int;
      final pts = (m['points_earned'] as num? ?? 0).toInt();
      result[cid] = (result[cid] ?? 0) + pts;
    }
    return result;
  }

  /// Settles a single log entry using SECURITY DEFINER RPC (bypasses RLS).
  Future<void> settleEntry(int logId, int customerId, int points) async {
    try {
      await _client.rpc('settle_customer_points', params: {
        'p_log_id':      logId,
        'p_customer_id': customerId,
        'p_points':      points,
      });
    } catch (_) {
      // RPC not installed yet — fallback to direct update
      final updated = await _client.from(_table).update({
        'is_settled': true,
        'settled_at': DateTime.now().toIso8601String(),
      }).eq('id', logId).select('id');

      if ((updated as List).isEmpty) {
        throw Exception(
          'فشل تسوية النقطة (id=$logId) — '
          'شغّل ملف setup_points_table.sql في Supabase Dashboard.',
        );
      }

      // Deduct from customer balance
      final row = await _client
          .from('customers')
          .select('points')
          .eq('id', customerId)
          .single();
      final current = (row['points'] as num? ?? 0).toInt();
      await _client
          .from('customers')
          .update({'points': (current - points).clamp(0, 999999)})
          .eq('id', customerId);
    }
  }

  /// Marks all unsettled entries for a customer as settled.
  Future<int> settleAllForCustomer(int customerId) async {
    // Get unsettled rows first so we know total points to deduct
    final unsettled = await _client
        .from(_table)
        .select('id, points_earned')
        .eq('customer_id', customerId)
        .eq('is_settled', false);

    final rows = unsettled as List;
    if (rows.isEmpty) return 0;

    final totalPoints =
        rows.fold<int>(0, (s, m) => s + ((m['points_earned'] as num?) ?? 0).toInt());

    await _client
        .from(_table)
        .update({
          'is_settled': true,
          'settled_at': DateTime.now().toIso8601String(),
        })
        .eq('customer_id', customerId)
        .eq('is_settled', false);

    // Deduct total from customer balance
    try {
      await _client.rpc('increment_customer_points', params: {
        'p_customer_id': customerId,
        'p_delta': -totalPoints,
      });
    } catch (_) {
      final row = await _client
          .from('customers')
          .select('points')
          .eq('id', customerId)
          .single();
      final current = (row['points'] as num? ?? 0).toInt();
      await _client
          .from('customers')
          .update({'points': (current - totalPoints).clamp(0, 999999)})
          .eq('id', customerId);
    }

    return rows.length;
  }
}
