import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/item.dart';
import '../../models/item_group.dart';
import '../../models/warehouse.dart';

class ItemDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<int> insert(Item item) async {
    try {

    final map = item.toMap()..remove('id');
    final result = await _client.from('items').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<void> delete(int id) async {
    try {
      await _client.from('items').delete().eq('id', id);
    } catch (_) {}
  }

  Future<Item?> findById(int id) async {
    try {

    final r = await _client.from('items').select().eq('id', id);
    return r.isEmpty ? null : Item.fromMap(r.first);
    } catch (_) {
      return null;
    }
}

  Future<Item?> findByBarcode(String barcode) async {
    try {

    final r = await _client
        .from('items')
        .select()
        .eq('barcode', barcode)
        .eq('is_blocked', false);
    return r.isEmpty ? null : Item.fromMap(r.first);
    } catch (_) {
      return null;
    }
}

  Future<List<Item>> getAll({bool activeOnly = true}) async {
    try {

    var q = _client.from('items').select();
    if (activeOnly) q = q.eq('is_blocked', false) as dynamic;
    final r = await (q as dynamic).order('name', ascending: true);
    return (r as List).map<Item>((m) => Item.fromMap(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<Item>> getByStoreType(String storeType,
      {bool activeOnly = true}) async {
    try {

    var q = _client.from('items').select().eq('store_type', storeType);
    if (activeOnly) q = q.eq('is_blocked', false) as dynamic;
    final r = await (q as dynamic).order('name', ascending: true);
    return (r as List).map<Item>((m) => Item.fromMap(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<Item>> search(String query) async {
    try {

    final r = await _client
        .from('items')
        .select()
        .eq('is_blocked', false)
        .or('name.ilike.%$query%,barcode.ilike.%$query%')
        .order('name', ascending: true);
    return r.map((m) => Item.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<Item>> searchByStoreType(String query, String storeType) async {
    try {

    final r = await _client
        .from('items')
        .select()
        .eq('is_blocked', false)
        .eq('store_type', storeType)
        .or('name.ilike.%$query%,barcode.ilike.%$query%')
        .order('name', ascending: true);
    return r.map((m) => Item.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<Item>> getByGroup(int groupId) async {
    try {

    final r = await _client
        .from('items')
        .select()
        .eq('group_id', groupId)
        .eq('is_blocked', false)
        .order('name', ascending: true);
    return r.map((m) => Item.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<Item>> getBlocked() async {
    try {

    final r = await _client.from('items').select().eq('is_blocked', true);
    return r.map((m) => Item.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<int> update(Item item) async {
    try {

    final map = item.toMap()..remove('id');
    await _client.from('items').update(map).eq('id', item.id!);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<int> updateQuantity(int id, double delta) async {
    try {

    final r = await _client.from('items').select('quantity').eq('id', id).single();
    final current = (r['quantity'] as num? ?? 0).toDouble();
    await _client.from('items').update({'quantity': current + delta}).eq('id', id);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<int> toggleBlocked(int id, bool blocked) async {
    try {

    await _client.from('items').update({'is_blocked': blocked}).eq('id', id);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<List<ItemGroup>> getAllGroups() async {
    try {

    final r = await _client.from('item_groups').select().order('name', ascending: true);
    return r.map((m) => ItemGroup.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<ItemGroup>> getGroupsByStoreType(String storeType) async {
    try {

    final r = await _client
        .from('item_groups')
        .select()
        .eq('store_type', storeType)
        .order('name', ascending: true);
    return r.map((m) => ItemGroup.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<int> insertGroup(ItemGroup group) async {
    try {

    final map = group.toMap()..remove('id');
    final result = await _client.from('item_groups').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<void> deleteGroup(int id) async {
    try {

    await _client.from('item_groups').delete().eq('id', id);
    } catch (_) {}
}

  Future<List<Warehouse>> getAllWarehouses() async {
    try {

    final r = await _client.from('warehouses').select().order('name', ascending: true);
    return r.map((m) => Warehouse.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<int> insertWarehouse(Warehouse w) async {
    try {

    final map = w.toMap()..remove('id');
    final result = await _client.from('warehouses').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<int> transferBetweenWarehouses({
    required int fromId,
    required int toId,
    required int itemId,
    required double qty,
    int? employeeId,
    String? notes,
  }) async {
    try {

    final now = DateTime.now().toIso8601String();
    final result = await _client.from('warehouse_transfers').insert({
      'from_warehouse_id': fromId,
      'to_warehouse_id': toId,
      'item_id': itemId,
      'qty': qty,
      'employee_id': employeeId,
      'date': now.substring(0, 10),
      'notes': notes,
      'created_at': now,
    }).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}
}
