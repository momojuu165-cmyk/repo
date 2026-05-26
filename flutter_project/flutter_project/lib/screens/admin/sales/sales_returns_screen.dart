import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../database/daos/invoice_dao.dart';
import '../../../models/sales_invoice.dart';
import '../../../providers/inventory_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class SalesReturnsScreen extends StatefulWidget {
  const SalesReturnsScreen({super.key});

  @override
  State<SalesReturnsScreen> createState() => _SalesReturnsScreenState();
}

class _SalesReturnsScreenState extends State<SalesReturnsScreen> {
  final _dao = InvoiceDao();
  List<SalesInvoice> _returns = [];
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
    final all = await _dao.getSalesInvoices(status: AppConstants.invoiceStatusReturn);
    if (mounted) {
      setState(() {
        _returns = all;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مرتجع مبيعات'),
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
                      Icon(Icons.assignment_return, size: 64, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('لا توجد مرتجعات مبيعات',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _returns.length,
                  itemBuilder: (ctx, i) {
                    final inv = _returns[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showReturnDetails(ctx, inv),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const CircleAvatar(
                                  backgroundColor: Color(AppColors.primaryInt),
                                  child: Icon(Icons.assignment_return, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(inv.invoiceNo,
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(AppFormatters.formatDateFromString(inv.date),
                                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Text(
                                  AppFormatters.formatCurrency(inv.total),
                                  style: const TextStyle(
                                      color: Color(AppColors.dangerInt),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ]),
                              if (inv.notes != null && inv.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, right: 48),
                                  child: Text('السبب: ${inv.notes}',
                                      style: const TextStyle(fontSize: 12, color: Colors.orange)),
                                ),
                              const Padding(
                                padding: EdgeInsets.only(top: 6, right: 48),
                                child: Text('اضغط لعرض تفاصيل المرتجع',
                                    style: TextStyle(fontSize: 11, color: Colors.blue)),
                              ),
                            ],
                          ),
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

  void _showNewReturnSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewReturnSheet(dao: _dao, onSaved: _load),
    );
  }

  void _showReturnDetails(BuildContext context, SalesInvoice inv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReturnDetailsSheet(dao: _dao, invoice: inv),
    );
  }
}

// ── Return details bottom sheet ───────────────────────────────────────────────

class _ReturnDetailsSheet extends StatefulWidget {
  final InvoiceDao dao;
  final SalesInvoice invoice;
  const _ReturnDetailsSheet({required this.dao, required this.invoice});

  @override
  State<_ReturnDetailsSheet> createState() => _ReturnDetailsSheetState();
}

class _ReturnDetailsSheetState extends State<_ReturnDetailsSheet> {
  List<SalesInvoiceItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.dao.getSalesInvoiceItems(widget.invoice.id!);
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Future<void> _printInvoice() async {
    final inv = widget.invoice;
    final items = _items;

    // Load Arabic Cairo fonts so all Arabic text renders correctly in the PDF
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'فاتورة مرتجع',
                style: pw.TextStyle(
                    font: arabicFontBold,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('رقم الفاتورة: ${inv.invoiceNo}',
                    style: pw.TextStyle(
                        font: arabicFontBold,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('التاريخ: ${inv.date}',
                    style: pw.TextStyle(font: arabicFont)),
              ],
            ),
            if (inv.notes != null && inv.notes!.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Text('السبب: ${inv.notes}',
                    style: pw.TextStyle(font: arabicFont)),
              ),
            pw.Divider(),
            pw.Row(children: [
              pw.Expanded(
                  child: pw.Text('المنتج',
                      style: pw.TextStyle(
                          font: arabicFontBold,
                          fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(
                  width: 60,
                  child: pw.Text('الكمية',
                      style: pw.TextStyle(
                          font: arabicFontBold,
                          fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(
                  width: 80,
                  child: pw.Text('السعر',
                      style: pw.TextStyle(
                          font: arabicFontBold,
                          fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(
                  width: 80,
                  child: pw.Text('الإجمالي',
                      style: pw.TextStyle(
                          font: arabicFontBold,
                          fontWeight: pw.FontWeight.bold))),
            ]),
            pw.Divider(),
            ...items.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(children: [
                    pw.Expanded(
                        child: pw.Text(item.itemName,
                            style: pw.TextStyle(font: arabicFont))),
                    pw.SizedBox(
                        width: 60,
                        child: pw.Text(
                            item.qty.toStringAsFixed(
                                item.qty % 1 == 0 ? 0 : 2),
                            style: pw.TextStyle(font: arabicFont))),
                    pw.SizedBox(
                        width: 80,
                        child: pw.Text(item.unitPrice.toStringAsFixed(2),
                            style: pw.TextStyle(font: arabicFont))),
                    pw.SizedBox(
                        width: 80,
                        child: pw.Text(
                            (item.qty * item.unitPrice).toStringAsFixed(2),
                            style: pw.TextStyle(font: arabicFont))),
                  ]),
                )),
            pw.Divider(),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('الإجمالي: ',
                      style: pw.TextStyle(
                          font: arabicFontBold,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14)),
                  pw.Text('${inv.total.toStringAsFixed(2)} ج.م',
                      style: pw.TextStyle(
                          font: arabicFontBold,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14)),
                ]),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            ),
            Row(children: [
              const Icon(Icons.assignment_return, color: Color(AppColors.primaryInt)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('مرتجع: ${inv.invoiceNo}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.print_outlined, color: Color(AppColors.primaryInt)),
                tooltip: 'طباعة المرتجع',
                onPressed: _loading ? null : _printInvoice,
              ),
              Text(AppFormatters.formatCurrency(inv.total),
                  style: const TextStyle(color: Color(AppColors.dangerInt), fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            Text(AppFormatters.formatDateFromString(inv.date),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if (inv.notes != null && inv.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('السبب: ${inv.notes}',
                    style: const TextStyle(color: Colors.orange, fontSize: 13)),
              ),
            const Divider(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('المنتجات المُرتجعة:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextButton.icon(
                onPressed: _loading ? null : _printInvoice,
                icon: const Icon(Icons.print, size: 16),
                label: const Text('طباعة'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(AppColors.primaryInt),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_items.isEmpty)
              const Text('لا توجد تفاصيل منتجات', style: TextStyle(color: Colors.grey))
            else
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.itemName,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${item.qty.toStringAsFixed(item.qty % 1 == 0 ? 0 : 2)} × ${AppFormatters.formatCurrency(item.unitPrice)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text(AppFormatters.formatCurrency(item.qty * item.unitPrice),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      ]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ReturnLineItem {
  final int itemId;
  final String itemName;
  final String? barcode;
  double qty;
  final double unitPrice;

  _ReturnLineItem({
    required this.itemId,
    required this.itemName,
    this.barcode,
    this.qty = 1,
    required this.unitPrice,
  });

  double get total => qty * unitPrice;
}

class _NewReturnSheet extends StatefulWidget {
  final InvoiceDao dao;
  final VoidCallback onSaved;

  const _NewReturnSheet({required this.dao, required this.onSaved});

  @override
  State<_NewReturnSheet> createState() => _NewReturnSheetState();
}

class _NewReturnSheetState extends State<_NewReturnSheet> {
  final _reasonCtrl = TextEditingController();
  List<_ReturnLineItem> _items = [];
  List<SalesInvoice> _invoices = [];
  SalesInvoice? _selectedInvoice;
  List<SalesInvoiceItem> _invoiceItems = [];
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
    final invs = await widget.dao.getSalesInvoices();
    if (mounted) {
      setState(() {
        _invoices = invs
            .where((i) => i.status != AppConstants.invoiceStatusReturn)
            .toList();
        _loadingInvoices = false;
      });
    }
  }

  Future<void> _selectInvoice(SalesInvoice inv) async {
    final items = await widget.dao.getSalesInvoiceItems(inv.id!);
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
      final invoiceId = await widget.dao.insertSalesInvoice(SalesInvoice(
        invoiceNo: 'RET-${DateTime.now().millisecondsSinceEpoch}',
        customerId: _selectedInvoice?.customerId,
        date: now.substring(0, 10),
        subtotal: _total,
        discount: 0,
        total: _total,
        paymentType: 'cash',
        amountPaid: _total,
        remaining: 0,
        status: AppConstants.invoiceStatusReturn,
        notes: _reasonCtrl.text.trim().isEmpty
            ? null
            : _reasonCtrl.text.trim(),
        createdAt: now,
      ));

      final inv = context.read<InventoryProvider>();
      for (final item in _items) {
        await widget.dao.insertSalesInvoiceItem(SalesInvoiceItem(
          invoiceId: invoiceId,
          itemId: item.itemId,
          itemName: item.itemName,
          barcode: item.barcode,
          qty: item.qty,
          priceType: 'retail',
          unitPrice: item.unitPrice,
          discount: 0,
          total: item.total,
        ));
        // Return stock to warehouse
        await inv.adjustQuantity(item.itemId, item.qty);
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
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('مرتجع مبيعات جديد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loadingInvoices)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<SalesInvoice>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'اختر الفاتورة الأصلية',
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
              const SizedBox(height: 4),
              ..._invoiceItems.map((ii) {
                final inReturn = _items.any((r) => r.itemId == ii.itemId);
                return CheckboxListTile(
                  dense: true,
                  activeColor: const Color(AppColors.primaryInt),
                  title: Text(ii.itemName),
                  subtitle: Text(
                      'الكمية: ${ii.qty} | السعر: ${AppFormatters.formatCurrency(ii.unitPrice)}'),
                  value: inReturn,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _items.add(_ReturnLineItem(
                          itemId: ii.itemId,
                          itemName: ii.itemName,
                          barcode: ii.barcode,
                          qty: ii.qty,
                          unitPrice: ii.unitPrice,
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppColors.primaryInt),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _saving || _items.isEmpty ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ المرتجع'),
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
