import 'dart:async';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../../providers/sales_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/installment_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/item.dart';
import '../../../models/customer.dart';
import '../../../models/department.dart';
import '../../../models/installment_product.dart';
import '../../../database/daos/department_dao.dart';
import '../../../database/daos/installment_product_dao.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/pdf_helper.dart';
import '../../widgets/barcode_scanner_screen.dart';
import '../customers/customer_points_screen.dart';

class SalesInvoiceScreen extends StatefulWidget {
  const SalesInvoiceScreen({super.key});

  @override
  State<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen> {
  final _barcodeCtrl = TextEditingController();
  final _productSearchCtrl = TextEditingController();
  final _manualPointsCtrl = TextEditingController(text: '0');
  String _productQuery = '';
  List<Customer> _selectedCustomers = [];
  List<Customer> _selectedTechnicians = [];
  double _invoiceDiscount = 0;
  List<Customer> _technicians = [];
  List<InstallmentProduct> _storeProducts = [];
  String _productSource = 'inventory'; // 'inventory' | 'store'
  String _paymentType = AppConstants.paymentCash;
  String _selectedPriceType = AppConstants.priceRetail;
  String _selectedDepartmentFilter = 'all';
  List<Department> _departments = [];
  int _installmentMonths = 6;
  double _amountPaid = 0;
  bool _saving = false;
  Timer? _autoSaveTimer;
  String? _draftKey;
  bool _draftSaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<InventoryProvider>().loadAll();
      context.read<SalesProvider>().clearCart();
      _draftKey = 'invoice_draft_${DateTime.now().millisecondsSinceEpoch}';
      _startAutoSave();
      _loadTechnicians();
      _loadStoreProducts();
      _loadDepartments();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _barcodeCtrl.dispose();
    _productSearchCtrl.dispose();
    _manualPointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStoreProducts() async {
    try {
      final dao = InstallmentProductDao();
      // availableOnly: true — exclude products marked is_available = false
      final products = await dao.getAll(availableOnly: true);
      if (mounted) setState(() => _storeProducts = products);
    } catch (_) {}
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await DepartmentDao().getAll(activeOnly: true);
      if (!mounted) return;
      setState(() => _departments = _mergeDepartments(depts));
    } catch (_) {}
  }

  List<Department> _mergeDepartments(List<Department> remote) {
    final merged = <String, Department>{};

    for (final dept in remote) {
      final key = _normalizeStoreType(dept.storeType);
      if (key.isEmpty) continue;
      merged[key] = dept.copyWith(storeType: key);
    }

    for (final storeType in const ['electrical', 'installment', 'clothing', 'mobiles', 'accessories']) {
      merged.putIfAbsent(storeType, () => Department(
        name: _storeTypeLabel(storeType),
        storeType: storeType,
        isActive: true,
        isSystem: true,
        createdAt: DateTime.now().toIso8601String(),
      ));
    }

    return merged.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<String> _orderedItemSectionKeys(List<Item> items) {
    final seen = <String>{};
    final keys = <String>[];
    for (final item in items) {
      final storeType = _normalizeStoreType(item.storeType);
      if (storeType.isEmpty) continue;
      if (seen.add(storeType)) {
        keys.add(storeType);
      }
    }

    if (keys.isEmpty) {
      if (items.any((item) => _normalizeStoreType(item.storeType).isEmpty)) {
        return ['other'];
      }
      return const [];
    }

    final ordered = <String>[];
    for (final dept in _departments) {
      final normalizedDept = _normalizeStoreType(dept.storeType);
      if (normalizedDept.isNotEmpty && keys.contains(normalizedDept)) {
        ordered.add(normalizedDept);
      }
    }

    for (final key in keys) {
      if (!ordered.contains(key)) {
        ordered.add(key);
      }
    }

    if (items.any((item) => _normalizeStoreType(item.storeType).isEmpty)) {
      ordered.add('other');
    }

    return ordered;
  }

  List<String> _orderedStoreProductSectionKeys(List<InstallmentProduct> products) {
    final seen = <String>{};
    final keys = <String>[];
    for (final product in products) {
      final storeType = _normalizeStoreType(product.storeType);
      if (storeType.isEmpty) continue;
      if (seen.add(storeType)) {
        keys.add(storeType);
      }
    }

    if (keys.isEmpty) {
      if (products.any((product) => _normalizeStoreType(product.storeType).isEmpty)) {
        return ['other'];
      }
      return const [];
    }

    final ordered = <String>[];
    for (final dept in _departments) {
      final normalizedDept = _normalizeStoreType(dept.storeType);
      if (normalizedDept.isNotEmpty && keys.contains(normalizedDept)) {
        ordered.add(normalizedDept);
      }
    }

    for (final key in keys) {
      if (!ordered.contains(key)) {
        ordered.add(key);
      }
    }

    if (products.any((product) => _normalizeStoreType(product.storeType).isEmpty)) {
      ordered.add('other');
    }

    return ordered;
  }

  String _sectionTitle(String key) {
    final normalizedKey = _normalizeStoreType(key);
    if (normalizedKey.isEmpty || normalizedKey == 'other') return 'أخرى';
    return _departmentLabel(normalizedKey);
  }

  String _departmentLabel(String storeType) {
    for (final dept in _departments) {
      if (_normalizeStoreType(dept.storeType) == storeType) {
        return dept.name;
      }
    }
    return _storeTypeLabel(storeType);
  }

  String _normalizeStoreType(String? value) => (value ?? '').trim().toLowerCase();

  /// Converts an InstallmentProduct → Item so it can be added to the cart.
  /// Uses a stable negative ID derived from the product's actual id,
  /// falling back to a hashCode-based value so no two products share id = 0.
  Item _toItem(InstallmentProduct p) {
    final stableId = p.id != null ? -(p.id!) : -(p.name.hashCode.abs() + 1000000);
    return Item(
        id: stableId,
        name: p.name,
        priceRetail: p.effectiveCashPrice,
        priceWholesale: p.effectiveCashPrice,
        priceSemiWholesale: p.effectiveCashPrice,
        priceSpecial: p.effectiveCashPrice,
        purchasePrice: p.purchasePrice,
        quantity: 9999,
        storeType: p.storeType,
        imagePath: p.imagePaths.isNotEmpty ? p.imagePaths.first : p.imagePath,
        category: p.category,
        createdAt: p.createdAt,
      );
  }

  Future<void> _loadTechnicians() async {
    try {
      final all = await context.read<CustomerProvider>().getAll();
      final techs = all
          .where((c) => c.customerType == AppConstants.customerTypeTechnician)
          .toList();
      if (mounted) setState(() => _technicians = techs);
    } catch (_) {}
  }

  static String _storeTypeLabel(String storeType) {
    switch (storeType) {
      case 'electrical': return 'كهربائي';
      case 'installment': return 'تقسيط';
      case 'clothing': return 'ملابس';
      case 'mobiles': return 'موبايلات';
      case 'accessories': return 'إكسسوارات';
      default: return storeType;
    }
  }

  static Color _storeTypeColor(String storeType) {
    switch (storeType) {
      case 'electrical': return Colors.indigo;
      case 'installment': return Colors.orange.shade700;
      case 'clothing': return Colors.pink.shade600;
      case 'mobiles': return Colors.blue.shade700;
      case 'accessories': return Colors.purple;
      default: return Colors.grey.shade600;
    }
  }

  // ── Auto Save ──────────────────────────────────────────────────────────────
  void _startAutoSave() {
    _autoSaveTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _autoSave());
  }

