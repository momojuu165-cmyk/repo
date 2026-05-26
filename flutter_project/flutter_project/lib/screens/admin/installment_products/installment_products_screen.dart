import 'dart:io';
import '../../../utils/image_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../database/daos/installment_product_dao.dart';
import '../../../database/daos/product_image_dao.dart';
import '../../../database/daos/item_dao.dart';
import '../../../database/daos/app_settings_dao.dart';
import '../../../models/app_settings.dart';
import '../../../models/installment_product.dart';
import '../../../models/product_image.dart';
import '../../../models/item_group.dart';
import '../../../models/partner_group.dart';
import '../../../database/daos/partner_group_dao.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import 'product_detail_screen.dart';

class InstallmentProductsScreen extends StatefulWidget {
  final String? initialStoreType; // null=all, 'installment', 'electrical', 'clothing', or any custom slug
  final String? departmentName;   // human-readable name for the title bar
  const InstallmentProductsScreen({super.key, this.initialStoreType, this.departmentName});
  @override
  State<InstallmentProductsScreen> createState() => _InstallmentProductsScreenState();
}

class _InstallmentProductsScreenState extends State<InstallmentProductsScreen> with SingleTickerProviderStateMixin {
  final _dao = InstallmentProductDao();
  List<InstallmentProduct> _products = [];
  List<ItemGroup> _groups = [];
  bool _loading = true;
  TabController? _tabController;
  List<String> _categories = [];
  String? _storeTypeFilter; // null=الكل, 'installment', 'electrical', 'clothing'

  @override
  void initState() {
    super.initState();
    _storeTypeFilter = widget.initialStoreType;
    _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await _dao.getAll(); // load ALL products (filtered later by _getForCategory)
    final itemDao = ItemDao();
    // Load only categories that belong to the currently active store-type section.
    // When no filter is applied (admin "all" view) fall back to all groups.
    final List<ItemGroup> groups;
    if (_storeTypeFilter != null) {
      groups = await itemDao.getGroupsByStoreType(_storeTypeFilter!);
    } else {
      groups = await itemDao.getAllGroups();
    }
    if (mounted) {
      final cats = groups.map((g) => g.name).toList();
      _tabController?.dispose();
      _tabController = TabController(length: cats.length + 1, vsync: this);
      setState(() {
        _products = p;
        _groups = groups;
        _categories = cats;
        _loading = false;
      });
    }
  }

