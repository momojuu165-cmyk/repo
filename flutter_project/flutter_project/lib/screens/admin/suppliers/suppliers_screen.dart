import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import '../../../database/daos/supplier_dao.dart';
import '../../../database/daos/invoice_dao.dart';
import '../../../database/daos/department_dao.dart';
import '../../../models/supplier.dart';
import '../../../models/purchase_invoice.dart';
import '../../../models/department.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/pdf_helper.dart';
import 'supplier_comparison_screen.dart';
import '../purchases/purchase_invoice_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _dao = SupplierDao();
  List<Supplier> _suppliers = [];
  List<Department> _departments = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final deps = await DepartmentDao().getAll(activeOnly: true);
      if (mounted) setState(() => _departments = deps);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _dao.getAll();
    if (mounted)
      setState(() {
        _suppliers = all;
        _loading = false;
      });
  }

  List<Supplier> get _filtered {
    if (_search.isEmpty) return _suppliers;
    final q = _search.toLowerCase();
    return _suppliers
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            (s.phone?.contains(q) ?? false) ||
            (s.section?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموردون'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'مقارنة أسعار الموردين',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SupplierComparisonScreen()),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showSupplierForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('مورد جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن مورد أو قسم...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          if (!_loading && _suppliers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                _SummaryChip(
                  icon: Icons.people,
                  label: '${_suppliers.length} مورد',
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  icon: Icons.account_balance_wallet,
                  label:
                      'مديونية: ${AppFormatters.formatCurrency(_suppliers.fold(0.0, (s, x) => s + x.debt))}',
                  color: Colors.red,
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.store,
                              size: 72, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('لا يوجد موردون',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16)),
                        ]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) => _SupplierCard(
                          supplier: _filtered[i],
                          dao: _dao,
                          onEdit: () =>
                              _showSupplierForm(existing: _filtered[i]),
                          onDelete: () => _confirmDelete(_filtered[i]),
                          onRefresh: _load,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Supplier s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المورد'),
        content: Text('هل تريد حذف المورد "${s.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _dao.hardDelete(s.id!);
      _load();
    }
  }

  void _showSupplierForm({Supplier? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final balanceCtrl = TextEditingController(
        text: (existing?.balance ?? 0).toStringAsFixed(0));
    final debtCtrl =
        TextEditingController(text: (existing?.debt ?? 0).toStringAsFixed(0));
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String? selectedSection = existing?.section;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                    left: 20,
                    right: 20,
                    top: 20),
                child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  existing == null
                                      ? 'إضافة مورد جديد'
                                      : 'تعديل بيانات المورد',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              // Contacts import button
                              OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    final status =
                                        await Permission.contacts.request();
                                    if (!status.isGranted) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx)
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                              'يجب منح إذن الوصول لجهات الاتصال'),
                                          backgroundColor: Colors.orange,
                                        ));
                                      }
                                      return;
                                    }
                                    final contact = await FlutterContacts
                                        .openExternalPick();
                                    if (contact != null) {
                                      final full =
                                          await FlutterContacts.getContact(
                                              contact.id,
                                              withProperties: true);
                                      setS(() {
                                        nameCtrl.text = full?.displayName ??
                                            contact.displayName;
                                        final phone = full?.phones.isNotEmpty ==
                                                true
                                            ? full!.phones.first.number
                                            : contact.phones.isNotEmpty
                                                ? contact.phones.first.number
                                                : '';
                                        phoneCtrl.text = phone;
                                      });
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx)
                                          .showSnackBar(SnackBar(
                                        content:
                                            Text('تعذر فتح جهات الاتصال: $e'),
                                        backgroundColor: Colors.red,
                                      ));
                                    }
                                  }
                                },
                                icon: const Icon(Icons.contacts_rounded,
                                    size: 16),
                                label: const Text('استيراد',
                                    style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.teal),
                                  foregroundColor: Colors.teal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ]),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                              labelText: 'اسم المورد *',
                              prefixIcon: Icon(Icons.store)),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                  labelText: 'الهاتف',
                                  prefixIcon: Icon(Icons.phone)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: addressCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'العنوان',
                                  prefixIcon: Icon(Icons.location_on)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        // Section dropdown — admin-defined departments
                        DropdownButtonFormField<String?>(
                          value: selectedSection,
                          decoration: const InputDecoration(
                            labelText: 'القسم المورَّد إليه',
                            prefixIcon:
                                Icon(Icons.category, color: Colors.indigo),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('— غير محدد —')),
                            ..._departments.map((d) =>
                                DropdownMenuItem<String?>(
                                    value: d.name, child: Text(d.name))),
                          ],
                          onChanged: (v) => setS(() => selectedSection = v),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: balanceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'الرصيد (ما له علينا)',
                                prefixIcon: Icon(Icons.account_balance_wallet,
                                    color: Colors.green),
                                suffixText: 'ج.م',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: debtCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'المديونية (ما علينا له)',
                                prefixIcon:
                                    Icon(Icons.money_off, color: Colors.red),
                                suffixText: 'ج.م',
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'ملاحظات',
                              prefixIcon: Icon(Icons.note)),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(AppColors.primaryInt),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14)),
                            onPressed: () async {
                              if (nameCtrl.text.trim().isEmpty) return;
                              final now = DateTime.now().toIso8601String();
                              final supplier = Supplier(
                                id: existing?.id,
                                name: nameCtrl.text.trim(),
                                phone: phoneCtrl.text.trim().isEmpty
                                    ? null
                                    : phoneCtrl.text.trim(),
                                address: addressCtrl.text.trim().isEmpty
                                    ? null
                                    : addressCtrl.text.trim(),
                                section: selectedSection,
                                balance: double.tryParse(balanceCtrl.text) ?? 0,
                                debt: double.tryParse(debtCtrl.text) ?? 0,
                                notes: notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim(),
                                createdAt: existing?.createdAt ?? now,
                              );
                              try {
                                if (existing == null) {
                                  await _dao.insert(supplier);
                                } else {
                                  await _dao.update(supplier);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                _load();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(existing == null
                                          ? 'تم إضافة المورد ✓'
                                          : 'تم تحديث بيانات المورد ✓'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                        content: Text('حدث خطأ: $e'),
                                        backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            child: Text(existing == null
                                ? 'إضافة المورد'
                                : 'حفظ التعديلات'),
                          ),
                        ),
                      ]),
                ),
              )),
    );
  }
}

