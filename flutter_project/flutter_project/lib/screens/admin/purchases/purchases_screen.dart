import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../database/daos/invoice_dao.dart';
import '../../../database/daos/partner_group_dao.dart';
import '../../../models/purchase_invoice.dart';
import '../../../models/partner_group.dart';
import '../../../models/item.dart';
import '../../../providers/inventory_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/pdf_helper.dart';
import 'purchase_invoice_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _dao = InvoiceDao();
  List<PurchaseInvoice> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    context.read<InventoryProvider>().loadAll();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final invs = await _dao.getPurchaseInvoices();
    if (mounted)
      setState(() {
        _invoices = invs;
        _loading = false;
      });
  }

  /// Print an individual supplier invoice as a PDF
  Future<void> _printInvoice(PurchaseInvoice inv) async {
    try {
      final items = await _dao.getPurchaseInvoiceItems(inv.id!);
      await PdfHelper.printReport(
        context: context,
        title: 'فاتورة مشتريات رقم: ${inv.invoiceNo}',
        subtitle: 'التاريخ: ${AppFormatters.formatDateFromString(inv.date)}',
        headers: [
          ['المنتج', 'الكمية', 'سعر الوحدة', 'الخصم', 'الإجمالي'],
        ],
        rows: items
            .map((it) => [
                  it.itemName,
                  it.qty.toStringAsFixed(2),
                  AppFormatters.formatCurrency(it.unitCost),
                  it.discount > 0
                      ? AppFormatters.formatCurrency(it.discount)
                      : '-',
                  AppFormatters.formatCurrency(it.total),
                ])
            .toList(),
        summaryRows: [
          if (inv.discount > 0)
            {
              'label': 'الخصم الإجمالي',
              'value': AppFormatters.formatCurrency(inv.discount)
            },
          {
            'label': 'الإجمالي الكلي',
            'value': AppFormatters.formatCurrency(inv.total)
          },
        ],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر الطباعة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المشتريات'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(child: Text('لا توجد فواتير مشتريات'))
              : ListView.builder(
                  itemCount: _invoices.length,
                  itemBuilder: (ctx, i) {
                    final inv = _invoices[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(AppColors.primaryInt)
                              .withValues(alpha: 0.1),
                          child: const Icon(Icons.shopping_cart,
                              color: Color(AppColors.primaryInt), size: 20),
                        ),
                        title: Text(inv.invoiceNo,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            AppFormatters.formatDateFromString(inv.date)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppFormatters.formatCurrency(inv.total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(width: 8),
                            // ── Print button ──────────────────────────────
                            IconButton(
                              icon: const Icon(Icons.print,
                                  color: Color(AppColors.primaryInt)),
                              tooltip: 'طباعة الفاتورة',
                              onPressed: () => _printInvoice(inv),
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
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PurchaseInvoiceScreen()),
        ).then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('فاتورة جديدة'),
      ),
    );
  }
}

class _PurchaseLineItem {
  Item item;
  double qty;
  double unitCost;
  double discount;

  _PurchaseLineItem({
    required this.item,
    this.qty = 1,
    required this.unitCost,
    this.discount = 0,
  });

  double get total => (unitCost * qty) - discount;
}

class _NewPurchaseSheet extends StatefulWidget {
  final InvoiceDao dao;
  final VoidCallback onSaved;

  const _NewPurchaseSheet({required this.dao, required this.onSaved});

  @override
  State<_NewPurchaseSheet> createState() => _NewPurchaseSheetState();
}

class _NewPurchaseSheetState extends State<_NewPurchaseSheet> {
  final _searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  List<_PurchaseLineItem> _items = [];
  List<Item> _searchResults = [];
  int? _warehouseId;
  bool _saving = false;

  // Partner group deduction
  final _groupDao = PartnerGroupDao();
  List<PartnerGroup> _partnerGroups = [];
  PartnerGroup? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _loadPartnerGroups();
  }

  Future<void> _loadPartnerGroups() async {
    try {
      final groups = await _groupDao.getAllGroups();
      if (mounted) setState(() => _partnerGroups = groups);
    } catch (_) {}
  }

  double get _total =>
      _items.fold<double>(0.0, (s, i) => s + i.total) -
      (double.tryParse(_discountCtrl.text) ?? 0);

  Future<void> _save() async {
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    final id = await widget.dao.insertPurchaseInvoice(PurchaseInvoice(
      invoiceNo: 'PUR-${DateTime.now().millisecondsSinceEpoch}',
      warehouseId: _warehouseId,
      date: now.substring(0, 10),
      total: _total,
      discount: double.tryParse(_discountCtrl.text) ?? 0,
      createdAt: now,
    ));
    final inv = context.read<InventoryProvider>();
    for (final item in _items) {
      await widget.dao.insertPurchaseInvoiceItem(PurchaseInvoiceItem(
        invoiceId: id,
        itemId: item.item.id!,
        itemName: item.item.name,
        barcode: item.item.barcode,
        qty: item.qty,
        unitCost: item.unitCost,
        discount: item.discount,
        total: item.total,
      ));
      await inv.adjustQuantity(item.item.id!, item.qty);
    }

    // ── خصم إجمالي الفاتورة من رصيد مجموعة الشركاء إذا حددها الأدمن ──────────
    if (_selectedGroup?.id != null && _total > 0) {
      try {
        final itemNames = _items.map((i) => i.item.name).join('، ');
        await _groupDao.deductProductCostFromCapital(
          groupId: _selectedGroup!.id!,
          cost: _total,
          productName: 'مشتريات: $itemNames',
          date: now.substring(0, 10),
        );
      } catch (_) {}
    }

    widget.onSaved();
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('فاتورة مشتريات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(
                labelText: 'المخزن', border: OutlineInputBorder()),
            items: inv.warehouses
                .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                .toList(),
            onChanged: (v) => setState(() => _warehouseId = v),
          ),
          const SizedBox(height: 8),
          // ── Partner group deduction ──────────────────────────────────────────
          if (_partnerGroups.isNotEmpty)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<PartnerGroup?>(
                value: _selectedGroup,
                decoration: InputDecoration(
                  labelText: 'خصم من مجموعة شركاء (اختياري)',
                  prefixIcon: const Icon(Icons.group, color: Colors.purple),
                  border: const OutlineInputBorder(),
                  helperText: _selectedGroup != null
                      ? 'سيُخصم ${_total.toStringAsFixed(0)} ج.م من رصيد "${_selectedGroup!.name}"'
                      : 'اختر المجموعة التي ستتحمل تكلفة هذه المشتريات',
                ),
                items: [
                  const DropdownMenuItem<PartnerGroup?>(
                      value: null, child: Text('بدون خصم من مجموعة')),
                  ..._partnerGroups.map((g) => DropdownMenuItem<PartnerGroup?>(
                      value: g, child: Text(g.name))),
                ],
                onChanged: (g) => setState(() => _selectedGroup = g),
              ),
              const SizedBox(height: 8),
            ]),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن منتج',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (q) async {
                    final r = await inv.search(q);
                    setState(() => _searchResults = r);
                  },
                ),
              ),
            ],
          ),
          if (_searchResults.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (ctx, i) {
                  final item = _searchResults[i];
                  return ListTile(
                    dense: true,
                    title: Text(item.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.add, color: Colors.green),
                      onPressed: () {
                        setState(() {
                          _items.add(_PurchaseLineItem(
                            item: item,
                            unitCost: item.purchasePrice,
                          ));
                          _searchResults = [];
                          _searchCtrl.clear();
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          if (_items.isNotEmpty) ...[
            const Divider(),
            SizedBox(
              height: 150,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final item = _items[i];
                  return Row(
                    children: [
                      Expanded(child: Text(item.item.name)),
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          initialValue: item.qty.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'كمية'),
                          onChanged: (v) => setState(
                              () => item.qty = double.tryParse(v) ?? 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: item.unitCost.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'تكلفة'),
                          onChanged: (v) => setState(
                              () => item.unitCost = double.tryParse(v) ?? 0),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 18),
                        onPressed: () => setState(() => _items.removeAt(i)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الإجمالي: ${AppFormatters.formatCurrency(_total)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white,
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
