import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/installment_product.dart';
import 'product_image_dao.dart';

class InstallmentProductDao {
  SupabaseClient get _client => Supabase.instance.client;
  final _imgDao = ProductImageDao();

  Future<int> insert(InstallmentProduct p) async {
    try {

    final map = p.toMap()..remove('id');
    final result = await _client.from('installment_products').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<int> update(InstallmentProduct p) async {
    try {

    final map = p.toMap()..remove('id');
    await _client.from('installment_products').update(map).eq('id', p.id!);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<int> delete(int id) async {
    try {

    await _client.from('installment_products').delete().eq('id', id);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<InstallmentProduct> _withImages(InstallmentProduct p) async {
    try {

    if (p.id == null) return p;
    final paths = await _imgDao.getPathsForProduct(p.storeType, p.id!);
    if (paths.isNotEmpty) {
      return p.copyWith(imagePaths: paths);
    }
    if (p.imagePath != null) {
      return p.copyWith(imagePaths: [p.imagePath!]);
    }
    return p;
    } catch (_) {
      return p;
    }
}

  Future<List<InstallmentProduct>> getAll({bool availableOnly = false, String? storeType}) async {
    try {

    var q = _client.from('installment_products').select();
    if (availableOnly) q = q.eq('is_available', true) as dynamic;
    if (storeType != null) q = (q as dynamic).eq('store_type', storeType);
    final r = await (q as dynamic).order('name', ascending: true);
    final products = (r as List).map<InstallmentProduct>((m) => InstallmentProduct.fromMap(m as Map<String, dynamic>)).toList();
    return Future.wait(products.map(_withImages));
    } catch (_) {
      return [];
    }
}

  Future<InstallmentProduct?> findById(int id) async {
    try {

    final r = await _client.from('installment_products').select().eq('id', id);
    if (r.isEmpty) return null;
    return _withImages(InstallmentProduct.fromMap(r.first));
    } catch (_) {
      return null;
    }
}

  Future<List<InstallmentProduct>> search(String query) async {
    try {

    final r = await _client
        .from('installment_products')
        .select()
        .or('name.ilike.%$query%,category.ilike.%$query%');
    final products = r.map((m) => InstallmentProduct.fromMap(m)).toList();
    return Future.wait(products.map(_withImages));
    } catch (_) {
      return [];
    }
}
}