  Future<void> _autoSave() async {
    final sales = context.read<SalesProvider>();
    if (sales.cart.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = {
        'customer_id': _selectedCustomers.isNotEmpty ? _selectedCustomers.first.id : null,
        'customer_name': _selectedCustomers.isNotEmpty ? _selectedCustomers.first.name : null,
        'payment_type': _paymentType,
        'installment_months': _installmentMonths,
        'item_count': sales.cart.length,
        'saved_at': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_draftKey ?? 'invoice_draft', draft.toString());
      if (mounted) setState(() => _draftSaved = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _draftSaved = false);
      });
    } catch (_) {}
  }

  Future<void> _scanBarcode() async {
    final query = _barcodeCtrl.text.trim();
    if (query.isEmpty) return;
    await _lookupAndAdd(query);
  }

  Future<void> _openCameraScanner() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scanned != null && scanned.isNotEmpty && mounted) {
      _barcodeCtrl.text = scanned;
      await _lookupAndAdd(scanned);
    }
  }

  Future<void> _lookupAndAdd(String code) async {
    final item = await context.read<InventoryProvider>().getByBarcode(code);
    if (item != null && mounted) {
      context.read<SalesProvider>().addItem(
            item,
            priceType: _selectedPriceType,
          );
      _barcodeCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة ${item.name}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } else if (mounted) {
      final created = await _showCreateItemDialog(barcode: code);
      if (created != null && mounted) {
        context.read<SalesProvider>().addItem(
              created,
              priceType: _selectedPriceType,
            );
        _barcodeCtrl.clear();
      }
    }
  }

  Future<Item?> _showCreateItemDialog({String barcode = ''}) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final barcodeCtrl = TextEditingController(text: barcode);
    return showDialog<Item>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة منتج جديد للسيستم'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم المنتج *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: barcodeCtrl,
              decoration: const InputDecoration(
                  labelText: 'باركود', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'سعر الشراء', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'سعر البيع *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'الكمية', border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (name.isEmpty || price <= 0) return;
              final newItem = Item(
                name: name,
                barcode: barcodeCtrl.text.trim().isEmpty
                    ? null
                    : barcodeCtrl.text.trim(),
                purchasePrice: double.tryParse(costCtrl.text) ?? 0,
                priceRetail: price,
                quantity: double.tryParse(qtyCtrl.text) ?? 1,
                storeType: 'electrical',
                createdAt: DateTime.now().toIso8601String(),
              );
              final id =
                  await context.read<InventoryProvider>().addItem(newItem);
              final saved = newItem.copyWith(id: id);
              if (ctx.mounted) Navigator.pop(ctx, saved);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCustomer() async {
    final customers = await context.read<CustomerProvider>().getAll();
    if (!mounted) return;
    final selected = await showSearch<Customer?>(
      context: context,
      delegate: _CustomerSearchDelegate(customers),
    );
    if (selected != null &&
        !_selectedCustomers.any((c) => c.id == selected.id)) {
      setState(() {
        _selectedCustomers.add(selected);
        if ((selected.priceType ?? '').isNotEmpty) {
          _selectedPriceType = selected.priceType!;
        }
      });
      if (_selectedCustomers.length == 1) {
        context.read<SalesProvider>().setCustomer(selected.id);
      }
    }
  }

  Future<void> _selectTechnician() async {
    if (_technicians.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('اختر فني',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _technicians.map((t) {
                final alreadySelected =
                    _selectedTechnicians.any((s) => s.id == t.id);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: const Icon(Icons.engineering,
                        color: Colors.teal, size: 18),
                  ),
                  title: Text(t.name),
                  subtitle: t.phone != null ? Text(t.phone!) : null,
                  trailing: alreadySelected
                      ? const Icon(Icons.check_circle, color: Colors.teal)
                      : null,
                  onTap: () {
                    if (!alreadySelected) {
                      setState(() => _selectedTechnicians.add(t));
                    }
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _printInvoice(SalesProvider sales) async {
    if (sales.cart.isEmpty) return;
    final items = sales.cart
        .map((c) => {
              'name': c.item.name,
              'qty': c.qty,
              'price': AppFormatters.formatCurrency(c.unitPrice),
              'total': AppFormatters.formatCurrency(c.total),
            })
        .toList();
    final bytes = await PdfHelper.generateInvoicePdf(
      invoiceNo: DateTime.now().millisecondsSinceEpoch.toString().substring(7),
      date: AppFormatters.formatDateTime(DateTime.now()),
      customerName: _selectedCustomers.isNotEmpty
          ? _selectedCustomers.map((c) => c.name).join('، ')
          : 'عميل غير محدد',
      paymentType: _paymentType == AppConstants.paymentCash
          ? 'نقدي'
          : _paymentType == AppConstants.paymentInstallment
              ? 'تقسيط'
              : 'دفع جزئي',
      items: items,
      subtotal: sales.subtotal,
      discount: sales.totalDiscount,
      total: sales.total,
      paid:
          _paymentType == AppConstants.paymentCash ? sales.total : _amountPaid,
      remaining: _paymentType == AppConstants.paymentCash
          ? 0
          : sales.total - _amountPaid,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name:
          'فاتورة - ${_selectedCustomers.isNotEmpty ? _selectedCustomers.first.name : 'عميل'}.pdf',
    );
  }

  void _openPointsScreen() {
    final recipient = _selectedCustomers.isNotEmpty
        ? _selectedCustomers.first
        : _selectedTechnicians.isNotEmpty
            ? _selectedTechnicians.first
            : null;

    if (recipient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر عميل أو فني أولاً لعرض نقاطه'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerPointsScreen(customer: recipient),
      ),
    );
  }

  Future<void> _saveInvoice() async {
    final sales = context.read<SalesProvider>();
    if (sales.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف منتجات أولاً')),
      );
      return;
    }
    if (_paymentType == AppConstants.paymentInstallment &&
        _selectedCustomers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تحديد العميل للتقسيط')),
      );
      return;
    }

    final manualPoints = int.tryParse(_manualPointsCtrl.text.trim()) ?? 0;
    final recipients = [..._selectedCustomers, ..._selectedTechnicians];

    if (manualPoints < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن أن تكون نقاط الولاء سالبة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (manualPoints > 0 && recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر عميل أو فني واحد على الأقل قبل إدخال النقاط'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final double paid =
          _paymentType == AppConstants.paymentCash ? sales.total : _amountPaid;
      final id = await sales.saveInvoice(
        paymentType: _paymentType,
        amountPaid: paid,
        treasuryId: 1,
      );
      if (_paymentType == AppConstants.paymentInstallment &&
          mounted &&
          _selectedCustomers.isNotEmpty) {
        final totalCost = sales.cart.fold(0.0, (s, i) => s + i.costTotal);
        await context.read<InstallmentProvider>().createInstallment(
              customerId: _selectedCustomers.first.id!,
              productName: 'فاتورة #$id',
              purchasePrice: totalCost,
              salePrice: sales.total,
              numInstallments: _installmentMonths,
              downPayment: paid,
              invoiceId: id,
            );
      }

      String? pointsError;
      int totalPointsLogged = 0;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final invoiceLabel = 'INV-$id';

      for (final recipient in recipients) {
        if (recipient.id == null || manualPoints <= 0) continue;
        try {
          await context.read<CustomerProvider>().logPointsForInvoice(
            customerId: recipient.id!,
            invoiceId: id,
            invoiceNo: invoiceLabel,
            date: today,
            pointsEarned: manualPoints,
            pointValue: 1.0,
            pointCurrency: 'piasters',
          );
          totalPointsLogged += manualPoints;
        } catch (e) {
          pointsError = (pointsError == null ? '' : '$pointsError\n') +
              '${recipient.name}: $e';
        }
      }

      if (mounted) {
        await context.read<CustomerProvider>().loadAll();
        setState(() => _saving = false);

        if (pointsError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم حفظ الفاتورة #$id ✓\n⚠️ فشل تسجيل بعض النقاط:\n$pointsError',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 8),
            ),
          );
          Navigator.pop(context);
          return;
        }

        if (totalPointsLogged == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حفظ الفاتورة #$id ✓',
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
          return;
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text('تم حفظ الفاتورة #$id',
                    style: const TextStyle(fontSize: 16)),
              ),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.stars_rounded,
                      color: Colors.amber.shade700, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+$totalPointsLogged نقطة',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          Text(
                            recipients.length == 1
                                ? 'لـ ${recipients.first.name}'
                                : 'موزعة على ${recipients.length} عملاء/فنيين',
                            style: TextStyle(
                                fontSize: 12, color: Colors.amber.shade700),
                          ),
                        ]),
                  ),
                ]),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.pop(context);
                },
                child: const Text('إغلاق'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.stars_rounded, size: 18),
                label: Text('نقاط ${recipients.first.name}'),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CustomerPointsScreen(customer: recipients.first),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Opens the product picker as a bottom sheet (used on mobile)
  Future<void> _showProductPickerSheet() async {
    await Future.wait([
      context.read<InventoryProvider>().loadAll(),
      _loadStoreProducts(),
      _loadDepartments(),
    ]);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.6,
          maxChildSize: 0.96,
          builder: (_, controller) => _ProductPickerSheet(
            items: context.watch<InventoryProvider>().items,
            scrollController: controller,
            storeProducts: _storeProducts,
            departments: _departments,
            priceType: _selectedPriceType,
            onAdd: (item) {
              context.read<SalesProvider>().addItem(item, priceType: _selectedPriceType);
            },
            toItem: _toItem,
            storeTypeLabel: _storeTypeLabel,
            storeTypeColor: _storeTypeColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(sales, isMobile),
      body: isMobile
          ? _buildMobileBody(sales, dateStr)
          : _buildTabletBody(sales, dateStr),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              onPressed: _showProductPickerSheet,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('اختر منتج'),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(SalesProvider sales, bool isMobile) {
    return AppBar(
      backgroundColor: const Color(AppColors.primaryInt),
      foregroundColor: Colors.white,
      titleSpacing: 8,
      title: isMobile
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('فاتورة مبيعات',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                _buildPaymentDropdown(),
              ],
            )
          : Row(children: [
              const Text('فاتورة مبيعات',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              _buildPaymentDropdown(),
            ]),
      actions: [
        if (!isMobile)
          TextButton.icon(
            onPressed: () {
              context.read<SalesProvider>().clearCart();
              setState(() {
                _selectedCustomers = [];
                _selectedTechnicians = [];
                _paymentType = AppConstants.paymentCash;
                _amountPaid = 0;
                _invoiceDiscount = 0;
                _barcodeCtrl.clear();
                _manualPointsCtrl.text = '0';
              });
            },
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('+ جديدة',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          )
        else
          IconButton(
            tooltip: 'فاتورة جديدة',
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () {
              context.read<SalesProvider>().clearCart();
              setState(() {
                _selectedCustomers = [];
                _selectedTechnicians = [];
                _paymentType = AppConstants.paymentCash;
                _selectedPriceType = AppConstants.priceRetail;
                _selectedDepartmentFilter = 'all';
                _amountPaid = 0;
                _invoiceDiscount = 0;
                _barcodeCtrl.clear();
                _manualPointsCtrl.text = '0';
              });
            },
          ),
        IconButton(
          tooltip: 'عرض النقاط',
          icon: const Icon(Icons.stars, color: Colors.white),
          onPressed: (_selectedCustomers.isEmpty && _selectedTechnicians.isEmpty)
              ? null
              : _openPointsScreen,
        ),
        IconButton(
          tooltip: 'طباعة',
          icon: const Icon(Icons.print, color: Colors.white),
          onPressed: sales.cart.isEmpty ? null : () => _printInvoice(sales),
        ),
        TextButton.icon(
          onPressed: _saving ? null : _saveInvoice,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save, color: Colors.white, size: 18),
          label: const Text('حفظ',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildPaymentDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _paymentType,
          dropdownColor: const Color(AppColors.primaryInt),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          iconEnabledColor: Colors.white,
          isDense: true,
          items: const [
            DropdownMenuItem(
                value: AppConstants.paymentCash, child: Text('نقدي')),
            DropdownMenuItem(
                value: AppConstants.paymentInstallment,
                child: Text('تقسيط')),
            DropdownMenuItem(
                value: AppConstants.paymentPartial, child: Text('جزئي')),
          ],
          onChanged: (v) =>
              setState(() => _paymentType = v ?? _paymentType),
        ),
      ),
    );
  }

  Widget _buildPriceTypeSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedPriceType,
      isDense: true,
      decoration: const InputDecoration(
        labelText: 'نوع السعر',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        filled: true,
        fillColor: Colors.white,
      ),
      items: const [
        DropdownMenuItem(value: AppConstants.priceRetail, child: Text('قطاعي')),
        DropdownMenuItem(value: AppConstants.priceSemiWholesale, child: Text('نصف جملة')),
        DropdownMenuItem(value: AppConstants.priceWholesale, child: Text('جملة')),
        DropdownMenuItem(value: AppConstants.priceSpecial, child: Text('خاص')),
      ],
      onChanged: (v) => setState(() => _selectedPriceType = v ?? _selectedPriceType),
    );
  }

  Widget _buildDepartmentFilterDropdown({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isDense: true,
      decoration: const InputDecoration(
        labelText: 'القسم',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('كل الأقسام')),
        ..._departments.map((d) => DropdownMenuItem(
              value: _normalizeStoreType(d.storeType),
              child: Text(d.name),
            )),
      ],
      onChanged: (v) => onChanged(_normalizeStoreType(v)),
    );
  }

  // ── MOBILE BODY ─────────────────────────────────────────────────────────────
  Widget _buildMobileBody(SalesProvider sales, String dateStr) {
    final screenHeight = MediaQuery.of(context).size.height;
    final pickerHeight = (screenHeight * 0.3).clamp(220.0, 420.0);

    return Column(
      children: [
        // ── Scrollable top section: invoice info + customer ──────────────────
        Flexible(
          flex: 1,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              children: [
                // Invoice data card
                _buildInvoiceDataCard(sales, dateStr, compact: true),
                // Customer card
                _buildCustomerCard(sales, compact: true),
                // Technicians row
                _buildTechniciansRow(sales),
                // Points
                if (_selectedCustomers.isNotEmpty ||
                    _selectedTechnicians.isNotEmpty)
                  _buildPointsRow(sales),
                // Barcode scanner row
                _buildBarcodeScanRow(),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Product picker (visible on mobile) ───────────────────────────────
        SizedBox(
          height: pickerHeight,
          child: _buildInlineProductPicker(sales),
        ),

        const SizedBox(height: 8),

        // ── Cart list (expanded) ─────────────────────────────────────────────
        Expanded(
          child: sales.cart.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 52, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('اضغط على منتج من القائمة أعلاه لإضافة أصناف',
                        style: TextStyle(color: Colors.grey.shade400),
                        textAlign: TextAlign.center),
                  ]),
                )
              : _buildCartList(sales),
        ),

        // ── Bottom summary bar ───────────────────────────────────────────────
        _buildBottomBar(sales, isMobile: true),
      ],
    );
  }

  // ── TABLET / WIDE BODY ──────────────────────────────────────────────────────
  Widget _buildTabletBody(SalesProvider sales, String dateStr) {
    return Column(
      children: [
        // ── Invoice data + Customer data (two panels side by side) ───────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildInvoiceDataCard(sales, dateStr)),
              Expanded(child: _buildCustomerCard(sales)),
            ],
          ),
        ),

        // ── Technicians row ──────────────────────────────────────────────────
        _buildTechniciansRow(sales),

        // ── Points row ──────────────────────────────────────────────────────
        if (_selectedCustomers.isNotEmpty || _selectedTechnicians.isNotEmpty)
          _buildPointsRow(sales),

        // ── Split: Cart (left) + Product list (right) ────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cart items panel ─────────────────────────────────────────
              Expanded(
                flex: 3,
                child: sales.cart.isEmpty
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 52, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text('اختر منتجاً من القائمة على اليسار',
                              style: TextStyle(color: Colors.grey.shade400)),
                        ]),
                      )
                    : _buildCartList(sales),
              ),
              // ── Divider ──────────────────────────────────────────────────
              const VerticalDivider(width: 1, thickness: 1),
              // ── Inline product picker ─────────────────────────────────────
              Expanded(
                flex: 2,
                child: _buildInlineProductPicker(sales),
              ),
            ],
          ),
        ),

        // ── Bottom summary bar ───────────────────────────────────────────────
        _buildBottomBar(sales, isMobile: false),
      ],
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────────

  Widget _buildInvoiceDataCard(SalesProvider sales, String dateStr,
      {bool compact = false}) {
    return _SectionCard(
      title: 'بيانات الفاتورة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'التاريخ', value: dateStr),
          _InfoRow(
            label: 'الإجمالي',
            value: AppFormatters.formatCurrency(sales.total),
            bold: true,
            valueColor: const Color(AppColors.primaryInt),
          ),
          Row(children: [
            const Text('خصم:',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: _invoiceDiscount == 0
                    ? '0'
                    : _invoiceDiscount.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  border: OutlineInputBorder(),
                  suffixText: 'ج.م',
                ),
                style: const TextStyle(fontSize: 12),
                onChanged: (v) => setState(
                    () => _invoiceDiscount = double.tryParse(v) ?? 0),
              ),
            ),
          ]),
          if (_invoiceDiscount > 0) ...[
            const SizedBox(height: 2),
            _InfoRow(
              label: 'الصافي',
              value: AppFormatters.formatCurrency(
                  sales.total - _invoiceDiscount),
              bold: true,
              valueColor: Colors.green,
            ),
          ],
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: _buildPriceTypeSelector(),
          ),
          if (_paymentType != AppConstants.paymentCash) ...[
            _InfoRow(
              label: 'المدفوع',
              value: AppFormatters.formatCurrency(_amountPaid),
              valueColor: Colors.blue,
            ),
            _InfoRow(
              label: 'الباقي',
              value: AppFormatters.formatCurrency(sales.total - _amountPaid),
              valueColor: Colors.red,
            ),
          ],
          if (_paymentType == AppConstants.paymentInstallment) ...[
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              value: _installmentMonths,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'عدد الأشهر',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              items: [3, 6, 9, 12, 18, 24]
                  .map((m) => DropdownMenuItem(
                      value: m, child: Text('$m شهر')))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _installmentMonths = v);
              },
            ),
          ],
          if (_paymentType != AppConstants.paymentCash) ...[
            const SizedBox(height: 4),
            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ المدفوع / العربون',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                suffixText: 'ج.م',
              ),
              onChanged: (v) =>
                  setState(() => _amountPaid = double.tryParse(v) ?? 0),
            ),
          ],
          if (context.read<AuthProvider>().isAdmin && sales.cart.isNotEmpty) ...[
            const SizedBox(height: 4),
            Builder(builder: (ctx) {
              final cost =
                  sales.cart.fold(0.0, (s, i) => s + i.costTotal);
              final profit = sales.total - cost;
              return _InfoRow(
                label: 'هامش الربح',
                value:
                    '${AppFormatters.formatCurrency(profit)} (${sales.total > 0 ? (profit / sales.total * 100).toStringAsFixed(1) : 0}%)',
                valueColor: profit >= 0 ? Colors.green : Colors.red,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerCard(SalesProvider sales, {bool compact = false}) {
    return _SectionCard(
      title: 'العملاء',
      trailing: TextButton.icon(
        onPressed: _selectCustomer,
        style: TextButton.styleFrom(
            padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
        icon: const Icon(Icons.person_add, size: 14),
        label: const Text('إضافة', style: TextStyle(fontSize: 12)),
      ),
      child: _selectedCustomers.isEmpty
          ? Row(
              children: [
                Icon(Icons.person_outline,
                    size: 28, color: Colors.grey.shade300),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('لم يتم تحديد عميل',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 12)),
                ),
                TextButton(
                  onPressed: _selectCustomer,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 24)),
                  child: const Text('اختر', style: TextStyle(fontSize: 12)),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _selectedCustomers
                      .map((c) => Chip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            label: Text(c.name,
                                style: const TextStyle(fontSize: 11)),
                            deleteIcon:
                                const Icon(Icons.close, size: 14),
                            onDeleted: () => setState(() {
                              _selectedCustomers.remove(c);
                              if (_selectedCustomers.isNotEmpty) {
                                context
                                    .read<SalesProvider>()
                                    .setCustomer(
                                        _selectedCustomers.first.id);
                              } else {
                                context
                                    .read<SalesProvider>()
                                    .setCustomer(null);
                              }
                            }),
                            backgroundColor: Colors.amber.shade50,
                            side: BorderSide(color: Colors.amber.shade300),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                          ))
                      .toList(),
                ),
                if (_selectedCustomers.length == 1) ...[
                  const SizedBox(height: 4),
                  _InfoRow(
                    label: 'الرصيد',
                    value: AppFormatters.formatCurrency(
                        _selectedCustomers.first.balance),
                    valueColor:
                        _selectedCustomers.first.balance > 0
                            ? Colors.orange
                            : Colors.green,
                  ),
                  _InfoRow(
                    label: 'النقاط',
                    value: '${_selectedCustomers.first.points}',
                    valueColor: Colors.purple,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildTechniciansRow(SalesProvider sales) {
    return Container(
      color: Colors.teal.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        const Icon(Icons.engineering, color: Colors.teal, size: 18),
        const SizedBox(width: 6),
        const Text('الفنيون:',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.teal)),
        const SizedBox(width: 8),
        Expanded(
          child: _selectedTechnicians.isEmpty
              ? TextButton.icon(
                  onPressed: _selectTechnician,
                  icon:
                      const Icon(Icons.add, size: 14, color: Colors.teal),
                  label: const Text('إضافة فني',
                      style: TextStyle(fontSize: 12, color: Colors.teal)),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 24)),
                )
              : Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    ..._selectedTechnicians.map((t) => Chip(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text(t.name,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.teal)),
                          deleteIcon: const Icon(Icons.close,
                              size: 13, color: Colors.teal),
                          onDeleted: () => setState(
                              () => _selectedTechnicians.remove(t)),
                          backgroundColor: Colors.teal.shade50,
                          side:
                              BorderSide(color: Colors.teal.shade300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4),
                        )),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.teal, size: 18),
                      onPressed: _selectTechnician,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _buildPointsRow(SalesProvider sales) {
    final recipients = [..._selectedCustomers, ..._selectedTechnicians];
    final manualPoints = int.tryParse(_manualPointsCtrl.text.trim()) ?? 0;

    return Container(
      color: Colors.deepPurple.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.stars, color: Colors.deepPurple, size: 16),
            const SizedBox(width: 6),
            const Text('إدخال النقاط يدوياً',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple)),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: _manualPointsCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'عدد النقاط لكل مستلم',
              hintText: 'اكتب رقم النقاط',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              suffixText: 'نقطة',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (recipients.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: recipients.map((recipient) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.deepPurple.shade100),
                  ),
                  child: Text(
                    '${recipient.name}: ${manualPoints > 0 ? '+$manualPoints' : '0'} نقطة',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          if (recipients.isEmpty)
            Text(
              'اختر عميل أو فني لتفعيل إدخال النقاط',
              style: TextStyle(fontSize: 11, color: Colors.deepPurple.shade300),
            ),
        ],
      ),
    );
  }

  Widget _buildBarcodeScanRow() {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: _barcodeCtrl,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'باركود...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6)),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: (_) => _scanBarcode(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryInt),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: _scanBarcode,
            child: const Icon(Icons.search, size: 18),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: _openCameraScanner,
            child: const Icon(Icons.camera_alt, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _buildCartList(SalesProvider sales) {
    return Column(
      children: [
        // Cart header
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
                bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(children: [
            const SizedBox(
                width: 26,
                child: Text('#',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54),
                    textAlign: TextAlign.center)),
            const SizedBox(width: 6),
            const Expanded(
                flex: 3,
                child: Text('اسم الصنف',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54))),
            const SizedBox(width: 6),
            const SizedBox(
                width: 80,
                child: Text('الكمية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54))),
            const SizedBox(width: 6),
            const SizedBox(
                width: 65,
                child: Text('السعر',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54))),
            const SizedBox(width: 6),
            const SizedBox(
                width: 65,
                child: Text('الإجمالي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54))),
            const SizedBox(width: 4),
            const SizedBox(width: 26),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: sales.cart.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) => _CartItemRow(
              index: i,
              cartItem: sales.cart[i],
              technicianPoints: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineProductPicker(SalesProvider sales) {
    final priceType = _selectedPriceType;

    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            color: Colors.teal.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(children: [
              const Icon(Icons.storefront_outlined,
                  color: Colors.white, size: 15),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'اختر منتجاً',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              if (_storeProducts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _productSource == 'inventory'
                        ? '${context.watch<InventoryProvider>().items.length} صنف'
                        : '${_storeProducts.length} منتج',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
            ]),
          ),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _productSource = 'inventory'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _productSource == 'inventory'
                        ? Colors.teal.shade50
                        : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: _productSource == 'inventory'
                            ? Colors.teal
                            : Colors.grey.shade300,
                        width: _productSource == 'inventory' ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 13,
                          color: _productSource == 'inventory'
                              ? Colors.teal
                              : Colors.grey),
                      const SizedBox(width: 4),
                      Text('المخزن',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _productSource == 'inventory'
                                  ? Colors.teal
                                  : Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _productSource = 'store'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _productSource == 'store'
                        ? Colors.orange.shade50
                        : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: _productSource == 'store'
                            ? Colors.orange
                            : Colors.grey.shade300,
                        width: _productSource == 'store' ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_outlined,
                          size: 13,
                          color: _productSource == 'store'
                              ? Colors.orange.shade700
                              : Colors.grey),
                      const SizedBox(width: 4),
                      Text('كل المنتجات',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _productSource == 'store'
                                  ? Colors.orange.shade700
                                  : Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
            child: Column(children: [
              TextField(
                controller: _productSearchCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو الباركود...',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  suffixIcon: _productQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _productSearchCtrl.clear();
                            setState(() => _productQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _productQuery = v),
              ),
              const SizedBox(height: 6),
              _buildDepartmentFilterDropdown(
                value: _selectedDepartmentFilter,
                onChanged: (v) => setState(() => _selectedDepartmentFilter = _normalizeStoreType(v)),
              ),
            ]),
          ),
          Expanded(
            child: Builder(builder: (ctx) {
              if (_productSource == 'inventory') {
                final allItems = context.watch<InventoryProvider>().items;
                final filtered = allItems.where((i) {
                  final matchesQuery = _productQuery.isEmpty ||
                      i.name.contains(_productQuery) ||
                      (i.barcode?.contains(_productQuery) ?? false);
                  if (!matchesQuery) return false;
                  if (_selectedDepartmentFilter == 'all') return true;
                  return _normalizeStoreType(i.storeType) == _selectedDepartmentFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 36,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 6),
                        Text('لا توجد أصناف في المخزن',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ),
                  );
                }

                final grouped = <String, List<Item>>{};
                for (final item in filtered) {
                  final key = item.storeType.trim().isEmpty ? 'other' : item.storeType.trim();
                  grouped.putIfAbsent(key, () => []).add(item);
                }

                final orderedKeys = _orderedItemSectionKeys(filtered);

                return ListView(
                  children: [
                    for (final key in orderedKeys)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                            child: Text(
                              _sectionTitle(key),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey.shade700),
                            ),
                          ),
                          ...grouped[key]!.map((item) => _ProductPickerTile(
                                name: item.name,
                                subtitle: 'كمية: ${item.quantity.toStringAsFixed(0)}',
                                price: item.priceForType(priceType),
                                inCart: sales.cart.any((c) => c.item.id == item.id),
                                badgeColor: Colors.teal.shade700,
                                badgeLabel: 'مخزن',
                                onTap: () => context.read<SalesProvider>().addItem(
                                      item,
                                      priceType: priceType,
                                    ),
                              )),
                        ],
                      ),
                  ],
                );
              }

              final filtered = _storeProducts.where((p) {
                final matchesQuery = _productQuery.isEmpty ||
                    p.name.contains(_productQuery) ||
                    (p.category?.contains(_productQuery) ?? false);
                if (!matchesQuery) return false;
                if (_selectedDepartmentFilter == 'all') return true;
                return _normalizeStoreType(p.storeType) == _selectedDepartmentFilter;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_outlined,
                          size: 36,
                          color: Colors.grey.shade300),
                      const SizedBox(height: 6),
                      Text('لا توجد منتجات',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                );
              }

              final grouped = <String, List<InstallmentProduct>>{};
              for (final p in filtered) {
                final key = p.storeType.trim().isEmpty ? 'other' : p.storeType.trim();
                grouped.putIfAbsent(key, () => []).add(p);
              }

              final orderedKeys = _orderedStoreProductSectionKeys(filtered);

              return ListView(
                children: [
                  for (final key in orderedKeys)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                          child: Text(
                            _sectionTitle(key),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey.shade700),
                          ),
                        ),
                        ...grouped[key]!.map((p) {
                          final itemConverted = _toItem(p);
                          final inCart = sales.cart.any((c) => c.item.id == itemConverted.id);
                          return _ProductPickerTile(
                            name: p.name,
                            subtitle: p.category ?? '',
                            price: p.effectiveCashPrice,
                            inCart: inCart,
                            badgeColor: _storeTypeColor(p.storeType),
                            badgeLabel: _storeTypeLabel(p.storeType),
                            onTap: () => context.read<SalesProvider>().addItem(
                                  itemConverted,
                                  priceType: priceType,
                                ),
                          );
                        }),
                      ],
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(SalesProvider sales, {required bool isMobile}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(blurRadius: 8, color: Colors.black12)
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 16,
        vertical: isMobile ? 8 : 10,
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'الإجمالي: ${AppFormatters.formatCurrency(sales.total)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                        color: const Color(AppColors.primaryInt)),
                    overflow: TextOverflow.ellipsis),
                if (_paymentType != AppConstants.paymentCash)
                  Text(
                    'الباقي: ${AppFormatters.formatCurrency(sales.total - _amountPaid)}',
                    style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.red),
                    overflow: TextOverflow.ellipsis,
                  ),
              ]),
        ),
        const SizedBox(width: 8),
        if (_draftSaved)
          const Icon(Icons.cloud_done, color: Colors.green, size: 16),
        const SizedBox(width: 4),
        if (!isMobile)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade700,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed:
                sales.cart.isEmpty ? null : () => _printInvoice(sales),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('طباعة'),
          )
        else
          IconButton(
            icon: const Icon(Icons.print),
            color: Colors.blueGrey.shade700,
            onPressed:
                sales.cart.isEmpty ? null : () => _printInvoice(sales),
            tooltip: 'طباعة',
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
      ]),
    );
  }
}

