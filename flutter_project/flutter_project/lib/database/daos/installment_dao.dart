import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/installment.dart';

class InstallmentDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<int> insertInstallment(Installment inst) async {
    try {

    final map = inst.toMap()..remove('id');
    final result = await _client.from('installments').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<int> insertPayment(InstallmentPayment payment) async {
    try {

    final map = payment.toMap()..remove('id');
    final result = await _client.from('installment_payments').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<Installment?> findById(int id) async {
    try {

    final r = await _client.from('installments').select().eq('id', id);
    return r.isEmpty ? null : Installment.fromMap(r.first);
    } catch (_) {
      return null;
    }
}

  Future<List<Installment>> getByCustomer(int customerId) async {
    try {

    final r = await _client
        .from('installments')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return r.map((m) => Installment.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<Map<String, dynamic>>> getInstallmentsWithCustomer({
    String? status,
    String? storeType,
  }) async {
    var q = _client.from('installments').select('*');
    if (status != null)    q = (q as dynamic).eq('status', status);
    if (storeType != null) q = (q as dynamic).eq('store_type', storeType);
    final List instRows = await (q as dynamic).order('created_at', ascending: false);

    if (instRows.isEmpty) return [];

    final customerIds = instRows
        .map((r) => r['customer_id'])
        .whereType<int>()
        .toSet()
        .toList();

    Map<int, Map<String, dynamic>> customerMap = {};
    if (customerIds.isNotEmpty) {
      try {
        final custRows = await _client
            .from('customers')
            .select('id, name, phone')
            .inFilter('id', customerIds);
        for (final c in custRows) {
          customerMap[c['id'] as int] =
              Map<String, dynamic>.from(c);
        }
      } catch (_) {}
    }

    return instRows.map((row) {
      final m = Map<String, dynamic>.from(row as Map);
      final cid = m['customer_id'] as int?;
      final cust = cid != null ? customerMap[cid] : null;
      m['customer_name'] = cust?['name'];
      m['customer_phone'] = cust?['phone'];
      return m;
    }).toList();
  }

  Future<List<InstallmentPayment>> getPayments(int installmentId) async {
    try {

    final r = await _client
        .from('installment_payments')
        .select()
        .eq('installment_id', installmentId)
        .order('due_date', ascending: true);
    return r.map((m) => InstallmentPayment.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<InstallmentPayment>> getOverduePayments() async {
    try {

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final r = await _client
        .from('installment_payments')
        .select()
        .eq('status', 'pending')
        .lt('due_date', today)
        .order('due_date', ascending: true);
    return r.map((m) => InstallmentPayment.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  /// Returns payments whose due_date falls in the given month (YYYY-MM),
  /// regardless of paid/overdue status. Useful for month-specific overdue views.
  Future<List<InstallmentPayment>> getOverduePaymentsByMonth(
      int year, int month) async {
    try {

    final monthStr =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final r = await _client
        .from('installment_payments')
        .select()
        .inFilter('status', ['pending', 'overdue'])
        .like('due_date', '$monthStr%')
        .order('due_date', ascending: true);
    return r.map((m) => InstallmentPayment.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  /// Deletes an installment and all its child payments atomically.
  Future<void> deleteInstallment(int installmentId) async {
    try {

    // Must delete child payments first (FK constraint)
    await _client
        .from('installment_payments')
        .delete()
        .eq('installment_id', installmentId);
    await _client
        .from('installments')
        .delete()
        .eq('id', installmentId);
    } catch (_) {}
}

  Future<int> markPaymentPaid(int paymentId, {
    String paymentMethod = 'in_store',
    String? receiptPath,
    int? confirmedBy,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final paymentRows = await _client
        .from('installment_payments')
        .select('amount, installment_id')
        .eq('id', paymentId)
        .limit(1);
    if (paymentRows.isEmpty) return 0;
    final amount = (paymentRows.first['amount'] as num).toDouble();
    final installmentId = paymentRows.first['installment_id'] as int;

    try {
      await _client.from('installment_payments').update({
        'status': 'paid',
        'paid_date': today,
        'payment_method': paymentMethod,
        'paid_amount': amount,
        if (receiptPath != null) 'receipt_path': receiptPath,
        if (confirmedBy != null) 'confirmed_by': confirmedBy,
        'confirmed_at': today,
      }).eq('id', paymentId);
    } catch (_) {
      await _client.from('installment_payments').update({
        'status': 'paid',
        'paid_date': today,
      }).eq('id', paymentId);
    }

    final instRows = await _client
        .from('installments')
        .select('remaining_amount')
        .eq('id', installmentId)
        .limit(1);
    if (instRows.isNotEmpty) {
      final current =
          (instRows.first['remaining_amount'] as num?)?.toDouble() ?? 0.0;
      final newRemaining = (current - amount).clamp(0.0, double.infinity);
      await _client.from('installments').update({
        'remaining_amount': newRemaining,
      }).eq('id', installmentId);
    }

    return 1;
  }

  /// Partial payment: records paidAmount, carries over the rest to next payment.
  Future<void> partialPayment(
    int paymentId,
    double paidAmount, {
    String? notes,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final rows = await _client
        .from('installment_payments')
        .select()
        .eq('id', paymentId)
        .limit(1);
    if (rows.isEmpty) return;

    final row = rows.first as Map<String, dynamic>;
    final fullAmount = (row['amount'] as num).toDouble();
    final carried = (row['carried_amount'] as num? ?? 0).toDouble();
    final totalDue = fullAmount + carried;
    final remaining = totalDue - paidAmount;
    final installmentId = row['installment_id'] as int;

    // Update this payment as partial
    try {
      await _client.from('installment_payments').update({
        'status': 'partial',
        'paid_date': today,
        'paid_amount': paidAmount,
        'carried_amount': carried,
        if (notes != null) 'notes': notes,
      }).eq('id', paymentId);
    } catch (_) {
      await _client.from('installment_payments').update({
        'status': 'partial',
        'paid_date': today,
      }).eq('id', paymentId);
    }

    // Add remaining to next payment if exists
    if (remaining > 0) {
      final nextPayments = await _client
          .from('installment_payments')
          .select()
          .eq('installment_id', installmentId)
          .inFilter('status', ['pending', 'overdue'])
          .order('due_date', ascending: true)
          .limit(1);

      if ((nextPayments as List).isNotEmpty) {
        final next = nextPayments.first as Map<String, dynamic>;
        final currentCarried = (next['carried_amount'] as num? ?? 0).toDouble();
        try {
          await _client.from('installment_payments').update({
            'carried_amount': currentCarried + remaining,
          }).eq('id', next['id'] as int);
        } catch (_) {}
      }
    }

    // Deduct paidAmount from installment remaining
    final instRows = await _client
        .from('installments')
        .select('remaining_amount')
        .eq('id', installmentId)
        .limit(1);
    if ((instRows as List).isNotEmpty) {
      final current =
          (instRows.first['remaining_amount'] as num?)?.toDouble() ?? 0.0;
      final newRemaining = (current - paidAmount).clamp(0.0, double.infinity);
      await _client.from('installments').update({
        'remaining_amount': newRemaining,
      }).eq('id', installmentId);
    }
  }

  /// Postpone a payment: marks it postponed, moves due_date 1 month forward.
  Future<void> postponePayment(int paymentId, String reason) async {
    final rows = await _client
        .from('installment_payments')
        .select()
        .eq('id', paymentId)
        .limit(1);
    if (rows.isEmpty) return;

    final row = rows.first as Map<String, dynamic>;
    final dueDate = row['due_date'] as String;

    // Move due date 1 month forward
    try {
      final d = DateTime.parse(dueDate);
      final newDate = DateTime(d.year, d.month + 1, d.day);
      final newDateStr = newDate.toIso8601String().substring(0, 10);

      await _client.from('installment_payments').update({
        'status': 'postponed',
        'due_date': newDateStr,
        'postpone_reason': reason,
      }).eq('id', paymentId);
    } catch (_) {
      await _client.from('installment_payments').update({
        'status': 'postponed',
        'postpone_reason': reason,
      }).eq('id', paymentId);
    }
  }

  Future<void> checkAndUpdateInstallmentStatus(int installmentId) async {
    try {

    final payments = await getPayments(installmentId);
    final allPaid = payments.every((p) => p.isPaid);
    if (allPaid && payments.isNotEmpty) {
      await _client.from('installments').update({
        'status': 'completed',
      }).eq('id', installmentId);
    }
    } catch (_) {}
}

  Future<Map<String, dynamic>> getInstallmentSummary(int installmentId) async {
    try {

    final payments = await getPayments(installmentId);
    final paid = payments.where((p) => p.isPaid).length;
    final postponed = payments.where((p) => p.isPostponed).length;
    final partial = payments.where((p) => p.isPartial).length;
    final total = payments.length;
    final paidAmount =
        payments.where((p) => p.isPaid).fold(0.0, (s, p) => s + p.amount);
    final partialPaidAmount =
        payments.where((p) => p.isPartial).fold(0.0, (s, p) => s + p.paidAmount);
    final remaining =
        payments.where((p) => !p.isPaid && !p.isPartial).fold(0.0, (s, p) => s + p.amount);
    return {
      'total': total,
      'paid': paid,
      'postponed': postponed,
      'partial': partial,
      'remaining_count': total - paid,
      'paid_amount': paidAmount + partialPaidAmount,
      'remaining_amount': remaining,
    };
    } catch (_) {
      return {};
    }
}

  static List<InstallmentPayment> generatePaymentSchedule({
    required int installmentId,
    required int numInstallments,
    required double monthlyAmount,
    required DateTime startDate,
  }) {
    return List.generate(numInstallments, (i) {
      final due =
          DateTime(startDate.year, startDate.month + i, startDate.day);
      return InstallmentPayment(
        installmentId: installmentId,
        dueDate: due.toIso8601String().substring(0, 10),
        amount: monthlyAmount,
        status: 'pending',
      );
    });
  }
}
