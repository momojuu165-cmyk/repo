import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../database/daos/invoice_dao.dart';
import '../../../models/purchase_invoice.dart';
import '../../../providers/inventory_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class PurchaseReturnsScreen extends StatefulWidget {
  const PurchaseReturnsScreen({super.key});

  @override
  State<PurchaseReturnsScreen> createState() => _PurchaseReturnsScreenState();
}

class _PurchaseReturnsScreenState extends State<PurchaseReturnsScreen> {
  final _dao = InvoiceDao();
  List<Map<String, dynamic>> _returns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadAll();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('purchase_returns')
          .select()
          .order('created_at', ascending: false);
      if (mounted) setState(() { _returns = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مرتجع مشتريات'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _returns.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.keyboard_return, size: 64, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('لا توجد مرتجعات مشتريات',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _returns.length,
                  itemBuilder: (ctx, i) {
                    final r = _returns[i];
                    final returnNo = r['return_no'] as String? ?? '';
                    final date = r['date'] as String? ?? '';
                    final total = (r['total'] as num? ?? 0).toDouble();
                    final reason = r['reason'] as String? ?? '';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(AppColors.primaryInt),
                          child: Icon(Icons.keyboard_return, color: Colors.white),
                        ),
                        title: Text(returnNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(date),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppFormatters.formatCurrency(total),
                              style: const TextStyle(
                                  color: Color(AppColors.dangerInt),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.print_rounded, color: Colors.blueGrey),
                              tooltip: 'طباعة',
                              onPressed: () => _printReturn(
                                returnNo: returnNo,
                                date: date,
                                total: total,
                                reason: reason,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showNewReturnSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('مرتجع جديد'),
      ),
    );
  }

  Future<void> _printReturn({
    required String returnNo,
    required String date,
    required double total,
    required String reason,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('مرتجع مشتريات',
                    style: pw.TextStyle(font: boldFont, fontSize: 22)),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('رقم المرتجع: $returnNo',
                      style: pw.TextStyle(font: arabicFont, fontSize: 13)),
                  pw.Text('التاريخ: $date',
                      style: pw.TextStyle(font: arabicFont, fontSize: 13)),
                ],
              ),
              pw.SizedBox(height: 8),
              if (reason.isNotEmpty)
                pw.Text('سبب الإرجاع: $reason',
                    style: pw.TextStyle(font: arabicFont, fontSize: 12)),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('الإجمالي: ${total.toStringAsFixed(2)} ج.م',
                      style: pw.TextStyle(font: boldFont, fontSize: 16)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'مرتجع-$returnNo.pdf',
    );
  }

  void _showNewReturnSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewPurchaseReturnSheet(dao: _dao, onSaved: _load),
    );
  }
}

class _ReturnItem {
  final int itemId;
  final String itemName;
  double qty;
  double unitCost;

  _ReturnItem({
    required this.itemId,
    required this.itemName,
    this.qty = 1,
    required this.unitCost,
  });

  double get total => qty * unitCost;
}

class _NewPurchaseReturnSheet extends StatefulWidget {
  final InvoiceDao dao;
  final VoidCallback onSaved;

  const _NewPurchaseReturnSheet({required this.dao, required this.onSaved});

  @override
  State<_NewPurchaseReturnSheet> createState() =>
      _NewPurchaseReturnSheetState();
}

class _NewPurchaseReturnSheetState extends State<_NewPurchaseReturnSheet> {
  final _reasonCtrl = TextEditingController();
  List<_ReturnItem> _items = [];
  List<PurchaseInvoice> _invoices = [];
  PurchaseInvoice? _selectedInvoice;
  List<PurchaseInvoiceItem> _invoiceItems = [];
  bool _saving = false;
  bool _loadingInvoices = true;

  double get _total => _items.fold(0.0, (s, i) => s + i.total);

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    final invs = await widget.dao.getPurchaseInvoices();
    if (mounted) {
      setState(() {
        _invoices = invs;
        _loadingInvoices = false;
      });
    }
  }

  Future<void> _selectInvoice(PurchaseInvoice inv) async {
    final items = await widget.dao.getPurchaseInvoiceItems(inv.id!);
    setState(() {
      _selectedInvoice = inv;
      _invoiceItems = items;
      _items = [];
    });
  }

  Future<void> _save() async {
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    try {
      final result = await Supabase.instance.client.from('purchase_returns').insert({
        'return_no': 'PRET-${DateTime.now().millisecondsSinceEpoch}',
        'original_invoice_id': _selectedInvoice?.id,
        'total': _total,
        'reason': _reasonCtrl.text.trim(),
        'date': now.substring(0, 10),
        'created_at': now,
      }).select('id').single();
      final returnId = result['id'] as int;

      final inv = context.read<InventoryProvider>();
      for (final item in _items) {
        await Supabase.instance.client.from('purchase_return_items').insert({
          'return_id': returnId,
          'item_id': item.itemId,
          'item_name': item.itemName,
          'qty': item.qty,
          'unit_cost': item.unitCost,
          'total': item.total,
        });
        // Deduct from stock (returning to supplier)
        await inv.adjustQuantity(item.itemId, -item.qty);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('مرتجع مشتريات جديد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loadingInvoices)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<PurchaseInvoice>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'اختر فاتورة المشتريات',
                  border: OutlineInputBorder(),
                ),
                items: _invoices
                    .map((i) => DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${i.invoiceNo} — ${AppFormatters.formatCurrency(i.total)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) _selectInvoice(v);
                },
              ),
            if (_invoiceItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('اختر الأصناف المُرجَعة:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              ..._invoiceItems.map((ii) {
                final inReturn = _items.any((r) => r.itemId == ii.itemId);
                return CheckboxListTile(
                  dense: true,
                  activeColor: const Color(AppColors.primaryInt),
                  title: Text(ii.itemName),
                  subtitle: Text(
                      'الكمية: ${ii.qty} | التكلفة: ${AppFormatters.formatCurrency(ii.unitCost)}'),
                  value: inReturn,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _items.add(_ReturnItem(
                          itemId: ii.itemId!,
                          itemName: ii.itemName,
                          qty: ii.qty,
                          unitCost: ii.unitCost,
                        ));
                      } else {
                        _items.removeWhere((r) => r.itemId == ii.itemId);
                      }
                    });
                  },
                );
              }),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'سبب الإرجاع',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الإجمالي: ${AppFormatters.formatCurrency(_total)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppColors.primaryInt),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _saving || _items.isEmpty ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
