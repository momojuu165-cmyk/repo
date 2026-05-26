import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/partner.dart';

class PartnerDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<int> insertPartner(Partner p) async {
    try {

    final map = p.toMap()..remove('id');
    final result = await _client.from('partners').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<int> insertTransaction(PartnerTransaction t) async {
    try {

    final map = t.toMap()..remove('id');
    final result = await _client.from('partner_transactions').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<List<Partner>> getAll({bool activeOnly = true}) async {
    try {

    var q = _client.from('partners').select();
    if (activeOnly) q = q.eq('is_active', true) as dynamic;
    final r = await (q as dynamic).order('name', ascending: true);
    return (r as List).map<Partner>((m) => Partner.fromMap(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
}

  Future<Partner?> findById(int id) async {
    try {

    final r = await _client.from('partners').select().eq('id', id);
    return r.isEmpty ? null : Partner.fromMap(r.first);
    } catch (_) {
      return null;
    }
}

  Future<int> update(Partner p) async {
    try {

    final map = p.toMap()..remove('id');
    await _client.from('partners').update(map).eq('id', p.id!);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<List<PartnerTransaction>> getTransactions({
    String? fromDate,
    String? toDate,
  }) async {
    try {

    var q = _client.from('partner_transactions').select();
    if (fromDate != null) q = q.gte('date', fromDate) as dynamic;
    if (toDate != null) q = (q as dynamic).lte('date', toDate);
    final r = await (q as dynamic).order('date', ascending: false);
    return (r as List)
        .map<PartnerTransaction>((m) => PartnerTransaction.fromMap(m as Map<String, dynamic>))
        .toList();
    } catch (_) {
      return [];
    }
}

  Future<double> getTotalShares() async {
    try {

    final partners = await getAll();
    return partners.fold<double>(0.0, (s, p) => s + p.shares);
    } catch (_) {
      return 0.0;
    }
}

  Future<Map<String, dynamic>> getProfitDistribution({
    required double totalProfit,
    required double adminFeeRate,
  }) async {
    try {

    final partners = await getAll();
    final totalShares = partners.fold<double>(0.0, (s, p) => s + p.shares);
    final adminFee = totalProfit * adminFeeRate;
    final distributable = totalProfit - adminFee;

    return {
      'total_profit': totalProfit,
      'admin_fee': adminFee,
      'distributable': distributable,
      'partners': partners.map((p) {
        final share =
            totalShares > 0 ? (p.shares / totalShares) * distributable : 0.0;
        return {
          'partner': p,
          'share_percentage':
              totalShares > 0 ? (p.shares / totalShares) * 100 : 0,
          'profit_share': share,
        };
      }).toList(),
    };
    } catch (_) {
      return {};
    }
}
}
