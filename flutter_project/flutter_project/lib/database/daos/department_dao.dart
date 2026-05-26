import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/department.dart';

class DepartmentDao {
  final _client = Supabase.instance.client;

  Future<List<Department>> getAll({bool activeOnly = false}) async {
    try {

    final rows = await _client
        .from('departments')
        .select()
        .order('name', ascending: true);
    final depts = List<Map<String, dynamic>>.from(rows)
        .map(Department.fromMap)
        .toList();
    if (!activeOnly) return depts;
    return depts.where((d) => d.isActive).toList();
    } catch (_) {
      return [];
    }
}

  Future<Department?> getByStoreType(String storeType) async {
    try {

    final rows = await _client
        .from('departments')
        .select()
        .eq('store_type', storeType)
        .limit(1);
    if (rows.isEmpty) return null;
    return Department.fromMap(rows.first);
    } catch (_) {
      return null;
    }
}

  Future<void> create(Department d) async {
    try {

    await _client.from('departments').insert(d.toMap());
    } catch (_) {}
}

  Future<void> update(Department d) async {
    try {

    await _client
        .from('departments')
        .update(d.toMap())
        .eq('id', d.id!);
    } catch (_) {}
}

  Future<void> delete(int id) async {
    try {

    await _client.from('departments').delete().eq('id', id);
    } catch (_) {}
}
}