  List<InstallmentProduct> _getForCategory(String? cat) {
    var list = _storeTypeFilter == null
        ? _products
        : _products.where((p) => p.storeType == _storeTypeFilter).toList();
    if (cat == null) return list;
    return list.where((p) => p.category == cat).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.departmentName != null
            ? 'منتجات ${widget.departmentName}'
            : _storeTypeFilter == 'electrical' ? 'منتجات الكهربائية'
            : _storeTypeFilter == 'clothing' ? 'منتجات الملابس'
            : _storeTypeFilter == 'installment' ? 'منتجات التقسيط'
            : 'منتجات المتجر'),
        backgroundColor: _storeTypeFilter == 'electrical' ? Colors.orange.shade800
            : _storeTypeFilter == 'clothing' ? const Color(AppColors.clothingInt)
            : _storeTypeFilter == 'installment' ? const Color(AppColors.installmentInt)
            : _storeTypeFilter != null ? const Color(AppColors.primaryInt)
            : const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.category), tooltip: 'إدارة الفئات', onPressed: _showManageCategoriesDialog),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: _categories.isEmpty
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  const Tab(text: 'الكل', icon: Icon(Icons.all_inclusive, size: 16)),
                  ..._categories.map((c) => Tab(text: c)),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة منتج'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // ─── Store Type Filter Chips ───────────────────────────────────
              if (widget.initialStoreType == null) Container(
                color: Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _StoreFilterChip(label: 'الكل', icon: Icons.all_inclusive, color: Colors.grey,
                        selected: _storeTypeFilter == null,
                        onTap: () { _storeTypeFilter = null; _load(); }),
                    const SizedBox(width: 8),
                    _StoreFilterChip(label: 'التقسيط', icon: Icons.shopping_bag, color: Colors.teal,
                        selected: _storeTypeFilter == AppConstants.storeInstallment,
                        onTap: () { _storeTypeFilter = AppConstants.storeInstallment; _load(); }),
                    const SizedBox(width: 8),
                    _StoreFilterChip(label: 'الكهربائي', icon: Icons.electrical_services, color: Colors.orange,
                        selected: _storeTypeFilter == AppConstants.storeElectrical,
                        onTap: () { _storeTypeFilter = AppConstants.storeElectrical; _load(); }),
                    const SizedBox(width: 8),
                    _StoreFilterChip(label: 'الملابس', icon: Icons.checkroom, color: Color(AppColors.clothingInt),
                        selected: _storeTypeFilter == AppConstants.storeClothing,
                        onTap: () { _storeTypeFilter = AppConstants.storeClothing; _load(); }),
                    const SizedBox(width: 8),
                    _StoreFilterChip(label: 'الموبايلات', icon: Icons.phone_android, color: Color(AppColors.mobilesInt),
                        selected: _storeTypeFilter == AppConstants.storeMobiles,
                        onTap: () { _storeTypeFilter = AppConstants.storeMobiles; _load(); }),
                    const SizedBox(width: 8),
                    _StoreFilterChip(label: 'الإكسسوارات', icon: Icons.watch, color: Color(AppColors.accessoriesInt),
                        selected: _storeTypeFilter == AppConstants.storeAccessories,
                        onTap: () { _storeTypeFilter = AppConstants.storeAccessories; _load(); }),
                  ]),
                ),
              ),
              Expanded(
                child: _categories.isEmpty
                    ? _buildProductList(null)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildProductList(null),
                          ..._categories.map((c) => _buildProductList(c)),
                        ],
                      ),
              ),
            ]),
    );
  }

  Widget _buildProductList(String? category) {
    final items = _getForCategory(category);
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(category == null ? 'لا توجد منتجات بعد' : 'لا توجد منتجات في فئة "$category"',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: const Text('إضافة منتج')),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final p = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: (p.imagePaths.isNotEmpty || p.imagePath != null)
                ? (() {
                    final imgP = p.imagePaths.isNotEmpty ? p.imagePaths.first : p.imagePath!;
                    return buildProductImage(imgP, width: 48, height: 48, fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(8));
                  })()
                    : CircleAvatar(
                        backgroundColor: p.isAvailable ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                        child: Icon(Icons.inventory_2, color: p.isAvailable ? Colors.green : Colors.grey)),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
            ),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.category != null)
                Row(children: [
                  const Icon(Icons.category, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(p.category!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              Row(children: [
                if (p.showCashPrice)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('كاش: ${AppFormatters.formatCurrency(p.effectiveCashPrice)}',
                        style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                if (p.showInstallmentPrice)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('تقسيط: ${AppFormatters.formatCurrency(p.effectiveInstallmentPrice)}',
                        style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
              ]),
              Row(children: [
                if (!p.showCashPrice)
                  const Text('سعر الكاش مخفي', style: TextStyle(fontSize: 10, color: Colors.orange)),
                if (!p.showCashPrice && !p.showInstallmentPrice) const Text(' | ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                if (!p.showInstallmentPrice)
                  const Text('سعر التقسيط مخفي', style: TextStyle(fontSize: 10, color: Colors.orange)),
                if (!p.isAvailable)
                  const Text('مخفي عن العملاء', style: TextStyle(color: Colors.red, fontSize: 10)),
              ]),
              if (p.imagePaths.length > 1)
                Text('${p.imagePaths.length} صور', style: const TextStyle(fontSize: 11, color: Colors.purple)),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _storeChipColor(p.storeType).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _storeChipLabel(p.storeType),
                    style: TextStyle(
                      fontSize: 10,
                      color: _storeChipColor(p.storeType),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]),
            ]),
            isThreeLine: true,
            trailing: PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(value: 'toggle', child: Text(p.isAvailable ? 'إخفاء من العملاء' : 'إظهار للعملاء')),
                const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) async {
                if (v == 'edit') {
                  _showForm(product: p);
                } else if (v == 'toggle') {
                  await _dao.update(p.copyWith(isAvailable: !p.isAvailable));
                  _load();
                } else if (v == 'delete') {
                  await _dao.delete(p.id!);
                  _load();
                }
              },
            ),
          ),
        );
      },
    );
  }

  Color _storeChipColor(String storeType) {
    switch (storeType) {
      case AppConstants.storeElectrical: return Colors.orange;
      case AppConstants.storeClothing: return const Color(AppColors.clothingInt);
      case AppConstants.storeMobiles: return const Color(AppColors.mobilesInt);
      case AppConstants.storeAccessories: return const Color(AppColors.accessoriesInt);
      default: return Colors.teal;
    }
  }

  String _storeChipLabel(String storeType) {
    switch (storeType) {
      case AppConstants.storeElectrical: return '⚡ كهربائي';
      case AppConstants.storeClothing: return '👗 ملابس';
      case AppConstants.storeMobiles: return '📱 موبايلات';
      case AppConstants.storeAccessories: return '⌚ إكسسوارات';
      default: return '🛍️ تقسيط';
    }
  }

  void _showForm({InstallmentProduct? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProductFormScreen(
          product: product,
          groups: _groups,
          onSaved: _load,
          dao: _dao,
          initialStoreType: _storeTypeFilter,
          departmentName: widget.departmentName,
        ),
      ),
    );
  }

  // Label for the current section used in UI strings
  String get _sectionLabel {
    if (widget.departmentName != null) return widget.departmentName!;
    switch (_storeTypeFilter) {
      case AppConstants.storeElectrical: return 'الكهربائية';
      case AppConstants.storeClothing:   return 'الملابس';
      case AppConstants.storeMobiles:    return 'الموبايلات';
      case AppConstants.storeAccessories: return 'الإكسسوارات';
      default: return 'التقسيط';
    }
  }

  // The store_type to assign when adding/deleting categories in the dialog
  String get _activeStoreType =>
      _storeTypeFilter ?? AppConstants.storeInstallment;

  void _showManageCategoriesDialog() {
    final nameCtrl = TextEditingController();
    final existingCats = List<String>.from(_categories);
    final activeType = _activeStoreType; // capture before async
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.category, color: Colors.teal),
            const SizedBox(width: 8),
            Text('إدارة فئات $_sectionLabel'),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(hintText: 'اسم الفئة الجديدة', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty || existingCats.contains(name)) return;
                    await Supabase.instance.client.from('item_groups').insert({
                      'name': name,
                      'store_type': activeType,
                      'created_at': DateTime.now().toIso8601String(),
                    });
                    nameCtrl.clear();
                    setS(() => existingCats..add(name)..sort());
                    _load();
                  },
                  child: const Text('إضافة'),
                ),
              ]),
              const SizedBox(height: 12),
              if (existingCats.isEmpty)
                const Padding(padding: EdgeInsets.all(8), child: Text('لا توجد فئات بعد', style: TextStyle(color: Colors.grey)))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView(
                    shrinkWrap: true,
                    children: existingCats.map((cat) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.label, color: Colors.teal, size: 18),
                      title: Text(cat),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        onPressed: () async {
                          await Supabase.instance.client
                              .from('item_groups')
                              .delete()
                              .eq('name', cat)
                              .eq('store_type', activeType);
                          setS(() => existingCats.remove(cat));
                          _load();
                        },
                      ),
                    )).toList(),
                  ),
                ),
            ]),
          ),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      ),
    );
  }
}

