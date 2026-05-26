import 'package:flutter/material.dart';
import '../../../database/daos/electrical_bundle_dao.dart';
import '../../../database/daos/installment_product_dao.dart';
import '../../../models/electrical_bundle.dart';
import '../../../models/installment_product.dart';
import 'dart:io';
import '../../../utils/image_helper.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class ElectricalBundlesScreen extends StatefulWidget {
  const ElectricalBundlesScreen({super.key});
  @override
  State<ElectricalBundlesScreen> createState() => _ElectricalBundlesScreenState();
}

class _ElectricalBundlesScreenState extends State<ElectricalBundlesScreen> {
  final _dao = ElectricalBundleDao();
  List<ElectricalBundle> _bundles = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final b = await _dao.getAllBundles();
    if (mounted) setState(() { _bundles = b; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ليستات الأدوات الكهربائية'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _openBundleForm(),
        icon: const Icon(Icons.add_box),
        label: const Text('ليسته جديدة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bundles.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.bolt, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('لا توجد ليستات بعد', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _openBundleForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('إنشاء ليسته جديدة'),
                    ),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _bundles.length,
                  itemBuilder: (ctx, i) {
                    final b = _bundles[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.withValues(alpha: 0.15),
                          child: const Icon(Icons.bolt, color: Colors.amber),
                        ),
                        title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Text(
                                  'خصم ${b.discountRate.toStringAsFixed(0)}%',
                                  style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'وفر ${AppFormatters.formatCurrency(b.savings)}',
                                style: const TextStyle(color: Colors.green, fontSize: 11),
                              ),
                            ]),
                            Text('${b.items.length} منتج في الليسته', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Switch(
                            value: b.isActive,
                            activeColor: const Color(AppColors.primaryInt),
                            onChanged: (v) async {
                              await _dao.updateBundle(ElectricalBundle(
                                id: b.id, name: b.name, description: b.description,
                                discountRate: b.discountRate, isActive: v, createdAt: b.createdAt,
                              ));
                              _load();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _openBundleForm(bundle: b),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteBundle(b),
                          ),
                        ]),
                        children: [
                          if (b.description != null && b.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Text(b.description!, style: const TextStyle(color: Colors.grey)),
                            ),
                          if (b.items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('لا توجد منتجات في هذه الليسته', style: TextStyle(color: Colors.grey)),
                            )
                          else
                            ...b.items.map((item) {
                              final imgPath = item.imagePath;
                              return ListTile(
                              dense: true,
                              leading: imgPath != null
                                  ? (imgPath.startsWith('http') || File(imgPath).existsSync()
                                      ? ClipRRect(borderRadius: BorderRadius.circular(4), child: buildProductImage(imgPath, width: 32, height: 32, fit: BoxFit.cover))
                                      : const Icon(Icons.electrical_services, size: 18, color: Colors.blue))
                                  : const Icon(Icons.electrical_services, size: 18, color: Colors.blue),
                              title: Text(item.itemName),
                              trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(
                                  AppFormatters.formatCurrency(item.originalPrice),
                                  style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 11, color: Colors.grey),
                                ),
                                Text(
                                  AppFormatters.formatCurrency(item.originalPrice * (1 - b.discountRate / 100)),
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ]),
                            );}).toList(),
                          Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(children: [
                              Expanded(child: Column(children: [
                                const Text('الإجمالي الأصلي', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(
                                  AppFormatters.formatCurrency(b.totalOriginalPrice),
                                  style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 13),
                                ),
                              ])),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                              Expanded(child: Column(children: [
                                const Text('بعد الخصم', style: TextStyle(fontSize: 10, color: Colors.green)),
                                Text(
                                  AppFormatters.formatCurrency(b.totalDiscountedPrice),
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ])),
                            ]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _deleteBundle(ElectricalBundle b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('حذف الليسته'),
        content: Text('هل تريد حذف باقة "${b.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _dao.deleteBundle(b.id!);
      _load();
    }
  }

  void _openBundleForm({ElectricalBundle? bundle}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BundleFormScreen(
          bundle: bundle,
          dao: _dao,
          onSaved: _load,
        ),
      ),
    );
  }
}

