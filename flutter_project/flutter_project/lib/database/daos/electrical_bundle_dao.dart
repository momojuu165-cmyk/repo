import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/electrical_bundle.dart';

class ElectricalBundleDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<int> insertBundle(ElectricalBundle b) async {
    try {

    final map = b.toMap()..remove('id');
    final result = await _client.from('electrical_bundles').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<int> updateBundle(ElectricalBundle b) async {
    try {

    final map = b.toMap()..remove('id');
    await _client.from('electrical_bundles').update(map).eq('id', b.id!);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<int> deleteBundle(int id) async {
    try {

    await _client.from('electrical_bundle_items').delete().eq('bundle_id', id);
    await _client.from('electrical_bundles').delete().eq('id', id);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<List<ElectricalBundle>> getAllBundles({bool activeOnly = false}) async {
    try {

    var q = _client.from('electrical_bundles').select();
    if (activeOnly) q = q.eq('is_active', true) as dynamic;
    final r = await (q as dynamic).order('created_at', ascending: false);
    final bundles = r.map((m) => ElectricalBundle.fromMap(m)).toList();
    for (var i = 0; i < bundles.length; i++) {
      final items = await getBundleItems(bundles[i].id!);
      bundles[i] = ElectricalBundle(
        id: bundles[i].id, name: bundles[i].name, description: bundles[i].description,
        discountRate: bundles[i].discountRate, isActive: bundles[i].isActive,
        createdAt: bundles[i].createdAt, items: items,
      );
    }
    return bundles;
    } catch (_) {
      return [];
    }
}

  Future<List<ElectricalBundleItem>> getBundleItems(int bundleId) async {
    try {

    final r = await _client
        .from('electrical_bundle_items')
        .select()
        .eq('bundle_id', bundleId);
    return r.map((m) => ElectricalBundleItem.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<void> setBundleItems(int bundleId, List<ElectricalBundleItem> items) async {
    try {

    await _client.from('electrical_bundle_items').delete().eq('bundle_id', bundleId);
    for (final item in items) {
      final map = item.toMap()..remove('id');
      map['bundle_id'] = bundleId;
      await _client.from('electrical_bundle_items').insert(map);
    }
    } catch (_) {}
}
}