// ─── Product Form Screen ───────────────────────────────────────────────────────

class _ProductFormScreen extends StatefulWidget {
  final InstallmentProduct? product;
  final List<ItemGroup> groups;
  final VoidCallback onSaved;
  final InstallmentProductDao dao;
  final String? initialStoreType;
  final String? departmentName;

  const _ProductFormScreen({this.product, required this.groups, required this.onSaved, required this.dao, this.initialStoreType, this.departmentName});

  @override
  State<_ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<_ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _salePriceCtrl;
  late final TextEditingController _cashPriceCtrl;
  late final TextEditingController _installmentPriceCtrl;
  late final TextEditingController _maxInstallmentMonthsCtrl; // Feature 5
  late bool _available;
  late bool _showCashPrice;
  late bool _showInstallmentPrice;
  String? _selectedCategory;
  late String _storeType;
  List<String> _imagePaths = [];
  bool _saving = false;

  // ── Partner group assignment ─────────────────────────────────────────────
  final _partnerGroupDao = PartnerGroupDao();
  List<PartnerGroup> _partnerGroups = [];
  List<int> _selectedGroupIds = [];
  bool _loadingPartnerGroups = true;

  // ── Installment rate settings (global) ────────────────────────────────────
  final _rateSettingsDao = AppSettingsDao();
  AppSettings _rateSettings = const AppSettings();
  bool _loadingRateSettings = true;
  late TextEditingController _monthlyRateCtrl;
  late TextEditingController _companyPercentageCtrl;
  late TextEditingController _profitRateCtrl;
  late TextEditingController _adminFeeCtrl;
  late TextEditingController _maxMonthsGlobalCtrl;
  final Map<String, TextEditingController> _rateControllers = {};
  String _priceTier = 'retail';