// ─── Product picker bottom sheet (mobile) ─────────────────────────────────────
class _ProductPickerSheet extends StatefulWidget {
  final List<Item> items;
  final List<InstallmentProduct> storeProducts;
  final List<Department> departments;
  final ScrollController scrollController;
  final String priceType;
  final void Function(Item) onAdd;
  final Item Function(InstallmentProduct) toItem;
  final String Function(String) storeTypeLabel;
  final Color Function(String) storeTypeColor;

  const _ProductPickerSheet({
    required this.items,
    required this.storeProducts,
    required this.departments,
    required this.scrollController,
    required this.priceType,
    required this.onAdd,
    required this.toItem,
    required this.storeTypeLabel,
    required this.storeTypeColor,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';
  String _source = 'inventory';
  String _departmentFilter = 'all';

  String _normalizeStoreType(String? value) => (value ?? '').trim().toLowerCase();

  String _sectionTitle(String key) {
    final normalizedKey = _normalizeStoreType(key);
    if (normalizedKey.isEmpty || normalizedKey == 'other') return 'أخرى';
    for (final dept in widget.departments) {
      if (_normalizeStoreType(dept.storeType) == normalizedKey) {
        return dept.name;
      }
    }
    return key;
  }

  List<String> _orderedSectionKeys(Iterable<String> keys) {
    final unique = <String>[];
    final seen = <String>{};
    for (final key in keys) {
      final normalized = _normalizeStoreType(key);
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      unique.add(normalized);
    }

    final ordered = <String>[];
    for (final dept in widget.departments) {
      final normalizedDept = _normalizeStoreType(dept.storeType);
      if (normalizedDept.isNotEmpty && unique.contains(normalizedDept)) {
        ordered.add(normalizedDept);
      }
    }
    for (final key in unique) {
      if (!ordered.contains(key)) {
        ordered.add(key);
      }
    }
    if (unique.contains('')) ordered.add('other');
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              const Expanded(
                child: Text('اختر منتجاً',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _source = 'inventory'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _source == 'inventory'
                        ? Colors.teal.shade50
                        : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: _source == 'inventory'
                            ? Colors.teal
                            : Colors.grey.shade300,
                        width: _source == 'inventory' ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text('المخزن',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _source == 'inventory'
                                ? Colors.teal
                                : Colors.grey)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _source = 'store'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _source == 'store'
                        ? Colors.orange.shade50
                        : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: _source == 'store'
                            ? Colors.orange
                            : Colors.grey.shade300,
                        width: _source == 'store' ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text('كل المنتجات',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _source == 'store'
                                ? Colors.orange.shade700
                                : Colors.grey)),
                  ),
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _query = ''),
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _departmentFilter,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'القسم',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('كل الأقسام')),
                  ...widget.departments.map((d) => DropdownMenuItem(
                        value: _normalizeStoreType(d.storeType),
                        child: Text(d.name),
                      )),
                ],
                onChanged: (v) => setState(() => _departmentFilter = _normalizeStoreType(v)),
              ),
            ]),
          ),
          Expanded(
            child: Builder(builder: (_) {
              if (_source == 'inventory') {
                final filtered = widget.items.where((i) {
                  final matchesQuery = _query.isEmpty ||
                      i.name.contains(_query) ||
                      (i.barcode?.contains(_query) ?? false);
                  if (!matchesQuery) return false;
                  if (_departmentFilter == 'all') return true;
                  return _normalizeStoreType(i.storeType) == _departmentFilter;
                }).toList();

                final grouped = <String, List<Item>>{};
                for (final item in filtered) {
                  final key = _normalizeStoreType(item.storeType).isEmpty ? 'other' : _normalizeStoreType(item.storeType);
                  grouped.putIfAbsent(key, () => []).add(item);
                }

                final orderedKeys = _orderedSectionKeys(grouped.keys);

                return ListView(
                  controller: widget.scrollController,
                  children: [
                    for (final key in orderedKeys)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                            child: Text(
                              _sectionTitle(key),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey.shade700),
                            ),
                          ),
                          ...grouped[key]!.map((item) => _ProductPickerTile(
                                name: item.name,
                                subtitle: 'كمية: ${item.quantity.toStringAsFixed(0)}',
                                price: item.priceForType(widget.priceType),
                                inCart: sales.cart.any((c) => c.item.id == item.id),
                                badgeColor: Colors.teal.shade700,
                                badgeLabel: 'مخزن',
                                onTap: () => widget.onAdd(item),
                              )),
                        ],
                      ),
                  ],
                );
              }

              final filtered = widget.storeProducts.where((p) {
                final matchesQuery = _query.isEmpty ||
                    p.name.contains(_query) ||
                    (p.category?.contains(_query) ?? false);
                if (!matchesQuery) return false;
                if (_departmentFilter == 'all') return true;
                return _normalizeStoreType(p.storeType) == _departmentFilter;
              }).toList();

              final grouped = <String, List<InstallmentProduct>>{};
              for (final p in filtered) {
                final key = _normalizeStoreType(p.storeType).isEmpty ? 'other' : _normalizeStoreType(p.storeType);
                grouped.putIfAbsent(key, () => []).add(p);
              }

              final orderedKeys = _orderedSectionKeys(grouped.keys);

              return ListView(
                controller: widget.scrollController,
                children: [
                  for (final key in orderedKeys)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                          child: Text(
                            _sectionTitle(key),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey.shade700),
                          ),
                        ),
                        ...grouped[key]!.map((p) {
                          final itemConverted = widget.toItem(p);
                          return _ProductPickerTile(
                            name: p.name,
                            subtitle: p.category ?? '',
                            price: p.effectiveCashPrice,
                            inCart: sales.cart.any((c) => c.item.id == itemConverted.id),
                            badgeColor: widget.storeTypeColor(p.storeType),
                            badgeLabel: widget.storeTypeLabel(p.storeType),
                            onTap: () => widget.onAdd(itemConverted),
                          );
                        }),
                      ],
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable section card ────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(AppColors.primaryInt),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text('$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

// ─── Cart item row ────────────────────────────────────────────────────────────
class _CartItemRow extends StatelessWidget {
  final int index;
  final CartItem cartItem;
  final int technicianPoints;

  const _CartItemRow({
    required this.index,
    required this.cartItem,
    this.technicianPoints = 0,
  });

  @override
  Widget build(BuildContext context) {
    final sales = context.read<SalesProvider>();
    final isOdd = index.isOdd;
    return Container(
      decoration: BoxDecoration(
        color: isOdd ? Colors.grey.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Row number
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(AppColors.primaryInt).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text('${index + 1}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(AppColors.primaryInt))),
        ),
        const SizedBox(width: 6),
        // Item name
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cartItem.item.name,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (cartItem.item.storeType.isNotEmpty)
                Text(cartItem.item.storeType,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Quantity controls
        SizedBox(
          width: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (cartItem.qty <= 1) {
                    sales.removeItem(index);
                  } else {
                    sales.updateItem(index, qty: cartItem.qty - 1);
                  }
                },
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Icon(Icons.remove,
                      size: 14, color: Colors.red),
                ),
              ),
              Expanded(
                child: Text(
                  cartItem.qty.toStringAsFixed(
                      cartItem.qty % 1 == 0 ? 0 : 2),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              GestureDetector(
                onTap: () => sales.updateItem(index, qty: cartItem.qty + 1),
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Icon(Icons.add,
                      size: 14, color: Colors.green),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Unit price
        SizedBox(
          width: 90,
          child: InkWell(
            onTap: () {
              final priceCtrl = TextEditingController(
                text: cartItem.unitPrice.toStringAsFixed(2),
              );
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('تعديل سعر المنتج'),
                  content: TextField(
                    controller: priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'السعر الجديد',
                      prefixText: 'ج.م ',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final newPrice = double.tryParse(priceCtrl.text.trim());
                        if (newPrice == null || newPrice <= 0) {
                          return;
                        }
                        sales.updateItem(index, unitPrice: newPrice);
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('تحديث'),
                    ),
                  ],
                ),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    AppFormatters.formatCurrency(cartItem.unitPrice),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.edit, size: 14, color: Colors.blueGrey),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Total
        SizedBox(
          width: 65,
          child: Text(
            AppFormatters.formatCurrency(cartItem.total),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        // Delete
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: 'حذف المنتج',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => sales.removeItem(index),
          ),
        ),
      ]),
    );
  }
}

// ─── Product picker tile ──────────────────────────────────────────────────────
class _ProductPickerTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final double price;
  final bool inCart;
  final Color badgeColor;
  final String badgeLabel;
  final VoidCallback onTap;

  const _ProductPickerTile({
    required this.name,
    required this.subtitle,
    required this.price,
    required this.inCart,
    required this.badgeColor,
    required this.badgeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: inCart ? Colors.green.shade50 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: inCart
                                  ? Colors.green.shade800
                                  : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: badgeColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(badgeLabel,
                          style: TextStyle(
                              fontSize: 9, color: badgeColor)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: inCart
                    ? Colors.green
                    : const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 30),
              ),
              onPressed: onTap,
              icon: Icon(inCart ? Icons.add : Icons.add, size: 13),
              label: Text(
                AppFormatters.formatCurrency(price),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Customer search delegate ──────────────────────────────────────────────────
class _CustomerSearchDelegate extends SearchDelegate<Customer?> {
  final List<Customer> customers;

  _CustomerSearchDelegate(this.customers)
      : super(searchFieldLabel: 'ابحث عن عميل');

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
        IconButton(
          icon: const Icon(Icons.person_add, color: Colors.green),
          tooltip: 'إضافة عميل جديد',
          onPressed: () => _createNewCustomer(context),
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final filtered = customers
        .where((c) =>
            c.name.contains(query) || (c.phone?.contains(query) ?? false))
        .toList();
    return Column(
      children: [
        if (query.isNotEmpty && filtered.isEmpty)
          ListTile(
            leading: const Icon(Icons.person_add, color: Colors.green),
            title: Text('إضافة "$query" كعميل جديد'),
            subtitle: const Text('اضغط لإضافته للنظام'),
            onTap: () => _createNewCustomer(context, initialName: query),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => ListTile(
              title: Text(filtered[i].name),
              subtitle: Text(filtered[i].phone ?? ''),
              onTap: () => close(ctx, filtered[i]),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createNewCustomer(BuildContext context,
      {String initialName = ''}) async {
    final nameCtrl = TextEditingController(text: initialName);
    final phoneCtrl = TextEditingController();

    Future<void> pickContact() async {
      try {
        final status = await Permission.contacts.request();
        if (!status.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('يرجى السماح للوصول لجهات الاتصال'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final contact = await FlutterContacts.openExternalPick();
        if (contact == null) return;

        final full = await FlutterContacts.getContact(
          contact.id,
          withProperties: true,
        );

        if (!context.mounted) return;

        nameCtrl.text = full?.displayName ?? contact.displayName;
        if (full != null && full.phones.isNotEmpty) {
          phoneCtrl.text = full.phones.first.number;
        } else if (contact.phones.isNotEmpty) {
          phoneCtrl.text = contact.phones.first.number;
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر استيراد جهة الاتصال'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    final customer = await showDialog<Customer>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة عميل جديد'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'الاسم *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'رقم الهاتف', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: pickContact,
                icon: const Icon(Icons.contacts, size: 18),
                label: const Text('استيراد من جهات الاتصال'),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final now = DateTime.now().toIso8601String();
              final newCustomer = Customer(
                name: name,
                phone: phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
                customerType: AppConstants.customerTypeRegular,
                priceType: AppConstants.priceRetail,
                storeType: AppConstants.storeElectrical,
                createdAt: now,
                loginCode: AppFormatters.generateAccessCode(),
              );
              final id = await context
                  .read<CustomerProvider>()
                  .addCustomer(newCustomer);
              final saved = newCustomer.copyWith(id: id);
              if (ctx.mounted) Navigator.pop(ctx, saved);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (customer != null && context.mounted) {
      close(context, customer);
    }
  }
}
