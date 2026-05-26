import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../models/item.dart';
import '../../../models/customer.dart';
import '../../../models/sales_invoice.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../database/daos/invoice_dao.dart';

// ─── colours ──────────────────────────────────────────────────────────────────
const _kPrimary = Color(AppColors.primaryInt);
const _kGreen   = Color(0xFF2E7D32);
const _kRed     = Color(0xFFB71C1C);

// ═══════════════════════════════════════════════════════════════════════════════
class PosInvoiceScreen extends StatefulWidget {
  const PosInvoiceScreen({super.key});
  @override
  State<PosInvoiceScreen> createState() => _PosInvoiceScreenState();
}

class _PosInvoiceScreenState extends State<PosInvoiceScreen> {

  // ── invoice header ──────────────────────────────────────────────────────────
  final _invoiceNoCtrl  = TextEditingController();
  final _dateCtrl       = TextEditingController();
  final _warehouseCtrl  = TextEditingController(text: 'المخزن الرئيسي');
  final _notesCtrl      = TextEditingController();
  String _saleType      = 'cash';
  String _invoiceStatus = 'new';
  String _paymentMethod = 'cash';

  // ── customer ────────────────────────────────────────────────────────────────
  Customer? _customer;
  double _customerDiscount = 0;
  double _previousBalance  = 0;
  double _amountPaid       = 0;
  final _amountPaidCtrl  = TextEditingController(text: '0');
  final _custDiscCtrl    = TextEditingController(text: '0');

  // ── cart ────────────────────────────────────────────────────────────────────
  final List<_CartItem> _cart = [];

  // ── item browser ────────────────────────────────────────────────────────────
  final _searchCtrl       = TextEditingController();
  String _searchQuery     = '';
  String? _selectedCategory;

  // ── misc ────────────────────────────────────────────────────────────────────
  double _taxRate  = 0;
  double _expenses = 0;
  final _taxCtrl = TextEditingController(text: '0');
  final _expCtrl = TextEditingController(text: '0');
  bool _saving    = false;

  // ── suspended invoice being edited (null = new) ──────────────────────────────
  int? _editingInvoiceId;

  // ── computed ────────────────────────────────────────────────────────────────
  double get _subtotal     => _cart.fold(0.0, (s, i) => s + i.lineTotal);
  double get _itemDisc     => _cart.fold(0.0, (s, i) => s + i.qty * i.unitPrice * (i.discountPct / 100));
  double get _custDiscAmt  => _subtotal * (_customerDiscount / 100);
  double get _netBefore    => _subtotal - _itemDisc - _custDiscAmt;
  double get _taxAmt       => _netBefore * (_taxRate / 100);
  double get _total        => _netBefore + _taxAmt + _expenses;
  double get _remaining    => _total - _amountPaid + _previousBalance;