  @override
  void initState() {
    super.initState();
    _monthlyRateCtrl = TextEditingController();
    _profitRateCtrl = TextEditingController();
    _adminFeeCtrl = TextEditingController();
    _maxMonthsGlobalCtrl = TextEditingController();
    _companyPercentageCtrl = TextEditingController(
        text: ((widget.product?.companyPercentage ?? 0) > 0
            ? widget.product!.companyPercentage.toStringAsFixed(1)
            : '0'));
    _loadRateSettings();
    _loadPartnerGroups();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _purchasePriceCtrl = TextEditingController(text: p?.purchasePrice.toString() ?? '0');
    _salePriceCtrl = TextEditingController(text: p?.salePrice.toString() ?? '');
    _cashPriceCtrl = TextEditingController(text: (p?.cashPrice ?? 0) > 0 ? p!.cashPrice.toString() : '');
    _installmentPriceCtrl = TextEditingController(text: (p?.installmentPrice ?? 0) > 0 ? p!.installmentPrice.toString() : '');
    _priceTier = p?.priceTier ?? 'retail';
    _maxInstallmentMonthsCtrl = TextEditingController(
        text: (p?.maxInstallmentMonths ?? AppConstants.defaultMaxInstallmentMonths).toString());
    _available = p?.isAvailable ?? true;
    _showCashPrice = p?.showCashPrice ?? true;
    _showInstallmentPrice = p?.showInstallmentPrice ?? true;
    _selectedCategory = p?.category;
    _storeType = p?.storeType ?? widget.initialStoreType ?? 'installment';
    // Seed with any already-known paths, then load from product_images table
    _imagePaths = List<String>.from(
      p?.imagePaths.isNotEmpty == true
          ? p!.imagePaths
          : (p?.imagePath != null ? [p!.imagePath!] : []),
    );
    if (p?.id != null) _loadImagesFromDb(p!.id!, p.storeType);
  }

  Future<void> _loadImagesFromDb(int productId, String storeType) async {
    final imgDao = ProductImageDao();
    final paths = await imgDao.getPathsForProduct(storeType, productId);
    if (paths.isNotEmpty && mounted) {
      setState(() => _imagePaths = paths);
    }
  }

