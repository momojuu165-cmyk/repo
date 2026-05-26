import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/sales_invoice.dart';
import '../../models/purchase_invoice.dart';
import '../../models/expense.dart';

class InvoiceDao {
  SupabaseClient get _client => Supabase.instance.client;

  // ─── Sales Invoices ───────────────────────────────────────────────────────

  Future<int> insertSalesInvoice(SalesInvoice inv) async {
    try {

    final map = inv.toMap()..remove('id');
    final result = await _client.from('sales_invoices').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<int> insertSalesInvoiceItem(SalesInvoiceItem item) async {
    try {

    final map = item.toMap()..remove('id');
    final result = await _client.from('sales_invoice_items').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<SalesInvoice?> getSalesInvoiceById(int id) async {
    try {

    final r = await _client.from('sales_invoices').select().eq('id', id);
    return r.isEmpty ? null : SalesInvoice.fromMap(r.first);
    } catch (_) {
      return null;
    }
}

  Future<List<SalesInvoice>> getSalesInvoices({
    int? customerId,
    String? fromDate,
    String? toDate,
    String? status,
    int? employeeId,
  }) async {
    try {

    var q = _client.from('sales_invoices').select();
    if (customerId != null) q = q.eq('customer_id', customerId) as dynamic;
    if (fromDate != null) q = (q as dynamic).gte('date', fromDate);
    if (toDate != null) q = (q as dynamic).lte('date', toDate);
    if (status != null) q = (q as dynamic).eq('status', status);
    if (employeeId != null) q = (q as dynamic).eq('employee_id', employeeId);
    final r = await (q as dynamic).order('created_at', ascending: false);
    return (r as List).map<SalesInvoice>((m) => SalesInvoice.fromMap(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<SalesInvoiceItem>> getSalesInvoiceItems(int invoiceId) async {
    try {

    final r = await _client
        .from('sales_invoice_items')
        .select()
        .eq('invoice_id', invoiceId);
    return r.map((m) => SalesInvoiceItem.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  Future<SalesInvoice?> findSalesInvoiceByBarcode(String barcode) async {
    try {

    // Find invoice items by barcode, then get the invoice
    final items = await _client
        .from('sales_invoice_items')
        .select('invoice_id')
        .eq('barcode', barcode)
        .order('invoice_id', ascending: false)
        .limit(1);
    if (items.isEmpty) return null;
    final invoiceId = items.first['invoice_id'] as int;
    return getSalesInvoiceById(invoiceId);
    } catch (_) {
      return null;
    }
}

  Future<int> updateSalesInvoiceStatus(int id, String status,
      {double? remaining}) async {
    try {

    final map = <String, dynamic>{'status': status};
    if (remaining != null) map['remaining'] = remaining;
    await _client.from('sales_invoices').update(map).eq('id', id);
    return 1;
    } catch (_) {
      return -1;
    }
}

  // ─── Purchase Invoices ────────────────────────────────────────────────────

  Future<int> insertPurchaseInvoice(PurchaseInvoice inv) async {
    try {

    final map = inv.toMap()..remove('id');
    final result = await _client.from('purchase_invoices').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<int> insertPurchaseInvoiceItem(PurchaseInvoiceItem item) async {
    try {

    final map = item.toMap()..remove('id');
    final result = await _client.from('purchase_invoice_items').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<List<PurchaseInvoice>> getPurchaseInvoices({
    int? supplierId,
    String? fromDate,
    String? toDate,
  }) async {
    try {

    var q = _client.from('purchase_invoices').select();
    if (supplierId != null) q = q.eq('supplier_id', supplierId) as dynamic;
    if (fromDate != null) q = (q as dynamic).gte('date', fromDate);
    if (toDate != null) q = (q as dynamic).lte('date', toDate);
    final r = await (q as dynamic).order('created_at', ascending: false);
    return (r as List).map<PurchaseInvoice>((m) => PurchaseInvoice.fromMap(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
}

  Future<List<PurchaseInvoiceItem>> getPurchaseInvoiceItems(int invoiceId) async {
    try {

    final r = await _client
        .from('purchase_invoice_items')
        .select()
        .eq('invoice_id', invoiceId);
    return r.map((m) => PurchaseInvoiceItem.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
}

  // ─── Expenses ─────────────────────────────────────────────────────────────

  Future<int> insertExpense(Expense expense) async {
    try {

    final map = expense.toMap()..remove('id');
    final result = await _client.from('expenses').insert(map).select('id').single();
    return result['id'] as int;
    } catch (_) {
      return -1;
    }
}

  Future<List<Expense>> getExpenses({
    String? fromDate,
    String? toDate,
    String? type,
  }) async {
    try {

    var q = _client.from('expenses').select();
    if (fromDate != null) q = q.gte('date', fromDate) as dynamic;
    if (toDate != null) q = (q as dynamic).lte('date', toDate);
    if (type != null) q = (q as dynamic).eq('type', type);
    final r = await (q as dynamic).order('date', ascending: false);
    return (r as List).map<Expense>((m) => Expense.fromMap(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
}

  // ─── Reports ──────────────────────────────────────────────────────────────

  Future<Map<String, double>> getSalesSummary(
      String fromDate, String toDate) async {
    try {

    final r = await _client
        .from('sales_invoices')
        .select('total, discount, amount_paid, remaining')
        .gte('date', fromDate)
        .lte('date', toDate)
        .neq('status', 'return');

    double totalSales = 0, totalDiscounts = 0, totalCollected = 0, totalRemaining = 0;
    for (final row in r) {
      totalSales += (row['total'] as num? ?? 0).toDouble();
      totalDiscounts += (row['discount'] as num? ?? 0).toDouble();
      totalCollected += (row['amount_paid'] as num? ?? 0).toDouble();
      totalRemaining += (row['remaining'] as num? ?? 0).toDouble();
    }
    return {
      'total_sales': totalSales,
      'total_discounts': totalDiscounts,
      'total_collected': totalCollected,
      'total_remaining': totalRemaining,
    };
    } catch (_) {
      return {};
    }
}

  Future<List<Map<String, dynamic>>> getItemMovement(int itemId) async {
    final sales = await _client
        .from('sales_invoice_items')
        .select('qty, unit_price, sales_invoices!inner(date, invoice_no)')
        .eq('item_id', itemId);
    final purchases = await _client
        .from('purchase_invoice_items')
        .select('qty, unit_cost, purchase_invoices!inner(date, invoice_no)')
        .eq('item_id', itemId);

    final result = <Map<String, dynamic>>[];
    for (final s in sales) {
      final inv = s['sales_invoices'] as Map?;
      result.add({
        'type': 'sale',
        'qty': s['qty'],
        'unit_price': s['unit_price'],
        'date': inv?['date'],
        'invoice_no': inv?['invoice_no'],
      });
    }
    for (final p in purchases) {
      final inv = p['purchase_invoices'] as Map?;
      result.add({
        'type': 'purchase',
        'qty': p['qty'],
        'unit_price': p['unit_cost'],
        'date': inv?['date'],
        'invoice_no': inv?['invoice_no'],
      });
    }
    result.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return result;
  }
}
