import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/treasury.dart';

class TreasuryDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Treasury>> getAll() async {
    try {

    final r = await _client.from('treasuries').select().order('name', ascending: true);
    return r.map((m) => Treasury.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<Treasury?> findById(int id) async {
    try {

    final r = await _client.from('treasuries').select().eq('id', id);
    return r.isEmpty ? null : Treasury.fromMap(r.first);
    } catch (_) {
      return null;
    }
}

  Future<int> insert(Treasury t) async {
    try {

    final map = t.toMap()..remove('id');
    final result = await _client.from('treasuries').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<int> updateBalance(int id, double newBalance) async {
    try {

    await _client.from('treasuries').update({'balance': newBalance}).eq('id', id);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<int> addMovement(TreasuryMovement movement) async {
    try {

    final map = movement.toMap()..remove('id');
    final result = await _client.from('treasury_movements').insert(map).select('id').single();
    final id = result['id'] as int;

    final treasury = await findById(movement.treasuryId);
    if (treasury != null) {
      double newBalance = treasury.balance;
      if (movement.type == 'deposit') {
        newBalance += movement.amount;
      } else if (movement.type == 'withdrawal') {
        newBalance -= movement.amount;
      }
      await updateBalance(movement.treasuryId, newBalance);
    }
    return id;
    } catch (_) {
      return -1;
    }
}

  Future<List<TreasuryMovement>> getMovements({
    int? treasuryId,
    String? type,
    String? fromDate,
    String? toDate,
  }) async {
    try {

    var q = _client.from('treasury_movements').select();
    if (treasuryId != null) q = q.eq('treasury_id', treasuryId) as dynamic;
    if (type != null) q = (q as dynamic).eq('type', type);
    if (fromDate != null) q = (q as dynamic).gte('date', fromDate);
    if (toDate != null) q = (q as dynamic).lte('date', toDate);
    final r = await (q as dynamic).order('date', ascending: false);
    return (r as List).map<TreasuryMovement>((m) => TreasuryMovement.fromMap(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
}

  Future<Map<String, double>> getMovementSummary(
      int treasuryId, String fromDate, String toDate) async {
    try {

    final r = await _client
        .from('treasury_movements')
        .select('type, amount')
        .eq('treasury_id', treasuryId)
        .gte('date', fromDate)
        .lte('date', toDate);

    double totalIn = 0, totalOut = 0;
    for (final row in r) {
      final amount = (row['amount'] as num? ?? 0).toDouble();
      if (row['type'] == 'deposit') { totalIn += amount; }
      else if (row['type'] == 'withdrawal') { totalOut += amount; }
    }
    return {'total_in': totalIn, 'total_out': totalOut};
    } catch (_) {
      return {};
    }
}
}