  Future<void> _loadRateSettings() async {
    try {
      final s = await _rateSettingsDao.getSettings();
      if (!mounted) return;
      _monthlyRateCtrl.text = s.monthlyInstallmentRate.toStringAsFixed(1);
      setState(() { _rateSettings = s; _loadingRateSettings = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRateSettings = false);
    }
  }

  Future<void> _loadPartnerGroups() async {
    try {
      final groups = await _partnerGroupDao.getAllGroups();
      List<int> selected = [];
      final p = widget.product;
      if (p?.id != null) {
        final itemId = p!.id!;
        final rows = await Supabase.instance.client
            .from('product_group_assignments')
            .select('group_id')
            .eq('item_id', itemId);
        selected = List<Map<String, dynamic>>.from(rows)
            .map((r) => (r['group_id'] as int))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _partnerGroups = groups;
        _selectedGroupIds = selected;
        _loadingPartnerGroups = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPartnerGroups = false);
    }
  }

  Future<void> _syncProductGroupAssignments(int productId, String itemName, double salePrice) async {
    try {
      final existingRows = await Supabase.instance.client
          .from('product_group_assignments')
          .select('id,group_id')
          .eq('item_id', productId);
      final existing = List<Map<String, dynamic>>.from(existingRows);
      final existingIds = existing.map((r) => (r['group_id'] as int)).toSet();
      final selectedIds = _selectedGroupIds.toSet();

      for (final row in existing) {
        final gid = (row['group_id'] as int);
        if (!selectedIds.contains(gid)) {
          await Supabase.instance.client
              .from('product_group_assignments')
              .delete()
              .eq('id', row['id']);
        }
      }
      for (final groupId in selectedIds) {
        if (!existingIds.contains(groupId)) {
          await _partnerGroupDao.assignProductToGroup(
            itemId: productId,
            itemName: itemName,
            groupId: groupId,
            salePrice: salePrice,
          );
        }
      }
    } catch (_) {
      // ignore sync failures silently
    }
  }

  Future<void> _saveRateSettings() async {
    try {
      final updated = _rateSettings.copyWith(
        monthlyInstallmentRate: double.tryParse(_monthlyRateCtrl.text) ?? 3.0,
      );
      await _rateSettingsDao.saveSettings(updated);
      if (mounted) setState(() => _rateSettings = updated);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _purchasePriceCtrl.dispose();
    _salePriceCtrl.dispose(); _cashPriceCtrl.dispose(); _installmentPriceCtrl.dispose();
    _profitRateCtrl.dispose(); _maxInstallmentMonthsCtrl.dispose();
    _monthlyRateCtrl.dispose(); _adminFeeCtrl.dispose(); _maxMonthsGlobalCtrl.dispose();
    _companyPercentageCtrl.dispose();
    for (final c in _rateControllers.values) c.dispose();
    super.dispose();
  }

  Future<String> _uploadImageToSupabase(String localPath) async {
    final ext = path.extension(localPath).toLowerCase();
    final contentType = ext == '.png'
        ? 'image/png'
        : ext == '.webp'
            ? 'image/webp'
            : ext == '.gif'
                ? 'image/gif'
                : 'image/jpeg';
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${path.basenameWithoutExtension(localPath)}${ext.isEmpty ? '.jpg' : ext}';
    final bytes = await File(localPath).readAsBytes();
    await Supabase.instance.client.storage
        .from('product-images')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    return Supabase.instance.client.storage
        .from('product-images')
        .getPublicUrl(fileName);
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;
    final List<String> newPaths = [];
    final List<String> failedFiles = [];
    for (final img in picked) {
      try {
        final url = await _uploadImageToSupabase(img.path);
        newPaths.add(url);
      } catch (e) {
        failedFiles.add('${path.basename(img.path)}: $e');
      }
    }
    if (newPaths.isNotEmpty) {
      setState(() => _imagePaths.addAll(newPaths));
    }
    if (failedFiles.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل رفع ${failedFiles.length} صورة.\n'
            'الخطأ: ${failedFiles.join(', ')}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  Future<void> _pickSingleImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    try {
      final url = await _uploadImageToSupabase(img.path);
      setState(() => _imagePaths.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل رفع الصورة.\nالخطأ: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final salePrice = double.tryParse(_salePriceCtrl.text) ?? 0;
      final cashPrice = double.tryParse(_cashPriceCtrl.text) ?? 0;
      final installmentPrice = double.tryParse(_installmentPriceCtrl.text) ?? 0;
      // Feature 5: parse maxInstallmentMonths
      final maxMonths = (int.tryParse(_maxInstallmentMonthsCtrl.text) ??
              AppConstants.defaultMaxInstallmentMonths)
          .clamp(1, 120);
      final companyPct = (double.tryParse(_companyPercentageCtrl.text) ?? 0).clamp(0.0, 100.0);
      final product = InstallmentProduct(
        id: widget.product?.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        imagePath: _imagePaths.isNotEmpty ? _imagePaths.first : null,
        imagePaths: _imagePaths,
        purchasePrice: double.tryParse(_purchasePriceCtrl.text) ?? 0,
        salePrice: salePrice,
        cashPrice: cashPrice,
        installmentPrice: installmentPrice,
        showCashPrice: _showCashPrice,
        showInstallmentPrice: _showInstallmentPrice,
        isAvailable: _available,
        category: _selectedCategory,
        priceTier: _storeType == AppConstants.storeElectrical ? _priceTier : null,
        storeType: _storeType,
        maxInstallmentMonths: maxMonths,
        createdAt: widget.product?.createdAt ?? now,
        companyPercentage: companyPct,
      );
      final imgDao = ProductImageDao();
      final int savedId;
      if (widget.product == null) {
        savedId = await widget.dao.insert(product);
      } else {
        await widget.dao.update(product);
        savedId = widget.product!.id!;
      }
      // Persist all images to product_images table
      await imgDao.deleteAllForProduct(_storeType, savedId);
      final now2 = DateTime.now().toIso8601String();
      for (int i = 0; i < _imagePaths.length; i++) {
        await imgDao.insert(ProductImage(
          productType: _storeType,
          productId: savedId,
          imagePath: _imagePaths[i],
          sortOrder: i,
          createdAt: now2,
        ));
      }
      await _syncProductGroupAssignments(savedId, product.name, product.effectiveCashPrice);
      await _saveRateSettings();
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.product == null ? 'تم إضافة المنتج بنجاح ✓' : 'تم تحديث المنتج بنجاح ✓'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Import from inventory / section ────────────────────────────────────────
  Future<void> _importFromInventory(BuildContext context) async {
    // Show ALL products from ALL sections AND warehouse items.
    List<Map<String, dynamic>> allItems;
    try {
      // Always load warehouse items from all categories
      final itemDao = ItemDao();
      final warehouseItems = await itemDao.getAll();
      // Also load all section products from all store types
      final sectionProducts = await InstallmentProductDao()
          .getAll(availableOnly: false);

      allItems = [
        ...warehouseItems.map((item) => {
          'name': item.name,
          'category': item.category ?? '',
          'retail': item.priceRetail,
          'cost': item.purchasePrice,
          'quantity': item.quantity,
          'barcode': item.barcode,
        }),
        ...sectionProducts.map((p) => {
          'name': p.name,
          'category': p.category ?? '',
          'retail': p.salePrice > 0 ? p.salePrice : (p.cashPrice ?? 0),
          'cost': p.purchasePrice,
          'quantity': null,
          'barcode': null,
        }),
      ];
      // Remove duplicates by name (warehouse items take priority)
      final seen = <String>{};
      allItems = allItems.where((i) => seen.add(i['name'] as String? ?? '')).toList();
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(allItems);

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text('استيراد من المخزن والأقسام',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن منتج...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                  onChanged: (q) {
                    setS(() {
                      filtered = allItems.where((i) {
                        final name = (i['name'] as String? ?? '').toLowerCase();
                        final barcode = (i['barcode'] as String? ?? '');
                        return name.contains(q.toLowerCase()) || barcode.contains(q);
                      }).toList();
                    });
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx2, i) {
                    final item = filtered[i];
                    final retail = (item['retail'] as num?)?.toDouble() ?? 0.0;
                    final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x1A009688),
                        child: Icon(Icons.inventory_2_outlined, color: Colors.teal, size: 18),
                      ),
                      title: Text(item['name'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text(
                        [
                          if ((item['category'] as String?) != null) item['category'] as String,
                          if (retail > 0) 'سعر: ${retail.toStringAsFixed(0)} ج.م',
                          if (qty > 0) 'كمية: ${qty.toStringAsFixed(0)}',
                        ].join(' | '),
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => Navigator.pop(ctx, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _nameCtrl.text = selected['name'] as String? ?? '';
        final retail = (selected['retail'] as num?)?.toDouble() ?? 0.0;
        final cost = (selected['cost'] as num?)?.toDouble() ?? 0.0;
        if (retail > 0) {
          _salePriceCtrl.text = retail.toStringAsFixed(0);
          _cashPriceCtrl.text = retail.toStringAsFixed(0);
        }
        if (cost > 0) {
          _purchasePriceCtrl.text = cost.toStringAsFixed(0);
        }
        if ((selected['category'] as String?) != null) {
          _selectedCategory = selected['category'] as String;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم استيراد بيانات "${selected['name']}" بنجاح'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'إضافة منتج' : 'تعديل المنتج'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ─── Images Section ─────────────────────────────────────────────
            const Text('الصور (يمكن إضافة أكثر من صورة)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: Row(children: [
                GestureDetector(
                  onTap: _pickSingleImage,
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey.shade100,
                    ),
                    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate, color: Colors.teal, size: 32),
                      Text('إضافة صورة', style: TextStyle(fontSize: 10, color: Colors.teal)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagePaths.length,
                    itemBuilder: (_, i) => Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 90, height: 90,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                          clipBehavior: Clip.antiAlias,
                          child: File(_imagePaths[i]).existsSync()
                              ? Image.file(File(_imagePaths[i]), fit: BoxFit.cover)
                              : Container(color: Colors.grey.shade200, child: const Icon(Icons.image, color: Colors.grey)),
                        ),
                        Positioned(
                          top: 2, right: 10,
                          child: GestureDetector(
                            onTap: () => setState(() => _imagePaths.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ─── Import from inventory ──────────────────────────────────────
            if (widget.product == null) ...[
              OutlinedButton.icon(
                onPressed: () => _importFromInventory(context),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('استيراد من المخزن'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ─── Name & Description ─────────────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المنتج *', prefixIcon: Icon(Icons.inventory_2)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'الوصف (اختياري)', prefixIcon: Icon(Icons.description)),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // ─── Store Type ──────────────────────────────────────────────────
            if (widget.initialStoreType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.store, color: Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('القسم', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      widget.departmentName ?? AppConstants.storeLabels[widget.initialStoreType] ?? widget.initialStoreType!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ]),
                ]),
              )
            else
              DropdownButtonFormField<String>(
                value: _storeType,
                decoration: const InputDecoration(labelText: 'قسم المنتج', prefixIcon: Icon(Icons.store)),
                items: const [
                  DropdownMenuItem(value: 'installment', child: Text('نظام التقسيط')),
                  DropdownMenuItem(value: 'electrical', child: Text('الأدوات الكهربائية')),
                  DropdownMenuItem(value: 'clothing', child: Text('الملابس')),
                  DropdownMenuItem(value: 'mobiles', child: Text('الموبايلات')),
                  DropdownMenuItem(value: 'accessories', child: Text('الإكسسوارات')),
                ],
                onChanged: (v) => setState(() { _storeType = v!; _selectedCategory = null; }),
              ),
            const SizedBox(height: 12),

            // ─── Price Tier (electrical only) ────────────────────────────
            if (_storeType == AppConstants.storeElectrical) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _priceTier,
                decoration: const InputDecoration(
                  labelText: 'شريحة السعر',
                  prefixIcon: Icon(Icons.sell, color: Colors.teal),
                  helperText: 'العميل يرى المنتجات المخصصة لشريحة سعره فقط',
                ),
                items: const [
                  DropdownMenuItem(value: 'wholesale', child: Text('جملة')),
                  DropdownMenuItem(value: 'semi_wholesale', child: Text('نص جملة')),
                  DropdownMenuItem(value: 'retail', child: Text('قطاعي')),
                ],
                onChanged: (v) => setState(() => _priceTier = v ?? 'retail'),
              ),
              const SizedBox(height: 12),
            ],

            // ─── Category ───────────────────────────────────────────────────
            DropdownButtonFormField<String?> (
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'الفئة', prefixIcon: Icon(Icons.category)),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('بدون فئة')),
                ...widget.groups
                    .where((g) => g.storeType == null || g.storeType == _storeType)
                    .map((g) => DropdownMenuItem<String?>(value: g.name, child: Text(g.name))),
              ],
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
            const SizedBox(height: 12),
            if (_partnerGroups.isNotEmpty) ...[
              const Text('تعيين المنتج للمجموعات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              if (_loadingPartnerGroups)
                const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _partnerGroups.map((group) {
                    final selected = _selectedGroupIds.contains(group.id);
                    return FilterChip(
                      label: Text(group.name),
                      selected: selected,
                      onSelected: (enabled) {
                        setState(() {
                          if (enabled) {
                            _selectedGroupIds.add(group.id!);
                          } else {
                            _selectedGroupIds.remove(group.id!);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
            ],

            // ─── Prices ─────────────────────────────────────────────────────
            const Text('الأسعار', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _purchasePriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'سعر الشراء', prefixIcon: Icon(Icons.shopping_cart)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _salePriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'سعر البيع العام', prefixIcon: Icon(Icons.sell)),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ─── Cash Price ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('سعر الكاش', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                  Row(children: [
                    const Text('إظهار للعميل', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: _showCashPrice,
                      onChanged: (v) => setState(() => _showCashPrice = v),
                      activeColor: Colors.green,
                    ),
                  ]),
                ]),
                TextFormField(
                  controller: _cashPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'اتركه فارغاً لاستخدام سعر البيع العام',
                    prefixIcon: Icon(Icons.payments, color: Colors.green),
                  ),
                ),
                if (!_showCashPrice)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('⚠️ سعر الكاش مخفي عن العملاء', style: TextStyle(color: Colors.orange, fontSize: 12)),
                  ),
              ]),
            ),
            const SizedBox(height: 12),

            // ─── Installment Price (hidden for electrical) ───────────────
            if (_storeType != AppConstants.storeElectrical) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('سعر التقسيط الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14)),
                    Row(children: [
                      const Text('إظهار للعميل', style: TextStyle(fontSize: 12)),
                      Switch(
                        value: _showInstallmentPrice,
                        onChanged: (v) => setState(() => _showInstallmentPrice = v),
                        activeColor: Colors.blue,
                      ),
                    ]),
                  ]),
                  TextFormField(
                    controller: _installmentPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'اتركه فارغاً لحساب تلقائي بالربح',
                      prefixIcon: Icon(Icons.payment, color: Colors.blue),
                    ),
                  ),
                  if (!_showInstallmentPrice)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('⚠️ سعر التقسيط مخفي عن العملاء', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ),
                ]),
              ),
              const SizedBox(height: 16),

              // ─── Feature 5: Max Installment Months ────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(AppColors.installmentInt).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(AppColors.installmentInt).withValues(alpha: 0.25)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Row(children: [
                    Icon(Icons.calendar_month,
                        color: Color(AppColors.installmentInt), size: 16),
                    SizedBox(width: 6),
                    Text('حد التقسيط الأقصى',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(AppColors.installmentInt),
                            fontSize: 14)),
                  ]),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _maxInstallmentMonthsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'أقصى عدد أشهر تقسيط',
                      prefixIcon: const Icon(Icons.calendar_today,
                          color: Color(AppColors.installmentInt)),
                      helperText:
                          'العميل سيختار من 1 إلى هذه القيمة (الافتراضي: ${AppConstants.defaultMaxInstallmentMonths})',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 120) {
                        return 'أدخل قيمة بين 1 و 120';
                      }
                      return null;
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ─── Company Percentage ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.business_center, color: Colors.orange, size: 16),
                    SizedBox(width: 6),
                    Text('نسبة الشركة',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14)),
                  ]),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _companyPercentageCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'نسبة الشركة من كل عملية بيع/قسط (%)',
                      prefixIcon: Icon(Icons.percent, color: Colors.orange),
                      helperText: 'نسبة الشركة من كل عملية بيع أو قسط (مثال: 5 تعني 5%)',
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n < 0 || n > 100) return 'أدخل قيمة بين 0 و 100';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Monthly Installment Rate (Global Setting) ─────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(AppColors.installmentInt).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(AppColors.installmentInt).withValues(alpha: 0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.percent, color: Color(AppColors.installmentInt), size: 16),
                  SizedBox(width: 6),
                  Text('النسبة الشهرية للتقسيط (عامة)',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: Color(AppColors.installmentInt), fontSize: 14)),
                ]),
                const SizedBox(height: 8),
                if (_loadingRateSettings)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextFormField(
                    controller: _monthlyRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'النسبة الشهرية (%)',
                      suffixText: '%/شهر',
                      prefixIcon: Icon(Icons.percent, color: Color(AppColors.installmentInt)),
                      helperText: 'تُطبق على جميع المنتجات — مثال: 2.5 تعني 2.5% شهرياً',
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 16),

            // ─── Visibility ─────────────────────────────────────────────────
            SwitchListTile(
              title: const Text('إظهار المنتج للعملاء'),
              subtitle: const Text('إيقاف هذا يخفي المنتج من قائمة العملاء'),
              value: _available,
              onChanged: (v) => setState(() => _available = v),
              activeColor: Colors.green,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                label: Text(widget.product == null ? 'إضافة المنتج' : 'حفظ التعديلات'),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}

// ─── Store Filter Chip Widget ─────────────────────────────────────────────────
class _StoreFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StoreFilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: selected ? color : Colors.grey),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? color : Colors.grey,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ]),
      ),
    );
  }
}