  // ── filtered items ──────────────────────────────────────────────────────────
  List<Item> _filteredItems(List<Item> all) {
    var list = all.where((i) => !i.isBlocked).toList();
    if (_selectedCategory != null) list = list.where((i) => i.category == _selectedCategory).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((i) => i.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<String> _categories(List<Item> all) {
    final cats = all.map((i) => i.category).whereType<String>().toSet().toList();
    cats.sort();
    return cats;
  }

  @override
  void initState() {
    super.initState();
    _genInvoiceNo();
    _dateCtrl.text = AppFormatters.todayStr();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadAll();
      context.read<CustomerProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    for (final c in [_invoiceNoCtrl, _dateCtrl, _warehouseCtrl, _notesCtrl,
        _amountPaidCtrl, _custDiscCtrl, _searchCtrl, _taxCtrl, _expCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── helpers ─────────────────────────────────────────────────────────────────
  void _genInvoiceNo() {
    final ts = DateTime.now();
    _invoiceNoCtrl.text =
        'INV-${ts.year}${ts.month.toString().padLeft(2,'0')}${ts.day.toString().padLeft(2,'0')}'
        '-${ts.millisecond.toString().padLeft(4,'0')}';
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // ── cart actions ─────────────────────────────────────────────────────────────
  void _addToCart(Item item) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.itemId == item.id);
      if (idx >= 0) {
        _cart[idx] = _cart[idx].copyWith(qty: _cart[idx].qty + 1);
      } else {
        _cart.add(_CartItem(
          itemId: item.id!,
          name: item.name,
          stockQty: item.quantity,
          qty: 1,
          unitPrice: item.effectiveCashPrice > 0 ? item.effectiveCashPrice : item.priceRetail,
          discountPct: item.discountRate,
        ));
      }
    });
  }

  void _changeQty(int idx, double delta) {
    final q = (_cart[idx].qty + delta).clamp(1, 99999).toDouble();
    setState(() => _cart[idx] = _cart[idx].copyWith(qty: q));
  }

  void _editCartItem(int idx) {
    final item = _cart[idx];
    final qCtrl = TextEditingController(text: item.qty.toStringAsFixed(item.qty == item.qty.roundToDouble() ? 0 : 2));
    final pCtrl = TextEditingController(text: item.unitPrice.toStringAsFixed(2));
    final dCtrl = TextEditingController(text: item.discountPct.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.edit_outlined, color: _kPrimary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(item.name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dlgField(qCtrl, 'الكمية', Icons.numbers),
          const SizedBox(height: 10),
          _dlgField(pCtrl, 'سعر الوحدة (ج.م)', Icons.attach_money),
          const SizedBox(height: 10),
          _dlgField(dCtrl, 'نسبة الخصم %', Icons.discount_outlined),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _cart[idx] = item.copyWith(
                  qty: double.tryParse(qCtrl.text) ?? item.qty,
                  unitPrice: double.tryParse(pCtrl.text) ?? item.unitPrice,
                  discountPct: double.tryParse(dCtrl.text) ?? item.discountPct,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  TextField _dlgField(TextEditingController c, String label, IconData icon) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label, prefixIcon: Icon(icon, size: 18),
      border: const OutlineInputBorder(), isDense: true,
    ),
  );

  // ── pay all ──────────────────────────────────────────────────────────────────
  void _payAll() {
    final amount = _total;
    setState(() {
      _amountPaid = amount;
      _amountPaidCtrl.text = amount.toStringAsFixed(2);
      _invoiceStatus = 'paid';
    });
  }

  // ── pick date ────────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dateCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
      });
    }
  }

