import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../models/customer.dart';

class CustomerDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<int> insert(Customer c) async {
    final Map<String, dynamic> map = {
      'name': c.name,
      'customer_type': c.customerType,
      'price_type': c.priceType,
      'store_type': c.storeType,
      'balance': c.balance,
      'points': c.points,
      'is_active': c.isActive,
      'is_approved': c.isApproved,
      'created_at': c.createdAt,
    };
    if (c.phone != null) map['phone'] = c.phone;
    if (c.address != null) map['address'] = c.address;
    if (c.loginCode != null) map['login_code'] = c.loginCode;
    if (c.customerStatus != 'regular') map['customer_status'] = c.customerStatus;
    if (c.groupId != null) map['group_id'] = c.groupId;
    if (c.fullName != null) map['full_name'] = c.fullName;
    if (c.whatsapp != null) map['whatsapp'] = c.whatsapp;
    if (c.email != null) map['email'] = c.email;
    if (c.homeAddress != null) map['home_address'] = c.homeAddress;
    if (c.workAddress != null) map['work_address'] = c.workAddress;

    try {
      final result =
          await _client.from('customers').insert(map).select('id').single();
      return result['id'] as int;
    } catch (e) {
      final coreMap = <String, dynamic>{
        'name': c.name,
        'customer_type': c.customerType,
        'price_type': c.priceType,
        'store_type': c.storeType,
        'balance': c.balance,
        'points': c.points,
        'is_active': c.isActive,
        'is_approved': c.isApproved,
        'created_at': c.createdAt,
      };
      if (c.phone != null) coreMap['phone'] = c.phone;
      if (c.address != null) coreMap['address'] = c.address;
      if (c.loginCode != null) coreMap['login_code'] = c.loginCode;
      final result2 =
          await _client.from('customers').insert(coreMap).select('id').single();
      return result2['id'] as int;
    }
  }

  Future<Customer?> findById(int id) async {
    try {
      final r = await _client.from('customers').select().eq('id', id);
      return r.isEmpty ? null : Customer.fromMap(r.first);
    } catch (_) {
      return null;
    }
  }

  Future<Customer?> findByLoginCode(String code) async {
    try {
      final normalizedCode = code.trim();
      final r = await _client
          .from('customers')
          .select()
          .ilike('login_code', normalizedCode)
          .eq('is_active', true);
      final list = r as List;
      if (list.isEmpty) {
        debugPrint('CustomerDao.findByLoginCode: no match for "$normalizedCode". Running diagnostic.');
        print('CustomerDao.findByLoginCode: no match for "$normalizedCode". Running diagnostic.');
        final diag = await _client
            .from('customers')
            .select('id, login_code, is_active, is_approved')
            .ilike('login_code', '%$normalizedCode%')
            .limit(10);
        debugPrint('CustomerDao.findByLoginCode diagnostic result: $diag');
        print('CustomerDao.findByLoginCode diagnostic result: $diag');
        return null;
      }
      debugPrint('CustomerDao.findByLoginCode: found ${list.length} row(s) for "$normalizedCode".');
      print('CustomerDao.findByLoginCode: found ${list.length} row(s) for "$normalizedCode".');
      return Customer.fromMap(list.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<Customer>> getAll({bool activeOnly = true}) async {
    try {
      var q = _client.from('customers').select();
      if (activeOnly) q = q.eq('is_active', true) as dynamic;
      final r = await (q as dynamic).order('name', ascending: true);
      return (r as List).map<Customer>((m) => Customer.fromMap(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Customer>> getByStoreType(String storeType) async {
    try {
      final r = await _client
          .from('customers')
          .select()
          .eq('is_active', true)
          .eq('store_type', storeType)
          .order('name', ascending: true);
      return r.map((m) => Customer.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Customer>> getPendingRegistrations() async {
    try {
      final r = await _client
          .from('customers')
          .select()
          .eq('is_active', true)
          .eq('is_approved', false)
          .order('created_at', ascending: false);
      return r.map((m) => Customer.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Customer>> search(String query) async {
    try {
      final r = await _client
          .from('customers')
          .select()
          .eq('is_active', true)
          .or('name.ilike.%$query%,phone.ilike.%$query%')
          .order('name', ascending: true);
      return r.map((m) => Customer.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> setCustomerStatus(int id, String customerStatus) async {
    try {
      final response = await _client
          .from('customers')
          .update({'customer_status': customerStatus})
          .eq('id', id)
          .select('id');
      return (response as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<int> update(Customer c) async {
    try {
      final map = c.toMap()..remove('id');
      final response =
          await _client.from('customers').update(map).eq('id', c.id!).select('id');
      return (response as List).isNotEmpty ? 1 : -1;
    } catch (_) {
      return -1;
    }
  }

  Future<int> updateBalance(int id, double newBalance) async {
    try {
      await _client.from('customers').update({'balance': newBalance}).eq('id', id);
      return 1;
    } catch (_) {
      return -1;
    }
  }

  /// Atomically increments (or decrements) the customer's points.
  ///
  /// First tries the `increment_customer_points` RPC function (atomic, no race
  /// condition). Falls back to a read-modify-write if the RPC is not installed.
  /// Throws a descriptive exception if the update is blocked (e.g. by RLS).
  Future<void> addPoints(int id, int delta) async {
    if (delta == 0) return;

    // ── Attempt 1: RPC (atomic, preferred) ─────────────────────────────────
    try {
      await _client.rpc(
        'increment_customer_points',
        params: {'p_customer_id': id, 'p_delta': delta},
      );
      return;
    } catch (_) {
      // RPC not installed — fall through to manual update
    }

    // ── Attempt 2: Read-modify-write with verification ──────────────────────
    final r = await _client
        .from('customers')
        .select('points')
        .eq('id', id)
        .single();
    final current = (r['points'] as num? ?? 0).toInt();
    final newPoints = (current + delta).clamp(0, 2147483647).toInt();

    final updated = await _client
        .from('customers')
        .update({'points': newPoints})
        .eq('id', id)
        .select('id');

    if ((updated as List).isEmpty) {
      throw Exception(
        'فشل تحديث نقاط العميل (${delta > 0 ? "+$delta" : "$delta"}) — '
        'تحقق من RLS policies على جدول customers في Supabase.\n'
        'شغّل ملف setup_points_table.sql في SQL Editor لإصلاح الصلاحيات.',
      );
    }
  }

  Future<int> updateLoginCode(int id, String code) async {
    try {
      await _client.from('customers').update({
        'login_code': code,
        'is_approved': true,
      }).eq('id', id);
      return 1;
    } catch (_) {
      return -1;
    }
  }

  Future<int> approveCustomer(int id, String loginCode) async {
    try {
      await _client.from('customers').update({
        'is_approved': true,
        'login_code': loginCode,
      }).eq('id', id);
      return 1;
    } catch (_) {
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getDebtors() async {
    final r = await _client
        .from('customers')
        .select('id, name, phone, balance')
        .eq('is_active', true)
        .gt('balance', 0)
        .order('balance', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  Future<int> delete(int id) async {
    try {
      await _client.from('customers').update({'is_active': false}).eq('id', id);
      return 1;
    } catch (_) {
      return -1;
    }
  }

  // ─── Customer invoices ────────────────────────────────────────────────────

  Future<int> insertCustomerInvoice(Map<String, dynamic> invoice) async {
    try {
      final result = await _client.from('customer_invoices').insert(invoice).select('id').single();
      return result['id'] as int;
    } catch (_) {
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerInvoices(int customerId) async {
    final r = await _client
        .from('customer_invoices')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  Future<List<Map<String, dynamic>>> getAllCustomerInvoices() async {
    final r = await _client
        .from('customer_invoices')
        .select('*, customers(name, phone)')
        .order('created_at', ascending: false);
    return r.map<Map<String, dynamic>>((row) {
      final m = Map<String, dynamic>.from(row as Map);
      final c = m['customers'] as Map?;
      m['customer_name'] = c?['name'];
      m['customer_phone'] = c?['phone'];
      m.remove('customers');
      return m;
    }).toList();
  }

  Future<void> updateInvoiceStatus(int invoiceId, String status) async {
    try {
      await _client.from('customer_invoices').update({'status': status}).eq('id', invoiceId);
    } catch (_) {}
  }

  // ─── Customer payments ────────────────────────────────────────────────────

  Future<int> insertCustomerPayment(Map<String, dynamic> payment) async {
    try {
      final result = await _client.from('customer_payments').insert(payment).select('id').single();
      return result['id'] as int;
    } catch (_) {
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerPayments(int customerId) async {
    final r = await _client
        .from('customer_payments')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  Future<List<Map<String, dynamic>>> getAllCustomerPayments() async {
    final r = await _client
        .from('customer_payments')
        .select('*, customers(name, phone)')
        .order('created_at', ascending: false);
    return r.map<Map<String, dynamic>>((row) {
      final m = Map<String, dynamic>.from(row as Map);
      final c = m['customers'] as Map?;
      m['customer_name'] = c?['name'];
      m['customer_phone'] = c?['phone'];
      m.remove('customers');
      return m;
    }).toList();
  }

  Future<void> updatePaymentStatus(int paymentId, String status) async {
    try {
      await _client.from('customer_payments').update({'status': status}).eq('id', paymentId);
    } catch (_) {}
  }
}
