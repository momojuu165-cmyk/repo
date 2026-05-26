import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../database/daos/invoice_dao.dart';
import '../../../database/daos/partner_group_dao.dart';
import '../../../database/daos/supplier_dao.dart';
import '../../../database/daos/department_dao.dart';
import '../../../database/daos/installment_product_dao.dart';
import '../../../models/purchase_invoice.dart';
import '../../../models/partner_group.dart';
import '../../../models/supplier.dart';
import '../../../models/item.dart';
import '../../../models/installment_product.dart';
import '../../../models/department.dart';
import '../../../models/warehouse.dart';
import '../../../providers/inventory_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class _LineItem {
  Item item;
  double qty;
  double unitCost;
  double discount;

  _LineItem({required this.item, this.qty = 1, required this.unitCost, this.discount = 0});

  double get total => (unitCost * qty) - discount;
}

// ─── Purchase Invoice Screen ──────────────────────────────────────────────────

class PurchaseInvoiceScreen extends StatefulWidget {
  final Supplier? supplier;
  const PurchaseInvoiceScreen({super.key, this.supplier});

  @override
  State<PurchaseInvoiceScreen> createState() => _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends State<PurchaseInvoiceScreen> {
  final _dao = InvoiceDao();
  final _groupDao = PartnerGroupDao();
  final _supplierDao = SupplierDao();

  // Form fields
  final _searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  List<_LineItem> _items = [];
  List<dynamic> _searchResults = [];
  bool _saving = false;

  // Supplier selection
  Supplier? _selectedSupplier;
  List<Supplier> _suppliers = [];
  bool _loadingSuppliers = true;

  // Section — loaded from DB departments
  String? _selectedSection;
  List<Department> _departments = [];

  // Partner group
  List<PartnerGroup> _partnerGroups = [];
  PartnerGroup? _selectedGroup;

  // Date
  String _date = DateTime.now().toIso8601String().substring(0, 10);

  // Warehouse
  int? _warehouseId;

  @override
  void initState() {
    super.initState();
    _selectedSupplier = widget.supplier;
    _selectedSection = widget.supplier?.section;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadAll();
      _loadSuppliers();
      _loadPartnerGroups();
      _loadDepartments();
    });
  }

  Future<void> _loadSuppliers() async {
    try {
      final all = await _supplierDao.getAll();
      if (mounted) setState(() { _suppliers = all; _loadingSuppliers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSuppliers = false);
    }
  }

  Future<void> _loadPartnerGroups() async {
    try {
      final g = await _groupDao.getAllGroups();
      if (mounted) setState(() => _partnerGroups = g);
    } catch (_) {}
  }

  Future<void> _loadDepartments() async {
    try {
      final deps = await DepartmentDao().getAll(activeOnly: true);
      if (mounted) setState(() => _departments = deps);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (s, i) => s + i.total);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _total => _subtotal - _discount;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _date = picked.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _showCreateProductDialog(InventoryProvider inv) async {
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final purchaseCtrl = TextEditingController(text: '0');
    final saleCtrl = TextEditingController(text: '0');
    final qtyCtrl = TextEditingController(text: '1');
    int? warehouseId = _warehouseId;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة منتج جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم المنتج', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: barcodeCtrl,
                decoration: const InputDecoration(labelText: 'الباركود (اختياري)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: purchaseCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سعر الشراء', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: saleCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سعر البيع', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              if (inv.warehouses.isNotEmpty)
                DropdownButtonFormField<int?>(
                  value: warehouseId,
                  decoration: const InputDecoration(
                    labelText: 'المخزن',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('— بدون مخزن —')),
                    ...inv.warehouses.map((w) => DropdownMenuItem<int?>(value: w.id, child: Text(w.name))),
                  ],
                  onChanged: (v) => warehouseId = v,
                ),
              if (inv.warehouses.isEmpty) ...[
                const SizedBox(height: 10),
                const Text('لا يوجد مخازن بعد. يمكنك إضافته من هنا.'),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.add_business),
                  label: const Text('إضافة مخزن جديد'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _showAddWarehouseDialog(inv);
                    if (mounted) setState(() {});
                    await _showCreateProductDialog(inv);
                  },
                ),
              ),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final purchasePrice = double.tryParse(purchaseCtrl.text.trim()) ?? 0;
              final salePrice = double.tryParse(saleCtrl.text.trim()) ?? 0;
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء إدخال اسم المنتج'), backgroundColor: Colors.red),
                );
                return;
              }
              final item = Item(
                name: name,
                barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                purchasePrice: purchasePrice,
                priceRetail: salePrice,
                priceWholesale: salePrice,
                priceSpecial: salePrice,
                cashPrice: salePrice,
                warehouseId: warehouseId,
                quantity: qty,
                createdAt: DateTime.now().toIso8601String(),
              );
              final createdId = await inv.addItem(item);
              if (createdId <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('حدث خطأ أثناء إضافة المنتج'), backgroundColor: Colors.red),
                );
                return;
              }
              final savedItem = item.copyWith(id: createdId);
              if (mounted) {
                setState(() {
                  _items.add(_LineItem(item: savedItem, unitCost: purchasePrice, qty: qty));
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ المنتج'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddWarehouseDialog(InventoryProvider provider) async {
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مخزن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المخزن *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(labelText: 'الموقع'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await provider.addWarehouse(Warehouse(
                name: nameCtrl.text.trim(),
                location: locCtrl.text.trim().isEmpty ? null : locCtrl.text.trim(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف منتجاً على الأقل'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final invoiceNo = 'PUR-${DateTime.now().millisecondsSinceEpoch}';

      final id = await _dao.insertPurchaseInvoice(PurchaseInvoice(
        invoiceNo: invoiceNo,
        supplierId: _selectedSupplier?.id,
        warehouseId: _warehouseId,
        date: _date,
        total: _total,
        discount: _discount,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: now,
      ));

      final inv = context.read<InventoryProvider>();
      for (final item in _items) {
        await _dao.insertPurchaseInvoiceItem(PurchaseInvoiceItem(
          invoiceId: id,
          itemId: item.item.id,
          itemName: item.item.name,
          barcode: item.item.barcode,
          qty: item.qty,
          unitCost: item.unitCost,
          discount: item.discount,
          total: item.total,
        ));
        // Only adjust warehouse quantity for items with a real warehouse ID
        if (item.item.id != null) {
          await inv.adjustQuantity(item.item.id!, item.qty);
        }
      }

      // Deduct from partner group if selected
      if (_selectedGroup?.id != null && _total > 0) {
        try {
          final itemNames = _items.map((i) => i.item.name).join('، ');
          await _groupDao.deductProductCostFromCapital(
            groupId: _selectedGroup!.id!,
            cost: _total,
            productName: 'مشتريات: $itemNames',
            date: _date,
          );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ فاتورة المشتريات $invoiceNo ✓'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة مشتريات'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Invoice header card ──────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('معلومات الفاتورة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),

                // Date row
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text(_date, style: const TextStyle(fontSize: 14)),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),

                // Supplier selector (optional)
                _loadingSuppliers
                    ? const Center(child: SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                    : DropdownButtonFormField<Supplier?>(
                        value: _selectedSupplier,
                        decoration: const InputDecoration(
                          labelText: 'المورد (اختياري)',
                          prefixIcon: Icon(Icons.store),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<Supplier?>(
                              value: null, child: Text('— بدون مورد —')),
                          ..._suppliers.map((s) => DropdownMenuItem<Supplier?>(
                              value: s,
                              child: Text(
                                s.section != null ? '${s.name} (${s.section})' : s.name,
                                overflow: TextOverflow.ellipsis,
                              ))),
                        ],
                        onChanged: (s) => setState(() {
                          _selectedSupplier = s;
                          if (s?.section != null && _selectedSection == null) {
                            _selectedSection = s!.section;
                          }
                        }),
                      ),
                const SizedBox(height: 10),

                // Section — from admin-defined departments
                DropdownButtonFormField<String?>(
                  value: _selectedSection,
                  decoration: const InputDecoration(
                    labelText: 'القسم',
                    prefixIcon: Icon(Icons.category, color: Colors.indigo),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— غير محدد —')),
                    ..._departments.map((d) => DropdownMenuItem<String?>(value: d.name, child: Text(d.name))),
                  ],
                  onChanged: (v) => setState(() => _selectedSection = v),
                ),
                const SizedBox(height: 10),

                // Partner group deduction
                if (_partnerGroups.isNotEmpty)
                  DropdownButtonFormField<PartnerGroup?>(
                    value: _selectedGroup,
                    decoration: InputDecoration(
                      labelText: 'خصم من مجموعة شركاء (اختياري)',
                      prefixIcon: const Icon(Icons.group, color: Colors.purple),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      helperText: _selectedGroup != null
                          ? 'سيُخصم ${_total.toStringAsFixed(0)} ج.م من رصيد "${_selectedGroup!.name}"'
                          : null,
                    ),
                    items: [
                      const DropdownMenuItem<PartnerGroup?>(
                          value: null, child: Text('بدون خصم من مجموعة')),
                      ..._partnerGroups.map((g) => DropdownMenuItem<PartnerGroup?>(
                          value: g, child: Text(g.name))),
                    ],
                    onChanged: (g) => setState(() => _selectedGroup = g),
                  ),

                // Warehouse
                if (inv.warehouses.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    value: _warehouseId,
                    decoration: const InputDecoration(
                      labelText: 'المخزن (اختياري)',
                      prefixIcon: Icon(Icons.warehouse),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('— بدون مخزن —')),
                      ...inv.warehouses.map((w) =>
                          DropdownMenuItem<int?>(value: w.id, child: Text(w.name))),
                    ],
                    onChanged: (v) => setState(() => _warehouseId = v),
                  ),
                ],
              ]),
            ),
          ),

          const SizedBox(height: 10),

          // ── Items card ───────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('الأصناف',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (_items.isNotEmpty)
                    Text('${_items.length} صنف',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
                const SizedBox(height: 10),

                // Search field
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن صنف وأضفه...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                  onChanged: (q) async {
                    if (q.trim().isEmpty) {
                      if (mounted) setState(() => _searchResults = []);
                      return;
                    }
                    final warehouseResults = await inv.search(q);
                    final sectionResults = await InstallmentProductDao().search(q);
                    if (mounted) setState(() => _searchResults = [...warehouseResults, ...sectionResults]);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('منتج غير موجود'),
                      onPressed: () => _showCreateProductDialog(inv),
                    ),
                  ],
                ),

                // Search results
                if (_searchResults.isNotEmpty)
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: const EdgeInsets.only(top: 6),
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (ctx, i) {
                        final item = _searchResults[i];
                        final name = item is Item ? item.name : (item as InstallmentProduct).name;
                        final cost = item is Item ? item.purchasePrice : (item as InstallmentProduct).purchasePrice;
                        // Wrap InstallmentProduct as a fake Item for _LineItem compatibility
                        final fakeItem = item is Item ? item : Item(
                          name: (item as InstallmentProduct).name,
                          purchasePrice: (item as InstallmentProduct).purchasePrice,
                          priceRetail: (item as InstallmentProduct).salePrice,
                          category: (item as InstallmentProduct).category,
                          createdAt: DateTime.now().toIso8601String(),
                        );
                        return ListTile(
                          dense: true,
                          title: Text(name, style: const TextStyle(fontSize: 13)),
                          subtitle: cost > 0
                              ? Text('${cost.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(fontSize: 11))
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.green),
                            onPressed: () {
                              setState(() {
                                _items.add(_LineItem(item: fakeItem, unitCost: cost));
                                _searchResults = [];
                                _searchCtrl.clear();
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),

                // Items list
                if (_items.isNotEmpty) ...[
                  const Divider(height: 20),
                  // Header
                  const Row(children: [
                    Expanded(flex: 3, child: Text('الصنف', style: TextStyle(fontSize: 11, color: Colors.grey))),
                    SizedBox(width: 4),
                    SizedBox(width: 56, child: Text('كمية', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey))),
                    SizedBox(width: 4),
                    SizedBox(width: 72, child: Text('تكلفة', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey))),
                    SizedBox(width: 4),
                    SizedBox(width: 70, child: Text('الإجمالي', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey))),
                    SizedBox(width: 32),
                  ]),
                  const SizedBox(height: 6),
                  ...List.generate(_items.length, (i) {
                    final item = _items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(item.item.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 56,
                          child: TextFormField(
                            initialValue: item.qty.toStringAsFixed(item.qty == item.qty.floorToDouble() ? 0 : 1),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onChanged: (v) => setState(() => item.qty = double.tryParse(v) ?? 1),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 72,
                          child: TextFormField(
                            initialValue: item.unitCost.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onChanged: (v) => setState(() => item.unitCost = double.tryParse(v) ?? 0),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 70,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              AppFormatters.formatCurrency(item.total),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => setState(() => _items.removeAt(i)),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ]),
                    );
                  }),
                ],

                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('لا توجد أصناف بعد — ابحث وأضف',
                        style: TextStyle(color: Colors.grey, fontSize: 13))),
                  ),
              ]),
            ),
          ),

          const SizedBox(height: 10),

          // ── Totals card ──────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _TotalRow('المجموع الفرعي', AppFormatters.formatCurrency(_subtotal)),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('خصم إجمالي:',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: 'ج.م',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
                const Divider(height: 20),
                _TotalRow('الإجمالي', AppFormatters.formatCurrency(_total),
                    bold: true, color: const Color(AppColors.primaryInt)),
              ]),
            ),
          ),

          const SizedBox(height: 10),

          // ── Notes ────────────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Save button ──────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(
                _saving ? 'جاري الحفظ...' : 'حفظ فاتورة المشتريات',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _TotalRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 15 : 14,
                  color: bold ? Colors.black87 : Colors.grey,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 17 : 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? (bold ? Colors.black87 : Colors.grey))),
        ],
      );
}
