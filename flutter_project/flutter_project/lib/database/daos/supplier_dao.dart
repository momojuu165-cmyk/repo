import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/supplier.dart';

class SupplierDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Supplier>> getAll({bool activeOnly = false}) async {
    try {

    var q = _client.from('suppliers').select('*');
    if (activeOnly) q = (q as dynamic).eq('is_active', true);
    final rows = await (q as dynamic).order('name', ascending: true);
    return (rows as List).map<Supplier>((r) => Supplier.fromMap(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
}

  Future<Supplier?> findById(int id) async {
    try {

    final r = await _client.from('suppliers').select().eq('id', id).limit(1);
    return (r as List).isEmpty ? null : Supplier.fromMap((r as List).first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
}

  Future<int> insert(Supplier supplier) async {
    final map = supplier.toMap()
      ..remove('id')
      ..remove('email')
      ..remove('tax_number');
    // Try progressively stripping columns that may not exist in the schema
    for (final attempt in [
      map,
      Map<String, dynamic>.from(map)..remove('section'),
      Map<String, dynamic>.from(map)..remove('section')..remove('is_active'),
      Map<String, dynamic>.from(map)..remove('section')..remove('is_active')..remove('notes'),
    ]) {
      try {
        final result = await _client.from('suppliers').insert(attempt).select('id').single();
        return result['id'] as int;
      } catch (e) {
        final msg = e.toString();
        // Only retry if it's a schema column error
        if (!msg.contains('column') && !msg.contains('schema')) rethrow;
      }
    }
    throw Exception('تعذر إضافة المورد — تحقق من إعدادات قاعدة البيانات');
  }

  Future<void> update(Supplier supplier) async {
    final map = supplier.toMap()
      ..remove('id')
      ..remove('email')
      ..remove('tax_number');
    for (final attempt in [
      map,
      Map<String, dynamic>.from(map)..remove('section'),
      Map<String, dynamic>.from(map)..remove('section')..remove('is_active'),
    ]) {
      try {
        await _client.from('suppliers').update(attempt).eq('id', supplier.id!);
        return;
      } catch (e) {
        final msg = e.toString();
        if (!msg.contains('column') && !msg.contains('schema')) rethrow;
      }
    }
  }

  Future<void> delete(int id) async {
    try {

    await _client.from('suppliers').update({'is_active': false}).eq('id', id);
    } catch (_) {}
}

  Future<void> hardDelete(int id) async {
    try {

    await _client.from('suppliers').delete().eq('id', id);
    } catch (_) {}
}

  Future<void> adjustBalance(int supplierId, double delta) async {
    try {

    final rows = await _client.from('suppliers').select('balance').eq('id', supplierId).limit(1);
    if ((rows as List).isEmpty) return;
    final current = ((rows as List).first['balance'] as num? ?? 0).toDouble();
    await _client.from('suppliers').update({'balance': current + delta}).eq('id', supplierId);
    } catch (_) {}
}

  Future<void> adjustDebt(int supplierId, double delta) async {
    try {

    // 'debt' column does not exist in Supabase schema — no-op
    } catch (_) {}
}

  // ── Supplier Products ──────────────────────────────────────────────────────

  Future<List<SupplierProduct>> getProductsBySupplier(int supplierId) async {
    try {

    final rows = await _client
        .from('supplier_products')
        .select()
        .eq('supplier_id', supplierId)
        .order('product_name', ascending: true);
    return (rows as List).map<SupplierProduct>((r) => SupplierProduct.fromMap(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
}

  Future<int> insertProduct(SupplierProduct product) async {
    try {

    final map = product.toMap()..remove('id');
    final result = await _client.from('supplier_products').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<void> updateProduct(SupplierProduct product) async {
    try {

    final map = product.toMap()..remove('id');
    await _client.from('supplier_products').update(map).eq('id', product.id!);
    } catch (_) {}
}

  Future<void> deleteProduct(int productId) async {
    try {

    await _client.from('supplier_products').delete().eq('id', productId);
    } catch (_) {}
}

  // ── Supplier Receipts / Photos ─────────────────────────────────────────────

  Future<List<SupplierReceipt>> getReceiptsBySupplier(int supplierId) async {
    try {
      final rows = await _client
          .from('supplier_receipts')
          .select()
          .eq('supplier_id', supplierId)
          .order('date', ascending: false);
      return (rows as List)
          .map<SupplierReceipt>((r) => SupplierReceipt.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> insertReceipt(SupplierReceipt receipt) async {
    try {
      final map = receipt.toMap()..remove('id');
      await _client.from('supplier_receipts').insert(map);
    } catch (_) {}
  }

  Future<void> deleteReceipt(int id) async {
    try {
      await _client.from('supplier_receipts').delete().eq('id', id);
    } catch (_) {}
  }

  /// Returns a list of all products grouped by name showing all supplier prices.
  Future<List<Map<String, dynamic>>> getProductComparison() async {
    final rows = await _client
        .from('supplier_products')
        .select('*, suppliers(name, phone)');

    final Map<String, Map<String, dynamic>> grouped = {};
    for (final row in (rows as List)) {
      final r = row as Map<String, dynamic>;
      final productName = r['product_name'] as String;
      final supplierInfo = r['suppliers'] as Map<String, dynamic>?;
      final supplierName = supplierInfo?['name'] as String? ?? '---';
      final price = (r['unit_price'] as num? ?? 0).toDouble();
      final date = r['last_supplied_at'] as String? ?? '';

      if (!grouped.containsKey(productName)) {
        grouped[productName] = {
          'product_name': productName,
          'prices': <Map<String, dynamic>>[],
          'best_price': price,
          'best_supplier': supplierName,
          'last_date': date,
        };
      }

      final entry = grouped[productName]!;
      (entry['prices'] as List<Map<String, dynamic>>).add({
        'supplier_name': supplierName,
        'price': price,
        'date': date,
        'supplier_phone': supplierInfo?['phone'],
      });

      if (price < (entry['best_price'] as double)) {
        entry['best_price'] = price;
        entry['best_supplier'] = supplierName;
      }
      if (date.compareTo(entry['last_date'] as String) > 0) {
        entry['last_date'] = date;
      }
    }

    return grouped.values.toList()
      ..sort((a, b) => (a['product_name'] as String)
          .compareTo(b['product_name'] as String));
  }
}