class _BundleFormScreen extends StatefulWidget {
  final ElectricalBundle? bundle;
  final ElectricalBundleDao dao;
  final VoidCallback onSaved;

  const _BundleFormScreen({
    this.bundle,
    required this.dao,
    required this.onSaved,
  });

  @override
  State<_BundleFormScreen> createState() => _BundleFormScreenState();
}

class _BundleFormScreenState extends State<_BundleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _discountCtrl;
  late bool _isActive;
  List<ElectricalBundleItem> _selectedItems = [];
  List<InstallmentProduct> _allItems = [];
  bool _loadingItems = false;
  bool _saving = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.bundle?.name ?? '');
    _descCtrl = TextEditingController(text: widget.bundle?.description ?? '');
    _discountCtrl = TextEditingController(text: (widget.bundle?.discountRate ?? 0).toString());
    _isActive = widget.bundle?.isActive ?? true;
    _selectedItems = List.from(widget.bundle?.items ?? []);
    _loadItems();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _loadingItems = true);
    final dao = InstallmentProductDao();
    final items = await dao.getAll(storeType: AppConstants.storeElectrical);
    if (mounted) setState(() { _allItems = items; _loadingItems = false; });
  }

  List<InstallmentProduct> get _filteredItems {
    if (_searchQuery.isEmpty) return _allItems;
    return _allItems.where((i) =>
      i.name.contains(_searchQuery)
    ).toList();
  }

  bool _isItemSelected(int itemId) => _selectedItems.any((i) => i.itemId == itemId);

  void _toggleItem(InstallmentProduct item) {
    setState(() {
      if (_isItemSelected(item.id!)) {
        _selectedItems.removeWhere((i) => i.itemId == item.id);
      } else {
        _selectedItems.add(ElectricalBundleItem(
          bundleId: widget.bundle?.id ?? 0,
          itemId: item.id!,
          itemName: item.name,
          originalPrice: item.salePrice > 0 ? item.salePrice : item.cashPrice,
          imagePath: item.imagePath,
        ));
      }
    });
  }

  double get _discountRate => double.tryParse(_discountCtrl.text) ?? 0;
  double get _totalOriginal => _selectedItems.fold(0, (s, i) => s + i.originalPrice);
  double get _totalDiscounted => _totalOriginal * (1 - _discountRate / 100);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final bundle = ElectricalBundle(
        id: widget.bundle?.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        discountRate: _discountRate,
        isActive: _isActive,
        createdAt: widget.bundle?.createdAt ?? now,
      );
      int bundleId;
      if (widget.bundle == null) {
        bundleId = await widget.dao.insertBundle(bundle);
      } else {
        await widget.dao.updateBundle(bundle);
        bundleId = widget.bundle!.id!;
      }
      final updatedItems = _selectedItems.map((item) => ElectricalBundleItem(
        bundleId: bundleId,
        itemId: item.itemId,
        itemName: item.itemName,
        originalPrice: item.originalPrice,
        imagePath: item.imagePath,
      )).toList();
      await widget.dao.setBundleItems(bundleId, updatedItems);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final msg = e.toString();
        final isFkError = msg.contains('23503') ||
            msg.contains('foreign key') ||
            msg.contains('electrical_bundle_items_item_id_fkey');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFkError
                  ? 'خطأ في قاعدة البيانات: المنتجات المختارة غير مرتبطة بجدول items.\n'
                    'الحل: افتح Supabase → SQL Editor وشغّل:\n'
                    'ALTER TABLE electrical_bundle_items DROP CONSTRAINT electrical_bundle_items_item_id_fkey;'
                  : 'حدث خطأ أثناء الحفظ: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bundle == null ? 'ليسته جديدة' : 'تعديل ${widget.bundle!.name}'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save, color: Colors.white),
            label: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Bundle info card
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('معلومات الليسته', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم الليسته *',
                          prefixIcon: Icon(Icons.bolt),
                          isDense: true,
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الوصف',
                          prefixIcon: Icon(Icons.description),
                          isDense: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _discountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'نسبة الخصم',
                                prefixIcon: Icon(Icons.percent),
                                suffixText: '%',
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Switch(
                            value: _isActive,
                            activeColor: const Color(AppColors.primaryInt),
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                          const Text('نشطة'),
                        ],
                      ),
                      if (_selectedItems.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(children: [
                                const Text('قبل الخصم', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(
                                  AppFormatters.formatCurrency(_totalOriginal),
                                  style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 12),
                                ),
                              ]),
                              const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                              Column(children: [
                                const Text('بعد الخصم', style: TextStyle(fontSize: 10, color: Colors.green)),
                                Text(
                                  AppFormatters.formatCurrency(_totalDiscounted),
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ]),
                              Column(children: [
                                const Text('توفير', style: TextStyle(fontSize: 10, color: Colors.orange)),
                                Text(
                                  AppFormatters.formatCurrency(_totalOriginal - _totalDiscounted),
                                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Selected items header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(AppColors.primaryInt).withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(Icons.shopping_basket, size: 16, color: Color(AppColors.primaryInt)),
                  const SizedBox(width: 6),
                  Text(
                    'المنتجات في الليسته (${_selectedItems.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(AppColors.primaryInt)),
                  ),
                ],
              ),
            ),
            if (_selectedItems.isNotEmpty)
              Container(
                color: Colors.green.shade50,
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _selectedItems.length,
                  itemBuilder: (_, i) {
                    final item = _selectedItems[i];
                    final imgPath = item.imagePath;
                    return ListTile(
                      dense: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: imgPath != null && (imgPath.startsWith('http') || File(imgPath).existsSync())
                            ? buildProductImage(imgPath, width: 32, height: 32, fit: BoxFit.cover)
                            : const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      ),
                      title: Text(item.itemName, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${AppFormatters.formatCurrency(item.originalPrice)} → ${AppFormatters.formatCurrency(item.originalPrice * (1 - _discountRate / 100))}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
                        onPressed: () => setState(() => _selectedItems.removeAt(i)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    );
                  },
                ),
              ),
            // Search box for items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'ابحث عن منتج لإضافته للليسته...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            // Items list
            Expanded(
              child: _loadingItems
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredItems.isEmpty
                      ? const Center(child: Text('لا توجد منتجات', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _filteredItems.length,
                          itemBuilder: (_, i) {
                            final item = _filteredItems[i];
                            final selected = _isItemSelected(item.id!);
                            final imgPath = item.imagePath;
                            return ListTile(
                              dense: true,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: imgPath != null && (imgPath.startsWith('http') || File(imgPath).existsSync())
                                    ? buildProductImage(imgPath, width: 40, height: 40, fit: BoxFit.cover)
                                    : Container(
                                        width: 40, height: 40,
                                        color: selected ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                                        child: Icon(
                                          selected ? Icons.check : Icons.electrical_services,
                                          color: selected ? Colors.green : Colors.grey,
                                          size: 18,
                                        ),
                                      ),
                              ),
                              title: Text(item.name, style: const TextStyle(fontSize: 13)),
                              subtitle: Text(
                                'سعر التقسيط: ${AppFormatters.formatCurrency(item.salePrice > 0 ? item.salePrice : item.cashPrice)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: selected
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.add_circle_outline, color: Color(AppColors.primaryInt)),
                              onTap: () => _toggleItem(item),
                              selected: selected,
                              selectedTileColor: Colors.green.withValues(alpha: 0.05),
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
