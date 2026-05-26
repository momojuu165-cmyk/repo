import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/inventory_provider.dart';
import '../../../database/daos/item_dao.dart';
import '../../../database/daos/installment_product_dao.dart';
import '../../../models/item.dart';
import '../../../models/installment_product.dart';
import '../../../models/warehouse.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/image_helper.dart';
import '../installment_products/installment_products_screen.dart';

// ─── Supabase Storage image upload helper ─────────────────────────────────────
Future<String?> _uploadProductImage(String localPath) async {
  try {
    final file = File(localPath);
    if (!file.existsSync()) return null;
    final bytes = await file.readAsBytes();
    final ext = localPath.split('.').last.toLowerCase();
    final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final client = Supabase.instance.client;
    await client.storage
        .from('product-images')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$safeExt',
            upsert: true,
          ),
        );
    return client.storage.from('product-images').getPublicUrl(fileName);
  } catch (_) {
    return null;
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InstallmentProduct> _installmentProducts = [];
  bool _loadingInstallment = false;
  String _ipQuery = '';
  // null = all, 'main', 'electrical', 'installment', 'clothing', 'mobiles', 'accessories'
  String? _deptFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadAll();
      _loadInstallmentProducts();
    });
  }

  Future<void> _loadInstallmentProducts() async {
    if (_loadingInstallment || _installmentProducts.isNotEmpty) return;
    setState(() => _loadingInstallment = true);
    try {
      final dao = InstallmentProductDao();
      final products = await dao.getAll();
      if (mounted) setState(() { _installmentProducts = products; _loadingInstallment = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingInstallment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزن'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'نقل بين المخازن',
            onPressed: () => _showTransferDialog(context),
          ),
        ],
      ),
      body: _buildAllProducts(context),
      // ─── FAB: Add new product directly in the makhzan ──────────────────
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Primary: add regular makhzan (inventory) product
          FloatingActionButton.extended(
            heroTag: 'add_inventory_product',
            backgroundColor: const Color(AppColors.primaryInt),
            foregroundColor: Colors.white,
            onPressed: () => _addInventoryProductDirect(context),
            icon: const Icon(Icons.add),
            label: const Text('إضافة للمخزن'),
          ),
          const SizedBox(height: 10),
          // Secondary: other product types
          FloatingActionButton(
            heroTag: 'add_other_product',
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            mini: true,
            tooltip: 'منتج تقسيط / كهربائي',
            onPressed: () => _showCreateProductDialog(context),
            child: const Icon(Icons.more_horiz),
          ),
        ],
      ),
    );
  }

  /// Opens the add-item form sheet to add a new regular inventory product
  void _addInventoryProductDirect(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: const _AddItemSheet(),
        ),
      ),
    );
  }

  void _showCreateProductDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('إنشاء منتج جديد',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Icon(Icons.store, color: Colors.blue.shade700)),
                title: const Text('منتج مخزن عادي'),
                subtitle: const Text('منتج يُضاف مباشرة للمخزن الرئيسي'),
                onTap: () {
                  Navigator.pop(context);
                  _addInventoryProductDirect(context);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: Icon(Icons.inventory_2, color: Colors.green.shade700)),
                title: const Text('منتج تقسيط / كهربائي'),
                subtitle: const Text('منتج يظهر في قوائم التقسيط والكهربائيات'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InstallmentProductsScreen()),
                  ).then((_) => _loadInstallmentProducts());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllProducts(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final allSearch = _ipQuery;

    final mainItems = provider.items.where((item) {
      return allSearch.isEmpty ||
          item.name.toLowerCase().contains(allSearch.toLowerCase()) ||
          (item.barcode?.toLowerCase().contains(allSearch.toLowerCase()) ?? false);
    }).toList();

    final installItems = _installmentProducts.where((p) {
      final matchSearch = allSearch.isEmpty ||
          p.name.toLowerCase().contains(allSearch.toLowerCase()) ||
          (p.category?.toLowerCase().contains(allSearch.toLowerCase()) ?? false);
      if (!matchSearch) return false;
      if (_deptFilter == null) return true;
      if (_deptFilter == 'main') return false;
      return p.storeType == _deptFilter;
    }).toList();

    final showMain = _deptFilter == null || _deptFilter == 'main';

    final totalCount = (showMain ? mainItems.length : 0) + installItems.length;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'بحث في كل المنتجات...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
            suffixIcon: _ipQuery.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _ipQuery = ''))
                : null,
          ),
          onChanged: (v) => setState(() => _ipQuery = v),
        ),
      ),
      // ─── Department filter chips ───────────────────────────────────────
      Container(
        color: Colors.grey.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _DepChip('الكل', Icons.all_inclusive, Colors.grey, _deptFilter == null,
                () => setState(() => _deptFilter = null)),
            const SizedBox(width: 6),
            _DepChip('المخزن', Icons.store, Colors.blue, _deptFilter == 'main',
                () => setState(() => _deptFilter = 'main')),
            const SizedBox(width: 6),
            _DepChip('كهربائيات', Icons.electrical_services, Colors.orange, _deptFilter == AppConstants.storeElectrical,
                () => setState(() => _deptFilter = AppConstants.storeElectrical)),
            const SizedBox(width: 6),
            _DepChip('تقسيط', Icons.shopping_bag, Colors.teal, _deptFilter == AppConstants.storeInstallment,
                () => setState(() => _deptFilter = AppConstants.storeInstallment)),
            const SizedBox(width: 6),
            _DepChip('ملابس', Icons.checkroom, Colors.pink, _deptFilter == AppConstants.storeClothing,
                () => setState(() => _deptFilter = AppConstants.storeClothing)),
            const SizedBox(width: 6),
            _DepChip('موبايلات', Icons.phone_android, Colors.purple, _deptFilter == AppConstants.storeMobiles,
                () => setState(() => _deptFilter = AppConstants.storeMobiles)),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(children: [
          Text('$totalCount منتج', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          if (showMain)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text('${mainItems.length} مخزن', style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
            ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
            child: Text('${installItems.length} منتج', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
          ),
        ]),
      ),
      if (_loadingInstallment && _installmentProducts.isEmpty)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
            itemCount: (showMain ? mainItems.length : 0) + installItems.length,
            itemBuilder: (ctx, i) {
              final mainCount = showMain ? mainItems.length : 0;
              if (i < mainCount) {
                final item = mainItems[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: buildProductImage(
                        item.imagePath,
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(8),
                        fallback: const Icon(Icons.inventory_2, size: 22, color: Colors.blue),
                      ),
                    ),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      'كمية: ${item.quantity} | سعر البيع: ${AppFormatters.formatCurrency(item.priceRetail)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)),
                          child: const Text('مخزن', style: TextStyle(fontSize: 10, color: Colors.blue)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                title: const Text('حذف المنتج'),
                                content: Text('هل تريد حذف "${item.name}" من المخزن؟'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('إلغاء')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(_, true),
                                    child: const Text('حذف'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await ItemDao().delete(item.id!);
                              if (ctx.mounted) context.read<InventoryProvider>().loadAll();
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () => showModalBottomSheet(
                      context: ctx,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (_) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.85,
                        maxChildSize: 0.97,
                        minChildSize: 0.5,
                        builder: (_, controller) => SingleChildScrollView(
                          controller: controller,
                          child: _AddItemSheet(item: item),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                final p = installItems[i - mainCount];
                final imgPath = p.imagePaths.isNotEmpty ? p.imagePaths.first : p.imagePath;
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                      child: imgPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: buildProductImage(imgPath, width: 42, height: 42, fit: BoxFit.cover, borderRadius: BorderRadius.circular(8)))
                          : const Icon(Icons.inventory_2_outlined, size: 22, color: Colors.green),
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      p.category != null ? '${p.category} | ${AppFormatters.formatCurrency(p.salePrice)}' : AppFormatters.formatCurrency(p.salePrice),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade200)),
                          child: const Text('تقسيط', style: TextStyle(fontSize: 10, color: Colors.green)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                title: const Text('حذف المنتج'),
                                content: Text('هل تريد حذف "${p.name}"؟'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('إلغاء')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(_, true),
                                    child: const Text('حذف'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await InstallmentProductDao().delete(p.id!);
                              if (ctx.mounted) setState(() => _installmentProducts.remove(p));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ),
    ]);
  }

  void _showTransferDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _TransferDialog(),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Item item;

  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<InventoryProvider>();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: buildProductImage(
          item.imagePath,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(8),
          fallback: const Icon(Icons.inventory_2, size: 40, color: Colors.grey),
        ),
        title: Text(item.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكمية: ${item.quantity}'),
            Text(
              'سعر البيع: ${AppFormatters.formatCurrency(item.priceRetail)}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.isBlocked)
              const Icon(Icons.block, color: Colors.red, size: 16),
            if (item.quantity <= 5 && !item.isBlocked)
              const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
            Text(
              item.barcode ?? '',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        onTap: () => _showItemDetails(context, item),
        onLongPress: () => provider.toggleBlocked(item.id!, !item.isBlocked),
      ),
    );
  }

  void _showItemDetails(BuildContext context, Item item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddItemSheet(item: item),
    );
  }
}

class _AddItemSheet extends StatefulWidget {
  final Item? item;

  const _AddItemSheet({this.item});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _purchaseCtrl;
  late final TextEditingController _salePriceCtrl;
  late final TextEditingController _notesCtrl;
  int? _warehouseId;
  String? _imagePath;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?.name);
    _barcodeCtrl = TextEditingController(text: widget.item?.barcode);
    _qtyCtrl = TextEditingController(
        text: widget.item?.quantity.toString() ?? '0');
    _purchaseCtrl = TextEditingController(
        text: widget.item?.purchasePrice.toString() ?? '0');
    _salePriceCtrl = TextEditingController(
        text: widget.item?.priceRetail.toString() ?? '0');
    _notesCtrl = TextEditingController(text: widget.item?.notes);
    _warehouseId = widget.item?.warehouseId;
    _imagePath = widget.item?.imagePath;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _barcodeCtrl,
      _qtyCtrl,
      _purchaseCtrl,
      _salePriceCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    setState(() { _uploading = true; _imagePath = picked.path; });
    final url = await _uploadProductImage(picked.path);
    if (mounted) {
      setState(() {
        _imagePath = url ?? picked.path;
        _uploading = false;
      });
    }
  }

  void _showAddWarehouseDialog(BuildContext context, InventoryProvider provider) {
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    showDialog(
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await provider.addWarehouse(Warehouse(
                name: nameCtrl.text.trim(),
                location: locCtrl.text.trim().isEmpty
                    ? null
                    : locCtrl.text.trim(),
              ));
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء الانتظار حتى ينتهي رفع الصورة')),
      );
      return;
    }
    final now = DateTime.now().toIso8601String();
    final salePrice = double.tryParse(_salePriceCtrl.text) ?? 0;
    final item = Item(
      id: widget.item?.id,
      barcode:
          _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      groupId: null,
      warehouseId: _warehouseId,
      purchasePrice: double.tryParse(_purchaseCtrl.text) ?? 0,
      priceRetail: salePrice,
      priceSemiWholesale: salePrice,
      priceWholesale: salePrice,
      priceSpecial: salePrice,
      quantity: double.tryParse(_qtyCtrl.text) ?? 0,
      unit: null,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      imagePath: _imagePath,
      createdAt: widget.item?.createdAt ?? now,
    );
    final provider = context.read<InventoryProvider>();
    if (widget.item == null) {
      await provider.addItem(item);
    } else {
      await provider.updateItem(item);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item == null ? 'إضافة منتج للمخزن' : 'تعديل المنتج',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _uploading ? null : _pickImage,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: _uploading
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2),
                          SizedBox(height: 8),
                          Text('جاري رفع الصورة...', style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    : _imagePath != null && _imagePath!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: buildProductImage(
                              _imagePath,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                              fallback: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                  Text('تعذّر عرض الصورة'),
                                ],
                              ),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                              Text('اضغط لإضافة صورة'),
                            ],
                          ),
              ),
            ),
            if (_imagePath != null && !_uploading)
              TextButton.icon(
                onPressed: () => setState(() => _imagePath = null),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                label: const Text('حذف الصورة', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المنتج *'),
              validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _barcodeCtrl,
              decoration: const InputDecoration(labelText: 'الباركود'),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 8),
            provider.warehouses.isEmpty
                ? OutlinedButton.icon(
                    icon: const Icon(Icons.add_business, size: 18),
                    label: const Text('إضافة مخزن', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showAddWarehouseDialog(context, provider),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        value: _warehouseId,
                        decoration: const InputDecoration(labelText: 'المخزن'),
                        hint: const Text('اختر مخزن'),
                        items: provider.warehouses
                            .map((w) => DropdownMenuItem(
                                value: w.id, child: Text(w.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _warehouseId = v),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add_business, size: 18),
                          label: const Text('إضافة مخزن جديد', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showAddWarehouseDialog(context, provider),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 8),
            const Text('الأسعار', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchaseCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'سعر الشراء',
                      prefixIcon: Icon(Icons.arrow_downward, size: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _salePriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'سعر البيع *',
                      prefixIcon: Icon(Icons.sell_outlined, size: 16),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'مطلوب';
                      if ((double.tryParse(v) ?? -1) < 0) return 'رقم غير صحيح';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'الكمية'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white,
                ),
                onPressed: _save,
                child: const Text('حفظ المنتج'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog();

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  int? _fromWarehouse;
  int? _toWarehouse;
  int? _itemId;
  double _qty = 1;

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    return AlertDialog(
      title: const Text('نقل بين المخازن'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'من مخزن'),
            items: inv.warehouses
                .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                .toList(),
            onChanged: (v) => setState(() => _fromWarehouse = v),
          ),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'إلى مخزن'),
            items: inv.warehouses
                .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                .toList(),
            onChanged: (v) => setState(() => _toWarehouse = v),
          ),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'المنتج'),
            items: inv.items
                .map((i) => DropdownMenuItem(value: i.id, child: Text(i.name)))
                .toList(),
            onChanged: (v) => setState(() => _itemId = v),
          ),
          TextFormField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الكمية'),
            initialValue: '1',
            onChanged: (v) => _qty = double.tryParse(v) ?? 1,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () async {
            if (_fromWarehouse == null ||
                _toWarehouse == null ||
                _itemId == null) return;
            await context.read<InventoryProvider>().transferItems(
                  fromId: _fromWarehouse!,
                  toId: _toWarehouse!,
                  itemId: _itemId!,
                  qty: _qty,
                );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('نقل'),
        ),
      ],
    );
  }
}

// ─── Department filter chip ─────────────────────────────────────────────────
class _DepChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _DepChip(this.label, this.icon, this.color, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700),
          ),
        ]),
      ),
    );
  }
}
