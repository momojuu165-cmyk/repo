import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_request.dart';

class RequestDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<int> insert(ProductRequest req) async {
    // Build a clean map: start with all fields, then strip columns that are
    // known to be missing in some deployments and retry on error.
    final base = req.toMap();
    // Always remove columns the table is known to not have yet
    final map = Map<String, dynamic>.from(base)
      ..remove('id')
      ..remove('qty')            // column does not exist in product_requests table
      ..remove('item_id')        // column doesn't exist in all deployments
      ..remove('deposit_amount') // strip optional columns that may not exist
      ..remove('date');          // strip date column that may not exist

    try {
      final result = await _client.from('product_requests').insert(map).select('id').single();
      return result['id'] as int;
    } catch (e) {
      final errStr = e.toString();
      // Fallback: strip any remaining unsupported optional column and retry once
      Map<String, dynamic> fallback = Map<String, dynamic>.from(map);
      bool stripped = false;
      for (final col in ['deposit_amount', 'date', 'notes', 'num_installments', 'store_type']) {
        if (errStr.contains(col)) {
          fallback.remove(col);
          stripped = true;
        }
      }
      if (stripped) {
        try {
          final result = await _client.from('product_requests').insert(fallback).select('id').single();
          return result['id'] as int;
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<List<ProductRequest>> getByCustomer(int customerId) async {
    try {

    final r = await _client
        .from('product_requests')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return r.map((m) => ProductRequest.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<Map<String, dynamic>>> getAllWithCustomer({
    String? status,
    String? storeType,
  }) async {
    var q = _client.from('product_requests').select('*, customers(name, phone, store_type)');
    if (status != null) q = q.eq('status', status) as dynamic;
    final r = await (q as dynamic).order('created_at', ascending: false);
    final result = r.map((row) {
      final m = Map<String, dynamic>.from(row as Map);
      final c = m['customers'] as Map?;
      m['customer_name'] = c?['name'];
      m['customer_phone'] = c?['phone'];
      m['customer_store_type'] = c?['store_type'];
      m.remove('customers');
      return m;
    }).toList();

    if (storeType != null) {
      return result.where((m) {
        final customerStore = (m['customer_store_type'] as String?)?.trim();
        final requestStore = (m['store_type'] as String?)?.trim();
        return customerStore == storeType || requestStore == storeType;
      }).toList();
    }
    return result;
  }

  Future<int> updateStatus(
    int id,
    String status, {
    double? adminDiscount,
    String? rejectReason,
  }) async {
    try {
      final map = <String, dynamic>{'status': status};
      if (adminDiscount != null) map['admin_discount'] = adminDiscount;
      if (rejectReason != null && rejectReason.isNotEmpty) {
        map['reject_reason'] = rejectReason;
      }
      await _client.from('product_requests').update(map).eq('id', id);
      return 1;
    } catch (e) {
      // If reject_reason column doesn't exist yet, retry without it
      if (rejectReason != null && e.toString().contains('reject_reason')) {
        try {
          final fallback = <String, dynamic>{'status': status};
          if (adminDiscount != null) fallback['admin_discount'] = adminDiscount;
          await _client.from('product_requests').update(fallback).eq('id', id);
          return 1;
        } catch (_) {}
      }
      return -1;
    }
  }

  Future<int> updateReceipt(int id, String receiptPath) async {
    try {

    await _client.from('product_requests').update({'receipt_path': receiptPath}).eq('id', id);
    return 1;
    } catch (_) {
      return -1;
    }
}

  Future<ProductRequest?> findById(int id) async {
    try {

    final r = await _client.from('product_requests').select().eq('id', id);
    return r.isEmpty ? null : ProductRequest.fromMap(r.first);
    } catch (_) {
      return null;
    }
}
}