  // ── pick customer ────────────────────────────────────────────────────────────
  void _pickCustomer() async {
    final customers = context.read<CustomerProvider>().customers;
    final searchCtrl = TextEditingController();
    List<Customer> filtered = List.from(customers);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          builder: (_, ctrl) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Text('اختر عميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ابحث باسم أو رقم هاتف...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(), isDense: true,
                ),
                onChanged: (q) => ss(() {
                  filtered = customers.where((c) =>
                      c.name.toLowerCase().contains(q.toLowerCase()) ||
                      (c.phone ?? '').contains(q)).toList();
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _kPrimary.withValues(alpha: 0.1),
                        child: Text(c.name[0], style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(c.phone ?? '—'),
                      trailing: Text(
                        AppFormatters.formatCurrency(c.balance ?? 0),
                        style: TextStyle(
                          color: (c.balance ?? 0) > 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold, fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() { _customer = c; _previousBalance = c.balance ?? 0; });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }

  // ── save invoice ─────────────────────────────────────────────────────────────
  Future<void> _saveInvoice({String? overrideStatus}) async {
    if (_cart.isEmpty) { _snack('أضف صنفاً على الأقل', Colors.orange); return; }
    final status = overrideStatus ?? _invoiceStatus;
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      final now  = DateTime.now().toIso8601String();
      final invoice = SalesInvoice(
        invoiceNo   : _invoiceNoCtrl.text.trim(),
        customerId  : _customer?.id,
        employeeId  : auth.currentUser?.id,
        date        : _dateCtrl.text,
        subtotal    : _subtotal,
        discount    : _itemDisc + _custDiscAmt,
        total       : _total,
        paymentType : _saleType,
        amountPaid  : _amountPaid,
        remaining   : _remaining,
        status      : status,
        notes       : _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt   : now,
      );
      final dao = InvoiceDao();
      final id  = await dao.insertSalesInvoice(invoice);
      for (final c in _cart) {
        await dao.insertSalesInvoiceItem(SalesInvoiceItem(
          invoiceId : id,
          itemId    : c.itemId,
          itemName  : c.name,
          qty       : c.qty,
          unitPrice : c.unitPrice,
          discount  : c.unitPrice * (c.discountPct / 100),
          total     : c.lineTotal,
        ));
      }
      if (status == 'pending') {
        _snack('✓ تم تعليق الفاتورة', Colors.orange);
      } else {
        _snack('✓ تم حفظ الفاتورة بنجاح', Colors.green);
      }
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _resetInvoice();
    } catch (e) {
      _snack('خطأ: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── reset ────────────────────────────────────────────────────────────────────
  void _resetInvoice() {
    setState(() {
      _cart.clear();
      _customer        = null;
      _customerDiscount= 0; _custDiscCtrl.text = '0';
      _previousBalance = 0;
      _amountPaid      = 0; _amountPaidCtrl.text = '0';
      _notesCtrl.clear();
      _taxRate  = 0; _taxCtrl.text = '0';
      _expenses = 0; _expCtrl.text = '0';
      _invoiceStatus = 'new';
      _saleType      = 'cash';
      _paymentMethod = 'cash';
      _editingInvoiceId = null;
      _dateCtrl.text = AppFormatters.todayStr();
    });
    _genInvoiceNo();
  }

  // ── suspend invoice ──────────────────────────────────────────────────────────
  void _suspendInvoice() async {
    if (_cart.isEmpty) { _snack('السلة فارغة', Colors.orange); return; }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعليق الفاتورة'),
        content: const Text('سيتم حفظ الفاتورة الحالية كـ "معلقة" ويمكن استرجاعها لاحقاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تعليق'),
          ),
        ],
      ),
    );
    if (confirm == true) await _saveInvoice(overrideStatus: 'pending');
  }

  // ── restore pending invoice ──────────────────────────────────────────────────
  void _restoreInvoice() async {
    setState(() => _saving = true);
    List<SalesInvoice> pending = [];
    try {
      pending = await InvoiceDao().getSalesInvoices(status: 'pending');
    } catch (e) {
      _snack('خطأ في تحميل الفواتير: $e', Colors.red);
      setState(() => _saving = false);
      return;
    }
    setState(() => _saving = false);
    if (!mounted) return;

    if (pending.isEmpty) {
      _snack('لا توجد فواتير معلقة', Colors.grey);
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Row(children: [
              Icon(Icons.restore_page, color: Colors.indigo),
              SizedBox(width: 8),
              Text('فواتير معلقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: pending.length,
                itemBuilder: (_, i) {
                  final inv = pending[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.pause, color: Colors.white, size: 18)),
                      title: Text(inv.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${inv.date}  •  ${AppFormatters.formatCurrency(inv.total)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _loadSuspendedInvoice(inv);
                      },
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _loadSuspendedInvoice(SalesInvoice inv) async {
    setState(() => _saving = true);
    try {
      final items = await InvoiceDao().getSalesInvoiceItems(inv.id!);
      final allItems = context.read<InventoryProvider>().items;
      setState(() {
        _resetInvoice();
        _invoiceNoCtrl.text = inv.invoiceNo;
        _dateCtrl.text      = inv.date;
        _saleType           = inv.paymentType;
        _invoiceStatus      = inv.status;
        _amountPaid         = inv.amountPaid;
        _amountPaidCtrl.text= inv.amountPaid.toStringAsFixed(2);
        _notesCtrl.text     = inv.notes ?? '';
        _editingInvoiceId   = inv.id;
        for (final si in items) {
          final matched = allItems.where((i) => i.id == si.itemId).toList();
          _cart.add(_CartItem(
            itemId   : si.itemId,
            name     : si.itemName,
            stockQty : matched.isNotEmpty ? matched.first.quantity : 0,
            qty      : si.qty,
            unitPrice: si.unitPrice,
            discountPct: si.discount > 0 && si.unitPrice > 0 ? (si.discount / si.unitPrice) * 100 : 0,
          ));
        }
      });
      _snack('تم تحميل الفاتورة ${inv.invoiceNo}', Colors.green);
    } catch (e) {
      _snack('خطأ في تحميل الفاتورة: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── print ────────────────────────────────────────────────────────────────────
  void _printInvoice() {
    if (_cart.isEmpty) { _snack('السلة فارغة', Colors.orange); return; }
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Center(
                child: Column(children: [
                  Icon(Icons.store, size: 36, color: _kPrimary),
                  SizedBox(height: 4),
                  Text('فاتورة مبيعات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _kPrimary)),
                ]),
              ),
              const Divider(height: 24),
              _printRow('رقم الفاتورة', _invoiceNoCtrl.text),
              _printRow('التاريخ', _dateCtrl.text),
              _printRow('المخزن', _warehouseCtrl.text),
              if (_customer != null) _printRow('العميل', _customer!.name),
              const Divider(height: 20),
              const Text('الأصناف', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._cart.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(child: Text('${e.key + 1}. ${e.value.name}', style: const TextStyle(fontSize: 12))),
                  Text('${e.value.qty.toStringAsFixed(e.value.qty == e.value.qty.roundToDouble() ? 0 : 1)} × ${AppFormatters.formatCurrency(e.value.unitPrice)}',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Text(AppFormatters.formatCurrency(e.value.lineTotal),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kPrimary)),
                ]),
              )),
              const Divider(height: 20),
              _printRow('الإجمالي', AppFormatters.formatCurrency(_subtotal)),
              if (_itemDisc + _custDiscAmt > 0) _printRow('الخصومات', '- ${AppFormatters.formatCurrency(_itemDisc + _custDiscAmt)}', color: Colors.red),
              if (_taxAmt > 0) _printRow('الضريبة', AppFormatters.formatCurrency(_taxAmt)),
              _printRow('الصافي', AppFormatters.formatCurrency(_total), color: _kPrimary, bold: true),
              const SizedBox(height: 4),
              _printRow('المدفوع', AppFormatters.formatCurrency(_amountPaid), color: _kGreen, bold: true),
              _printRow('المتبقي', AppFormatters.formatCurrency(_remaining),
                  color: _remaining > 0 ? _kRed : _kGreen, bold: true),
              const Divider(height: 20),
              Center(child: Text(_notesCtrl.text.isNotEmpty ? _notesCtrl.text : 'شكراً لتعاملكم معنا',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('إغلاق'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _printRow(String label, String value, {Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color ?? Colors.black87)),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 820;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(),
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('نقطة البيع — POS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Text('فاتورة: ${_invoiceNoCtrl.text}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ]),
      actions: _saving
          ? [const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))]
          : [
              _appBarBtn(Icons.payments_outlined, 'دفع الكل', _cart.isNotEmpty ? _payAll : null, Colors.white),
              _appBarBtn(Icons.pause_circle_outline, 'تعليق', _cart.isNotEmpty ? _suspendInvoice : null, Colors.orange.shade200),
              _appBarBtn(Icons.restore_page_outlined, 'استرجاع', _restoreInvoice, Colors.lightBlue.shade200),
              _appBarBtn(Icons.print_outlined, 'طباعة', _cart.isNotEmpty ? _printInvoice : null, Colors.white),
              _appBarBtn(Icons.save_rounded, 'حفظ', _cart.isNotEmpty ? () => _saveInvoice() : null, Colors.lightGreen.shade200),
              _appBarBtn(Icons.refresh, 'جديد', _resetInvoice, Colors.white),
              const SizedBox(width: 4),
            ],
    );
  }

  Widget _appBarBtn(IconData icon, String tooltip, VoidCallback? onTap, Color color) =>
      IconButton(
        icon: Icon(icon, color: onTap == null ? Colors.white38 : color),
        tooltip: tooltip,
        onPressed: onTap,
      );

  // ── Wide (≥820) ─────────────────────────────────────────────────────────────
  Widget _wideLayout() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Left sidebar: invoice info + customer + totals + payment + save
      SizedBox(
        width: 310,
        child: Container(
          color: Colors.white,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _invoiceCard(),
              const SizedBox(height: 10),
              _customerCard(),
              const SizedBox(height: 10),
              _totalsCard(),
              const SizedBox(height: 10),
              _paymentCard(),
              const SizedBox(height: 10),
              _saveAndNewButtons(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      const VerticalDivider(width: 1, thickness: 1),
      // Right panel: item browser + cart
      Expanded(
        child: Column(children: [
          _itemBrowserHeader(),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Item browser
              Expanded(flex: 5, child: _itemBrowser()),
              const VerticalDivider(width: 1),
              // Cart
              Expanded(flex: 4, child: _cartPanel()),
            ]),
          ),
        ]),
      ),
    ]);
  }

  // ── Narrow (<820) ───────────────────────────────────────────────────────────
  Widget _narrowLayout() {
    return Column(children: [
      Expanded(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                _invoiceCard(),
                const SizedBox(height: 10),
                _customerCard(),
                const SizedBox(height: 10),
              ]),
            )),
            SliverToBoxAdapter(child: _itemBrowserHeader()),
            SliverToBoxAdapter(child: SizedBox(height: 280, child: _itemBrowser())),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: _cartHeader(),
            )),
            _cart.isEmpty
                ? SliverToBoxAdapter(child: _emptyCart())
                : SliverList(delegate: SliverChildBuilderDelegate(
                    (_, i) => _CartRowWidget(
                      index: i, item: _cart[i],
                      onEdit: () => _editCartItem(i),
                      onDelete: () => setState(() => _cart.removeAt(i)),
                      onPlus: () => _changeQty(i, 1),
                      onMinus: () => _changeQty(i, -1),
                    ),
                    childCount: _cart.length,
                  )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                _totalsCard(), const SizedBox(height: 10),
                _paymentCard(), const SizedBox(height: 80),
              ]),
            )),
          ],
        ),
      ),
      _narrowBottomBar(),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  CARDS
  // ══════════════════════════════════════════════════════════════════════════════

  // ── invoice card ─────────────────────────────────────────────────────────────
  Widget _invoiceCard() {
    return _PosCard(
      title: 'بيانات الفاتورة',
      icon: Icons.receipt_long,
      color: _kPrimary,
      child: Column(children: [
        // Invoice No (editable)
        TextField(
          controller: _invoiceNoCtrl,
          decoration: const InputDecoration(
            labelText: 'رقم الفاتورة',
            prefixIcon: Icon(Icons.tag, size: 18),
            border: OutlineInputBorder(), isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        // Date (tap to pick)
        TextField(
          controller: _dateCtrl,
          readOnly: true,
          onTap: _pickDate,
          decoration: const InputDecoration(
            labelText: 'تاريخ الفاتورة',
            prefixIcon: Icon(Icons.calendar_today, size: 18),
            suffixIcon: Icon(Icons.edit_calendar_outlined, size: 18),
            border: OutlineInputBorder(), isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        // Warehouse (editable)
        TextField(
          controller: _warehouseCtrl,
          decoration: const InputDecoration(
            labelText: 'المخزن',
            prefixIcon: Icon(Icons.warehouse_outlined, size: 18),
            border: OutlineInputBorder(), isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        _row2(
          _ddField('نوع البيع', _saleType, {'cash': 'نقدي', 'installment': 'تقسيط'},
              (v) => setState(() => _saleType = v!)),
          _ddField('طريقة الدفع', _paymentMethod, {'cash': 'كاش', 'visa': 'فيزا', 'transfer': 'تحويل'},
              (v) => setState(() => _paymentMethod = v!)),
        ),
        const SizedBox(height: 8),
        _ddField('حالة الفاتورة', _invoiceStatus, {'new': 'جديدة', 'paid': 'مدفوعة', 'pending': 'معلقة'},
            (v) => setState(() => _invoiceStatus = v!)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'ملاحظات',
            prefixIcon: Icon(Icons.note_outlined, size: 18),
            border: OutlineInputBorder(), isDense: true,
          ),
        ),
      ]),
    );
  }

  // ── customer card ────────────────────────────────────────────────────────────
  Widget _customerCard() {
    return _PosCard(
      title: 'بيانات العميل',
      icon: Icons.person_outlined,
      color: Colors.teal,
      child: Column(children: [
        InkWell(
          onTap: _pickCustomer,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _customer != null ? Colors.teal.shade50 : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _customer != null ? Colors.teal.shade300 : Colors.grey.shade300),
            ),
            child: Row(children: [
              Icon(_customer != null ? Icons.person : Icons.person_search,
                  color: _customer != null ? Colors.teal : Colors.grey, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: _customer == null
                    ? const Text('انقر لاختيار عميل...', style: TextStyle(color: Colors.grey, fontSize: 13))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_customer!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (_customer!.phone != null)
                          Text(_customer!.phone!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
              ),
              if (_customer != null)
                GestureDetector(
                  onTap: () => setState(() { _customer = null; _previousBalance = 0; }),
                  child: const Icon(Icons.close, size: 18, color: Colors.grey),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ]),
          ),
        ),
        if (_customer != null) ...[
          const SizedBox(height: 10),
          _row2(
            _infoChip('الرصيد السابق', AppFormatters.formatCurrency(_previousBalance),
                _previousBalance > 0 ? Colors.red : Colors.green, Icons.account_balance),
            TextField(
              controller: _custDiscCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'خصم العميل %',
                prefixIcon: Icon(Icons.discount_outlined, size: 18),
                border: OutlineInputBorder(), isDense: true, suffixText: '%',
              ),
              onChanged: (v) => setState(() => _customerDiscount = double.tryParse(v) ?? 0),
            ),
          ),
        ],
      ]),
    );
  }

  // ── totals card ──────────────────────────────────────────────────────────────
  Widget _totalsCard() {
    return _PosCard(
      title: 'تفاصيل المبلغ',
      icon: Icons.calculate_outlined,
      color: Colors.indigo,
      child: Column(children: [
        _totRow('إجمالي الأصناف', AppFormatters.formatCurrency(_subtotal), Colors.black87),
        if (_itemDisc > 0) _totRow('خصم الأصناف', '- ${AppFormatters.formatCurrency(_itemDisc)}', Colors.red),
        if (_custDiscAmt > 0)
          _totRow('خصم العميل (${_customerDiscount.toStringAsFixed(0)}%)',
              '- ${AppFormatters.formatCurrency(_custDiscAmt)}', Colors.orange),
        const Divider(height: 12),
        _totRow('الصافي قبل الضريبة', AppFormatters.formatCurrency(_netBefore), Colors.black87),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('ضريبة %', style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _taxCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
              onChanged: (v) => setState(() => _taxRate = double.tryParse(v) ?? 0),
            ),
          ),
          const SizedBox(width: 8),
          Text(AppFormatters.formatCurrency(_taxAmt), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('مصاريف إضافية', style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _expCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
              onChanged: (v) => setState(() => _expenses = double.tryParse(v) ?? 0),
            ),
          ),
        ]),
        const Divider(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: _kPrimary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.payments_outlined, color: _kPrimary, size: 18),
            const SizedBox(width: 8),
            const Text('الإجمالي الكلي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kPrimary)),
            const Spacer(),
            Text(AppFormatters.formatCurrency(_total),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _kPrimary)),
          ]),
        ),
      ]),
    );
  }

  // ── payment card ─────────────────────────────────────────────────────────────
  Widget _paymentCard() {
    return _PosCard(
      title: 'الدفع والمتبقي',
      icon: Icons.account_balance_wallet_outlined,
      color: _kGreen,
      child: Column(children: [
        if (_previousBalance > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              Text('رصيد سابق: ${AppFormatters.formatCurrency(_previousBalance)}',
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _amountPaidCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGreen),
              decoration: InputDecoration(
                labelText: 'المبلغ المدفوع',
                prefixIcon: const Icon(Icons.payments, color: _kGreen, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true, suffixText: 'ج.م',
                fillColor: Colors.green.shade50, filled: true,
              ),
              onChanged: (v) => setState(() => _amountPaid = double.tryParse(v) ?? 0),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            onPressed: _payAll,
            child: const Text('دفع الكل', style: TextStyle(fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _remaining > 0 ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _remaining > 0 ? Colors.red.shade200 : Colors.green.shade200),
          ),
          child: Row(children: [
            Icon(_remaining > 0 ? Icons.money_off : Icons.check_circle_outline,
                color: _remaining > 0 ? Colors.red : Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(_remaining > 0 ? 'المتبقي' : 'تم السداد الكامل ✓',
                style: TextStyle(color: _remaining > 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Text(AppFormatters.formatCurrency(_remaining.abs()),
                style: TextStyle(color: _remaining > 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),
      ]),
    );
  }

  // ── save + new buttons ───────────────────────────────────────────────────────
  Widget _saveAndNewButtons() {
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _cart.isEmpty ? Colors.grey.shade300 : _kGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: _saving || _cart.isEmpty ? null : () => _saveInvoice(),
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الفاتورة',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
            side: BorderSide(color: Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _resetInvoice,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('فاتورة جديدة'),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  ITEM BROWSER
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _itemBrowserHeader() {
    return Consumer<InventoryProvider>(
      builder: (_, inv, __) {
        final cats = _categories(inv.items);
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Search only
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'ابحث عن صنف...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: const Color(0xFFF8F8F8), isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }))
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            // Category chips
            if (cats.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _catChip('الكل', null),
                    ...cats.map((c) => _catChip(c, c)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  Widget _catChip(String label, String? value) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _selectedCategory == value,
      onSelected: (_) => setState(() => _selectedCategory = value),
      selectedColor: _kPrimary.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: _selectedCategory == value ? _kPrimary : Colors.black87),
    ),
  );

  Widget _itemBrowser() {
    return Consumer<InventoryProvider>(
      builder: (_, inv, __) {
        final items = _filteredItems(inv.items);
        if (inv.loading) return const Center(child: CircularProgressIndicator());
        if (items.isEmpty) return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('لا توجد أصناف', style: TextStyle(color: Colors.grey.shade400)),
          ]),
        );
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            final price = item.effectiveCashPrice > 0 ? item.effectiveCashPrice : item.priceRetail;
            final inCart = _cart.where((c) => c.itemId == item.id).fold(0.0, (s, c) => s + c.qty);
            return InkWell(
              onTap: () => _addToCart(item),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: inCart > 0 ? _kPrimary.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: inCart > 0 ? _kPrimary.withValues(alpha: 0.3) : Colors.grey.shade200),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: _kPrimary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      Text(
                        'مخزون: ${item.quantity.toStringAsFixed(0)} ${item.unit ?? ''}',
                        style: TextStyle(fontSize: 11, color: item.quantity > 0 ? Colors.grey : Colors.red),
                      ),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(AppFormatters.formatCurrency(price),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _kPrimary)),
                    if (inCart > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(10)),
                        child: Text('${inCart.toStringAsFixed(0)} في السلة',
                            style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                  ]),
                  const SizedBox(width: 6),
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  CART PANEL
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _cartPanel() {
    return Column(children: [
      _cartHeader(),
      Expanded(
        child: _cart.isEmpty
            ? _emptyCart()
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: _cart.length,
                itemBuilder: (_, i) => _CartRowWidget(
                  index: i, item: _cart[i],
                  onEdit: () => _editCartItem(i),
                  onDelete: () => setState(() => _cart.removeAt(i)),
                  onPlus: () => _changeQty(i, 1),
                  onMinus: () => _changeQty(i, -1),
                ),
              ),
      ),
      // Cart summary strip
      if (_cart.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Row(children: [
            Text('${_cart.length} صنف  •  ${_cart.fold(0.0,(s,i)=>s+i.qty).toStringAsFixed(0)} قطعة',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const Spacer(),
            Text('الصافي: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            Text(AppFormatters.formatCurrency(_total),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kPrimary)),
          ]),
        ),
    ]);
  }

  Widget _cartHeader() {
    return Container(
      color: _kPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(children: [
        const SizedBox(width: 22),
        const Expanded(flex: 4, child: _TH(text: 'الصنف')),
        const Expanded(flex: 3, child: _TH(text: 'الكمية')),
        const Expanded(flex: 2, child: _TH(text: 'السعر')),
        const Expanded(flex: 2, child: _TH(text: 'الإجمالي')),
        const SizedBox(width: 54),
      ]),
    );
  }

  Widget _emptyCart() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text('السلة فارغة', style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
        const SizedBox(height: 4),
        Text('اضغط على أي صنف لإضافته', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      ]),
    ),
  );

  // ── narrow bottom bar ────────────────────────────────────────────────────────
  Widget _narrowBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الإجمالي', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          Text(AppFormatters.formatCurrency(_total),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _kPrimary)),
          if (_remaining > 0)
            Text('متبقي: ${AppFormatters.formatCurrency(_remaining)}',
                style: const TextStyle(color: Colors.red, fontSize: 11)),
        ])),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _cart.isEmpty ? Colors.grey : _kGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _saving || _cart.isEmpty ? null : () => _saveInvoice(),
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? '...' : 'حفظ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  SMALL HELPERS
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _row2(Widget a, Widget b) =>
      Row(children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)]);

  Widget _ddField(String label, String value, Map<String, String> opts, ValueChanged<String?> cb) =>
      DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(), isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        items: opts.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12))))
            .toList(),
        onChanged: cb,
      );

  Widget _infoChip(String label, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 16), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ])),
    ]),
  );

  Row _totRow(String label, String value, Color color) => Row(children: [
    Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CART ROW WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _CartRowWidget extends StatelessWidget {
  final int index;
  final _CartItem item;
  final VoidCallback onEdit, onDelete, onPlus, onMinus;
  const _CartRowWidget({required this.index, required this.item, required this.onEdit,
      required this.onDelete, required this.onPlus, required this.onMinus});

  @override
  Widget build(BuildContext context) {
    final isLow = item.qty > item.stockQty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isLow ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isLow ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      child: Row(children: [
        SizedBox(width: 22, child: Text('${index + 1}', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey))),
        const SizedBox(width: 4),
        Expanded(
          flex: 4,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            Text(AppFormatters.formatCurrency(item.unitPrice),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ),
        // Qty controls
        Expanded(
          flex: 3,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _qBtn(Icons.remove, onMinus, Colors.red.shade300),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                item.qty == item.qty.roundToDouble() ? item.qty.toStringAsFixed(0) : item.qty.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            _qBtn(Icons.add, onPlus, Colors.green.shade500),
          ]),
        ),
        // Line total
        Expanded(
          flex: 2,
          child: Text(AppFormatters.formatCurrency(item.lineTotal),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kPrimary)),
        ),
        // Discount badge
        if (item.discountPct > 0)
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200)),
            child: Text('${item.discountPct.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        // Actions
        Row(mainAxisSize: MainAxisSize.min, children: [
          _iBtn(Icons.edit_outlined, onEdit, Colors.blue),
          _iBtn(Icons.delete_outline, onDelete, Colors.red),
        ]),
      ]),
    );
  }

  Widget _qBtn(IconData icon, VoidCallback onTap, Color color) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      width: 22, height: 22,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Icon(icon, size: 14, color: color),
    ),
  );

  Widget _iBtn(IconData icon, VoidCallback onTap, Color color) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 16, color: color)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CART ITEM MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class _CartItem {
  final int itemId;
  final String name;
  final double stockQty;
  final double qty;
  final double unitPrice;
  final double discountPct;

  const _CartItem({
    required this.itemId,
    required this.name,
    required this.stockQty,
    required this.qty,
    required this.unitPrice,
    required this.discountPct,
  });

  double get netPrice  => unitPrice * (1 - discountPct / 100);
  double get lineTotal => qty * netPrice;

  _CartItem copyWith({double? qty, double? unitPrice, double? discountPct}) => _CartItem(
    itemId: itemId, name: name, stockQty: stockQty,
    qty: qty ?? this.qty,
    unitPrice: unitPrice ?? this.unitPrice,
    discountPct: discountPct ?? this.discountPct,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  POS CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _PosCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  const _PosCard({required this.title, required this.icon, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(12), child: child),
      ]),
    );
  }
}

// ─── Table Header Cell ─────────────────────────────────────────────────────────
class _TH extends StatelessWidget {
  final String text;
  const _TH({required this.text});
  @override
  Widget build(BuildContext context) => Text(text, textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold));
}