// ─── Supplier Card ────────────────────────────────────────────────────────────

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final SupplierDao dao;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  const _SupplierCard({
    required this.supplier,
    required this.dao,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  _SupplierDetailScreen(supplier: supplier, dao: dao)),
        ).then((_) => onRefresh()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              backgroundColor:
                  const Color(AppColors.primaryInt).withValues(alpha: 0.1),
              child:
                  const Icon(Icons.store, color: Color(AppColors.primaryInt)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(supplier.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  if (supplier.phone != null)
                    Row(children: [
                      const Icon(Icons.phone, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(supplier.phone!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
                  if (supplier.section != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(supplier.section!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.indigo,
                              fontWeight: FontWeight.w600)),
                    ),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (supplier.debt > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'مديونية: ${AppFormatters.formatCurrency(supplier.debt)}',
                    style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
                ),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _SupplierDetailScreen(
                            supplier: supplier, dao: dao)),
                  ),
                  child: const Icon(Icons.print_outlined,
                      size: 18, color: Colors.green),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_left, size: 18, color: Colors.grey),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }
}

Future<void> _printPurchaseInvoice(
    BuildContext context, PurchaseInvoice inv) async {
  final items = await InvoiceDao().getPurchaseInvoiceItems(inv.id!);
  final rows = items
      .map((item) => [
            item.itemName,
            item.qty % 1 == 0
                ? item.qty.toInt().toString()
                : item.qty.toStringAsFixed(2),
            AppFormatters.formatCurrency(item.unitCost),
            AppFormatters.formatCurrency(item.total),
          ])
      .toList();

  await PdfHelper.printReport(
    context: context,
    title: 'فاتورة مشتريات ${inv.invoiceNo}',
    subtitle: 'التاريخ: ${inv.date}',
    headers: const [
      ['المنتج', 'الكمية', 'سعر الوحدة', 'الإجمالي'],
    ],
    rows: rows,
    summaryRows: [
      {'label': 'الإجمالي', 'value': AppFormatters.formatCurrency(inv.total)},
      if (inv.notes != null && inv.notes!.isNotEmpty)
        {'label': 'الملاحظات', 'value': inv.notes!},
    ],
  );
}

class _SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;
  final SupplierDao dao;
  const _SupplierDetailScreen({required this.supplier, required this.dao});
  @override
  State<_SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<_SupplierDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  List<PurchaseInvoice> _invoices = [];
  List<SupplierReceipt> _receipts = [];
  bool _loadingInvoices = true;
  bool _loadingReceipts = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadInvoices();
    _loadReceipts();
  }

  Future<void> _loadInvoices() async {
    setState(() => _loadingInvoices = true);
    try {
      final inv = await InvoiceDao()
          .getPurchaseInvoices(supplierId: widget.supplier.id!);
      if (mounted)
        setState(() {
          _invoices = inv;
          _loadingInvoices = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingInvoices = false);
    }
  }

  Future<void> _loadReceipts() async {
    setState(() => _loadingReceipts = true);
    final r = await widget.dao.getReceiptsBySupplier(widget.supplier.id!);
    if (mounted)
      setState(() {
        _receipts = r;
        _loadingReceipts = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.supplier;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.name),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'الفواتير'),
            Tab(icon: Icon(Icons.photo_camera, size: 18), text: 'الصور'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            tooltip: 'فاتورة مشتريات',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PurchaseInvoiceScreen(supplier: s),
              ),
            ).then((_) => _loadInvoices()),
          ),
        ],
      ),
      body: Column(children: [
        // Supplier info header
        Container(
          color: const Color(AppColors.primaryInt).withValues(alpha: 0.05),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            if (s.phone != null) ...[
              const Icon(Icons.phone, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(s.phone!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 16),
            ],
            if (s.section != null) ...[
              const Icon(Icons.category, size: 14, color: Colors.indigo),
              const SizedBox(width: 4),
              Text(s.section!,
                  style: const TextStyle(fontSize: 13, color: Colors.indigo)),
              const SizedBox(width: 16),
            ],
            if (s.debt > 0) ...[
              const Icon(Icons.money_off, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Text('مديونية: ${AppFormatters.formatCurrency(s.debt)}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.red,
                      fontWeight: FontWeight.bold)),
            ],
          ]),
        ),
        // Tabs
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _InvoicesTab(
                invoices: _invoices,
                loading: _loadingInvoices,
                supplier: s,
                onAddInvoice: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PurchaseInvoiceScreen(supplier: s)),
                ).then((_) => _loadInvoices()),
              ),
              _PhotosTab(
                receipts: _receipts,
                loading: _loadingReceipts,
                supplier: s,
                dao: widget.dao,
                onChanged: _loadReceipts,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Products Tab ─────────────────────────────────────────────────────────────

class _ProductsTab extends StatelessWidget {
  final List<SupplierProduct> products;
  final bool loading;
  final Supplier supplier;
  final SupplierDao dao;
  final VoidCallback onChanged;
  const _ProductsTab({
    required this.products,
    required this.loading,
    required this.supplier,
    required this.dao,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showAddProduct(context),
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
              ? const Center(
                  child: Text('لا توجد منتجات لهذا المورد',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: products.length,
                  itemBuilder: (ctx, i) {
                    final p = products[i];
                    return Card(
                      child: ListTile(
                        title: Text(p.productName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'آخر توريد: ${p.lastSuppliedAt}${p.unit != null ? " | الوحدة: ${p.unit}" : ""}'),
                        trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(AppFormatters.formatCurrency(p.unitPrice),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                              if (p.notes != null)
                                Text(p.notes!,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                            ]),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x1A0D1B4B),
                          child: Icon(Icons.inventory_2,
                              color: Color(AppColors.primaryInt), size: 20),
                        ),
                        onLongPress: () async {
                          await dao.deleteProduct(p.id!);
                          onChanged();
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _showAddProduct(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('إضافة منتج للمورد',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم المنتج *',
                  prefixIcon: Icon(Icons.inventory_2))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextFormField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'سعر الوحدة', suffixText: 'ج.م'),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: TextFormField(
              controller: unitCtrl,
              decoration: const InputDecoration(
                  labelText: 'الوحدة', hintText: 'قطعة / كيلو'),
            )),
          ]),
          const SizedBox(height: 10),
          TextFormField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظات')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final now = DateTime.now().toIso8601String().substring(0, 10);
                await dao.insertProduct(SupplierProduct(
                  supplierId: supplier.id!,
                  productName: nameCtrl.text.trim(),
                  unitPrice: double.tryParse(priceCtrl.text) ?? 0,
                  unit: unitCtrl.text.trim().isEmpty
                      ? null
                      : unitCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  lastSuppliedAt: now,
                ));
                onChanged();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('إضافة'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Invoices Tab ─────────────────────────────────────────────────────────────

class _InvoicesTab extends StatelessWidget {
  final List<PurchaseInvoice> invoices;
  final bool loading;
  final Supplier supplier;
  final VoidCallback onAddInvoice;
  const _InvoicesTab({
    required this.invoices,
    required this.loading,
    required this.supplier,
    required this.onAddInvoice,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: onAddInvoice,
        icon: const Icon(Icons.add),
        label: const Text('فاتورة مشتريات'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : invoices.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('لا توجد فواتير لهذا المورد',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AppColors.primaryInt),
                          foregroundColor: Colors.white),
                      onPressed: onAddInvoice,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة فاتورة'),
                    ),
                  ]),
                )
              : Column(children: [
                  // Summary bar
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${invoices.length} فاتورة',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            'الإجمالي: ${AppFormatters.formatCurrency(invoices.fold(0.0, (s, i) => s + i.total))}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.orange),
                          ),
                        ]),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: invoices.length,
                      itemBuilder: (ctx, i) {
                        final inv = invoices[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade100,
                              child: const Icon(Icons.receipt,
                                  color: Colors.orange, size: 20),
                            ),
                            title: Text(inv.invoiceNo,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(inv.date,
                                style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(AppFormatters.formatCurrency(inv.total),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.orange)),
                                  if (inv.notes != null)
                                    Text(inv.notes!,
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                  const Icon(Icons.chevron_left,
                                      size: 16, color: Colors.grey),
                                ]),
                            onTap: () => _showInvoiceDetail(context, inv),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
    );
  }
}

// ─── Photos Tab ───────────────────────────────────────────────────────────────

void _showInvoiceDetail(BuildContext context, PurchaseInvoice inv) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تفاصيل الفاتورة: ${inv.invoiceNo}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.white),
                  onPressed: () => _printPurchaseInvoice(ctx, inv),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'طباعة الفاتورة',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                'التاريخ: ${inv.date}  |  الإجمالي: ${AppFormatters.formatCurrency(inv.total)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (inv.notes != null)
                Text('ملاحظة: ${inv.notes!}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Text('اسم المنتج',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey))),
              SizedBox(width: 8),
              SizedBox(
                  width: 48,
                  child: Text('الكمية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey))),
              SizedBox(width: 8),
              SizedBox(
                  width: 64,
                  child: Text('السعر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey))),
              SizedBox(width: 8),
              SizedBox(
                  width: 72,
                  child: Text('الإجمالي',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<PurchaseInvoiceItem>>(
              future: InvoiceDao().getPurchaseInvoiceItems(inv.id!),
              builder: (ctx2, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Text('لا توجد تفاصيل لهذه الفاتورة',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.separated(
                  controller: ctrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx3, i) {
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Expanded(
                          flex: 3,
                          child: Text(item.itemName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          child: Text(
                            item.qty % 1 == 0
                                ? item.qty.toInt().toString()
                                : item.qty.toStringAsFixed(2),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            AppFormatters.formatCurrency(item.unitCost),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: Text(
                            AppFormatters.formatCurrency(item.total),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.orange),
                          ),
                        ),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _PhotosTab extends StatelessWidget {
  final List<SupplierReceipt> receipts;
  final bool loading;
  final Supplier supplier;
  final SupplierDao dao;
  final VoidCallback onChanged;
  const _PhotosTab({
    required this.receipts,
    required this.loading,
    required this.supplier,
    required this.dao,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _addReceipt(context),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('إضافة صورة'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : receipts.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.photo_camera,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('لا توجد صور فواتير',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white),
                      onPressed: () => _addReceipt(context),
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('التقاط صورة فاتورة'),
                    ),
                  ]),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: receipts.length,
                  itemBuilder: (ctx, i) {
                    final r = receipts[i];
                    final hasImage =
                        r.imagePath != null && File(r.imagePath!).existsSync();
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 1,
                      child: InkWell(
                        onTap: hasImage
                            ? () => _viewImage(ctx, r.imagePath!)
                            : null,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Container(
                                  color: Colors.grey.shade100,
                                  child: hasImage
                                      ? Image.file(
                                          File(r.imagePath!),
                                          fit: BoxFit.cover,
                                        )
                                      : Center(
                                          child: Icon(
                                            Icons.image_not_supported_outlined,
                                            color: Colors.grey.shade400,
                                            size: 28,
                                          ),
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.date,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                    if (r.notes != null &&
                                        r.notes!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        r.notes!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 18),
                                  tooltip: 'حذف الصورة',
                                  onPressed: () async {
                                    await dao.deleteReceipt(r.id!);
                                    onChanged();
                                  },
                                ),
                              ),
                            ]),
                      ),
                    );
                  },
                ),
    );
  }

  void _viewImage(BuildContext context, String path) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                  appBar: AppBar(
                    title: const Text('صورة الفاتورة'),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  backgroundColor: Colors.black,
                  body: Center(
                      child: InteractiveViewer(
                    child: Image.file(File(path)),
                  )),
                )));
  }

  Future<void> _addReceipt(BuildContext context) async {
    final picker = ImagePicker();
    String? selectedDate = DateTime.now().toIso8601String().substring(0, 10);
    final notesCtrl = TextEditingController();
    String? imagePath;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                    left: 20,
                    right: 20,
                    top: 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('إضافة صورة فاتورة',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  // Date selector
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.tryParse(selectedDate!) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setS(() => selectedDate =
                            picked.toIso8601String().substring(0, 10));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today,
                            color: Colors.grey, size: 18),
                        const SizedBox(width: 10),
                        Text(selectedDate ?? 'اختر التاريخ',
                            style: const TextStyle(fontSize: 14)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Image selection
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final x = await picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 70,
                          );
                          if (x != null) setS(() => imagePath = x.path);
                        },
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('كاميرا'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.teal),
                          foregroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final x = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                          );
                          if (x != null) setS(() => imagePath = x.path);
                        },
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('معرض'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.indigo),
                          foregroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ]),
                  if (imagePath != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(imagePath!),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة / وصف',
                      prefixIcon: Icon(Icons.note),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () async {
                        final receipt = SupplierReceipt(
                          supplierId: supplier.id!,
                          date: selectedDate!,
                          notes: notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                          imagePath: imagePath,
                          createdAt: DateTime.now().toIso8601String(),
                        );
                        await dao.insertReceipt(receipt);
                        onChanged();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ الصورة'),
                    ),
                  ),
                ]),
              )),
    );
  }
}

// ─── Summary Chip ─────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SummaryChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
