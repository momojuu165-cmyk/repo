import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_image.dart';

class ProductImageDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<int> insert(ProductImage img) async {
    try {

    final map = img.toMap()..remove('id');
    final result = await _client.from('product_images').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<List<ProductImage>> getForProduct(String productType, int productId) async {
    try {

    final r = await _client
        .from('product_images')
        .select()
        .eq('product_type', productType)
        .eq('product_id', productId)
        .order('sort_order', ascending: true);
    return r.map((m) => ProductImage.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<String>> getPathsForProduct(String productType, int productId) async {
    try {

    final images = await getForProduct(productType, productId);
    return images.map((i) => i.imagePath).toList();
    } catch (_) {
      return [];
    }
}

  Future<void> delete(int id) async {
    try {

    await _client.from('product_images').delete().eq('id', id);
    } catch (_) {}
}

  Future<void> deleteAllForProduct(String productType, int productId) async {
    try {

    await _client
        .from('product_images')
        .delete()
        .eq('product_type', productType)
        .eq('product_id', productId);
    } catch (_) {}
}
}
