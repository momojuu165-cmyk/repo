import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../database/daos/customer_invoice_dao.dart';
import '../../database/daos/installment_product_dao.dart';
import '../../database/daos/electrical_bundle_dao.dart';
import '../../models/customer_invoice.dart';
import '../../models/installment_product.dart';
import '../../models/electrical_bundle.dart';
import '../../services/push_notification_service.dart';
import '../../utils/notification_messages.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class CustomerCreateInvoiceScreen extends StatefulWidget {
  final int customerId;
  final String storeType;
  const CustomerCreateInvoiceScreen({super.key, required this.customerId, required this.storeType});
  @override
  State<CustomerCreateInvoiceScreen> createState() => _CustomerCreateInvoiceScreenState();
}

class _CustomerCreateInvoiceScreenState extends State<CustomerCreateInvoiceScreen> {
  final _invoiceDao = CustomerInvoiceDao();
  final _productDao = InstallmentProductDao();
  final _bundleDao = ElectricalBundleDao();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'in_store';
  File? _receiptImage;
  final List<_ItemEntry> _entries = [];
  List<InstallmentProduct> _availableProducts = [];
  List<ElectricalBundle> _availableBundles = [];
  bool _loading = false;
  bool _loadingProducts = true;
  int _installmentMonths = 1;

  static const double _annualInstallmentFeeRate = 0.10;
  double get _installmentFee {
    if (_installmentMonths <= 1) return 0.0;
    return _total * _annualInstallmentFeeRate * (_installmentMonths / 12.0);
  }
  double get _totalWithFee => _total + _installmentFee;

  int get _maxInstallmentMonths => 240;
  double get _monthlyPayment =>
      _installmentMonths > 0 ? _totalWithFee / _installmentMonths : _totalWithFee;

  bool get _isElectrical => widget.storeType == AppConstants.storeElectrical;

  @override
  void initState() { super.initState(); _loadProducts(); }

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    // Load products filtered by store type
    final products = await _productDao.getAll(
      availableOnly: true,
      storeType: widget.storeType,
    );
    List<ElectricalBundle> bundles = [];
    if (_isElectrical) {
      bundles = await _bundleDao.getAllBundles(activeOnly: true);
    }
    if (mounted) setState(() {
      _availableProducts = products;
      _availableBundles = bundles;
      _loadingProducts = false;
    });
  }

  double _invoiceDiscountPct = 0.0;
  double get _total => _entries.fold(0.0, (s, e) => s + e.total);
  double get _discountedTotal => _isElectrical && _invoiceDiscountPct > 0
      ? _total * (1 - _invoiceDiscountPct / 100)
      : _total;

  Future<void> _pickReceipt() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null && mounted) setState(() => _receiptImage = File(picked.path));
  }

  Future<void> _submit() async {
    if (_entries.isEmpty) { _snack('أضف منتجاً واحداً على الأقل', Colors.red); return; }
    final needsReceipt = _paymentMethod == 'vodafone_cash'
        || _paymentMethod == 'instapay' || _paymentMethod == 'bank_transfer';
    if (needsReceipt && _receiptImage == null) {
      _snack('يرجى إرفاق إيصال الدفع', Colors.orange); return;
    }
    setState(() => _loading = true);
    try {
      final invoiceNo = await _invoiceDao.generateInvoiceNo();
      final now = DateTime.now().toIso8601String();
      final invoice = CustomerInvoice(
        customerId: widget.customerId, invoiceNo: invoiceNo,
        total: _discountedTotal, paymentMethod: _paymentMethod,
        receiptPath: _receiptImage?.path, status: 'pending',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        date: now, createdAt: now,
        customerStoreType: widget.storeType,
        items: _entries.map((e) => CustomerInvoiceItem(
          itemName: e.name, qty: e.qty, unitPrice: e.unitPrice,
          total: e.total, itemId: e.itemId,
        )).toList(),
      );
      await _invoiceDao.insertInvoice(invoice);
      // Notify admin of new customer invoice
      PushNotificationService.sendToRole(
        role: 'admin',
        title: NotifMsg.newInvoiceAdminTitle,
        body: '${NotifMsg.newInvoiceAdminBody} $invoiceNo',
        type: 'invoice',
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم إرسال طلبك برقم $invoiceNo'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      _snack('حدث خطأ: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء فاتورة جديدة'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      body: _loadingProducts
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SectionTitle(icon: Icons.shopping_cart, title: 'المنتجات المطلوبة'),
                  const SizedBox(height: 8),
                  if (_entries.isEmpty)
                    _emptyProductsPlaceholder()
                  else ..._entries.asMap().entries.map((e) => _buildItemCard(e.key, e.value)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                      side: const BorderSide(color: Color(AppColors.primaryInt))),
                    onPressed: _showAddItemDialog,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('إضافة منتج')),
                  if (_entries.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _TotalBox(total: _discountedTotal),

                    const SizedBox(height: 16),
                    _SectionTitle(icon: Icons.calendar_month, title: 'عدد أشهر التقسيط'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(AppColors.primaryInt).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(AppColors.primaryInt).withValues(alpha: 0.2)),
                      ),
                      child: Column(children: [
                        Row(children: [
                          const Text('عدد الأشهر: '),
                          Expanded(
                            child: Slider(
                              value: _installmentMonths.clamp(1, _maxInstallmentMonths).toDouble(),
                              min: 1,
                              max: _maxInstallmentMonths.toDouble(),
                              divisions: _maxInstallmentMonths > 1 ? _maxInstallmentMonths - 1 : 1,
                              activeColor: const Color(AppColors.primaryInt),
                              label: '$_installmentMonths شهر',
                              onChanged: (v) => setState(() =>
                                  _installmentMonths = v.round().clamp(1, _maxInstallmentMonths)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(AppColors.primaryInt),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$_installmentMonths شهر',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('إجمالي المنتجات:', style: TextStyle(fontSize: 13)),
                              Text(AppFormatters.formatCurrency(_total),
                                  style: const TextStyle(fontSize: 13)),
                            ]),
                            if (_installmentFee > 0) ...[
                              const SizedBox(height: 4),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text('رسوم التقسيط (${(_annualInstallmentFeeRate * 100).toStringAsFixed(0)}% شهرياً × $_installmentMonths شهر):',
                                    style: const TextStyle(fontSize: 12, color: Colors.orange)),
                                Text('+ ${AppFormatters.formatCurrency(_installmentFee)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.orange)),
                              ]),
                              const Divider(height: 12),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                const Text('الإجمالي مع الرسوم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(AppFormatters.formatCurrency(_totalWithFee),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(AppColors.primaryInt))),
                              ]),
                              const SizedBox(height: 8),
                            ],
                            const Divider(height: 8),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('القسط الشهري التقريبي:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(AppFormatters.formatCurrency(_monthlyPayment),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 18,
                                      color: Color(AppColors.primaryInt))),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _SectionTitle(icon: Icons.payment, title: 'طريقة الدفع'),
                  const SizedBox(height: 8),
                  _PaymentSelector(value: _paymentMethod,
                      onChanged: (v) => setState(() => _paymentMethod = v)),
                  if (_paymentMethod != 'in_store') ...[
                    const SizedBox(height: 16),
                    _SectionTitle(icon: Icons.receipt_long, title: 'إيصال الدفع',
                        subtitle: 'مطلوب', subtitleColor: Colors.red),
                    const SizedBox(height: 8),
                    _ReceiptPicker(image: _receiptImage,
                        onPick: _pickReceipt,
                        onClear: () => setState(() => _receiptImage = null)),
                  ],
                  const SizedBox(height: 16),
                  _SectionTitle(icon: Icons.notes, title: 'ملاحظات (اختياري)'),
                  const SizedBox(height: 8),
                  TextField(controller: _notesCtrl, maxLines: 3,
                      decoration: const InputDecoration(hintText: 'أي ملاحظات خاصة بطلبك...')),
                  const SizedBox(height: 30),
                ]),
              )),
              _SubmitBar(loading: _loading, onSubmit: _submit),
            ]),
    );
  }

  Widget _emptyProductsPlaceholder() => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200)),
    child: const Text('لم تضف أي منتج. اضغط + لإضافة.',
        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));

  Widget _buildItemCard(int index, _ItemEntry entry) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${entry.qty.toStringAsFixed(0)} × ${AppFormatters.formatCurrency(entry.unitPrice)}'),
        if (entry.discountRate > 0)
          Text('خصم ${entry.discountRate.toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.green, fontSize: 11)),
      ]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(AppFormatters.formatCurrency(entry.total),
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => setState(() => _entries.removeAt(index))),
      ]),
    ));

  void _showAddItemDialog() {
    if (_isElectrical) {
      _showElectricalAddItemDialog();
    } else {
      _showStandardAddItemDialog();
    }
  }

  // ── Electrical: search all products ──────────────────────────────────────

  void _showElectricalAddItemDialog() {
    final searchCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    InstallmentProduct? selectedProduct;
    ElectricalBundle? matchedBundle;

    double _findBundleDiscount(InstallmentProduct p) {
      for (final b in _availableBundles) {
        if (b.items.any((i) => i.itemName.toLowerCase() == p.name.toLowerCase())) {
          return b.discountRate;
        }
      }
      return 0.0;
    }

    ElectricalBundle? _findBundle(InstallmentProduct p) {
      for (final b in _availableBundles) {
        if (b.items.any((i) => i.itemName.toLowerCase() == p.name.toLowerCase())) {
          return b;
        }
      }
      return null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        final query = searchCtrl.text.toLowerCase();
        final filtered = query.isEmpty
            ? _availableProducts
            : _availableProducts
                .where((p) => p.name.toLowerCase().contains(query))
                .toList();

        final discountRate = selectedProduct != null
            ? _findBundleDiscount(selectedProduct!)
            : 0.0;
        final displayPrice = selectedProduct != null
            ? (discountRate > 0
                ? selectedProduct!.salePrice * (1 - discountRate / 100)
                : selectedProduct!.salePrice)
            : 0.0;

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('إضافة منتج كهربائي',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Search field
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setS(() {}),
              ),
              const SizedBox(height: 8),

              // Search results
              if (filtered.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final dr = _findBundleDiscount(p);
                      final price = dr > 0
                          ? p.salePrice * (1 - dr / 100)
                          : p.salePrice;
                      final isSelected = selectedProduct?.id == p.id;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor:
                            const Color(AppColors.primaryInt).withValues(alpha: 0.07),
                        title: Text(p.name,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: p.category != null
                            ? Text(p.category!,
                                style: const TextStyle(fontSize: 11))
                            : null,
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (dr > 0)
                              Text(
                                AppFormatters.formatCurrency(p.salePrice),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough),
                              ),
                            Text(
                              AppFormatters.formatCurrency(price),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: dr > 0
                                      ? Colors.green
                                      : Colors.green.shade700),
                            ),
                          ],
                        ),
                        onTap: () => setS(() {
                          selectedProduct = p;
                          matchedBundle = _findBundle(p);
                          searchCtrl.text = p.name;
                        }),
                      );
                    },
                  ),
                ),

              if (selectedProduct != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.primaryInt).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(AppColors.primaryInt).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(selectedProduct!.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    if (discountRate > 0)
                      Text(
                        'خصم ${discountRate.toStringAsFixed(0)}% من ليسته "${matchedBundle?.name ?? ''}"',
                        style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    Text(
                      'السعر: ${AppFormatters.formatCurrency(displayPrice)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'الكمية', isDense: true),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppColors.primaryInt),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46)),
                onPressed: () {
                  final name = selectedProduct?.name ?? searchCtrl.text.trim();
                  if (name.isEmpty) return;
                  final qty = double.tryParse(qtyCtrl.text) ?? 1;
                  final price = selectedProduct != null ? displayPrice : 0.0;
                  setState(() => _entries.add(_ItemEntry(
                    name: name,
                    qty: qty,
                    unitPrice: price,
                    total: qty * price,
                    itemId: selectedProduct?.id,
                    maxMonths: null,
                    discountRate: discountRate,
                    bundleName: matchedBundle?.name,
                  )));
                  Navigator.pop(ctx);
                },
                child: const Text('إضافة'),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        );
      }),
    );
  }

  void _showElectricalAddItemDialogOld() {
    // Removed — replaced by search-only dialog above
  }

  // (old dialog removed - replaced by search-only dialog)

  // ── Standard: pick from products or type manually ────────────────────────

  void _showStandardAddItemDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();
    InstallmentProduct? selectedProduct;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16, right: 16, top: 16),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('إضافة منتج للفاتورة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_availableProducts.isNotEmpty) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                side: const BorderSide(color: Color(AppColors.primaryInt)),
                foregroundColor: const Color(AppColors.primaryInt),
              ),
              icon: const Icon(Icons.search),
              label: selectedProduct == null
                  ? const Text('اختر منتجاً من الكتالوج')
                  : Text(selectedProduct!.name, overflow: TextOverflow.ellipsis),
              onPressed: () async {
                final picked = await showDialog<InstallmentProduct>(
                  context: ctx,
                  builder: (dlg) {
                    String query = '';
                    return StatefulBuilder(builder: (dlg, setDlg) {
                      final filtered = query.isEmpty
                          ? _availableProducts
                          : _availableProducts.where((p) =>
                              p.name.toLowerCase().contains(query.toLowerCase())).toList();
                      return AlertDialog(
                        contentPadding: const EdgeInsets.all(8),
                        title: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('اختر منتجاً'),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(
                                hintText: 'بحث...', prefixIcon: Icon(Icons.search), isDense: true),
                            onChanged: (v) => setDlg(() => query = v),
                          ),
                        ]),
                        content: SizedBox(
                          width: double.maxFinite,
                          height: 350,
                          child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final p = filtered[i];
                              final price = p.salePrice > 0 ? p.salePrice : p.cashPrice;
                              return ListTile(
                                dense: true,
                                title: Text(p.name, style: const TextStyle(fontSize: 13)),
                                subtitle: p.category != null ? Text(p.category!, style: const TextStyle(fontSize: 11)) : null,
                                trailing: price > 0
                                    ? Text(AppFormatters.formatCurrency(price),
                                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold))
                                    : null,
                                onTap: () => Navigator.pop(dlg, p),
                              );
                            },
                          ),
                        ),
                        actions: [TextButton(onPressed: () => Navigator.pop(dlg), child: const Text('إلغاء'))],
                      );
                    });
                  },
                );
                if (picked != null) setS(() {
                  selectedProduct = picked;
                  nameCtrl.text = picked.name;
                  final price = picked.salePrice > 0 ? picked.salePrice : picked.cashPrice;
                  if (price > 0) priceCtrl.text = price.toStringAsFixed(0);
                });
              },
            ),
            if (selectedProduct != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: const [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('أو عدّل البيانات', style: TextStyle(color: Colors.grey, fontSize: 12))),
                  Expanded(child: Divider()),
                ]),
              ),
            if (selectedProduct == null)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: const [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('أو أدخل يدوياً', style: TextStyle(color: Colors.grey))),
                  Expanded(child: Divider()),
                ])),
          ],
          TextField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المنتج *')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'الكمية'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                readOnly: selectedProduct != null,
                style: TextStyle(
                  color: selectedProduct != null ? Colors.grey.shade600 : null,
                ),
                decoration: InputDecoration(
                  labelText: 'السعر التقريبي',
                  filled: selectedProduct != null,
                  fillColor: selectedProduct != null ? Colors.grey.shade100 : null,
                ))),
          ]),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46)),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final qty = double.tryParse(qtyCtrl.text) ?? 1;
              final price = double.tryParse(priceCtrl.text) ?? 0;
              setState(() => _entries.add(_ItemEntry(
                name: nameCtrl.text.trim(), qty: qty,
                unitPrice: price, total: qty * price, itemId: selectedProduct?.id,
                maxMonths: selectedProduct?.maxInstallmentMonths)));
              Navigator.pop(ctx);
            },
            child: const Text('إضافة')),
        ]),
      )));
  }
}

class _ItemEntry {
  final String name;
  final double qty;
  final double unitPrice;
  final double total;
  final int? itemId;
  final int? maxMonths;
  final double discountRate;
  final String? bundleName;
  _ItemEntry({
    required this.name, required this.qty, required this.unitPrice,
    required this.total, this.itemId, this.maxMonths,
    this.discountRate = 0, this.bundleName,
  });
}

class _SectionTitle extends StatelessWidget {
  final IconData icon; final String title;
  final String? subtitle; final Color? subtitleColor;
  const _SectionTitle({required this.icon, required this.title, this.subtitle, this.subtitleColor});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: const Color(AppColors.primaryInt)),
    const SizedBox(width: 6),
    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    if (subtitle != null) ...[
      const SizedBox(width: 6),
      Text(subtitle!, style: TextStyle(color: subtitleColor ?? Colors.grey, fontSize: 12)),
    ],
  ]);
}

class _TotalBox extends StatelessWidget {
  final double total;
  const _TotalBox({required this.total});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(AppColors.primaryInt).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('الإجمالي التقريبي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      Text(AppFormatters.formatCurrency(total), style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 20, color: Color(AppColors.primaryInt))),
    ]));
}

class _PaymentSelector extends StatelessWidget {
  final String value; final ValueChanged<String> onChanged;
  const _PaymentSelector({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final methods = [
      ('in_store', 'دفع عند الاستلام', Icons.store),
      ('vodafone_cash', 'فودافون كاش', Icons.phone_android),
      ('instapay', 'إنستاباي', Icons.account_balance_wallet),
      ('bank_transfer', 'تحويل بنكي', Icons.account_balance),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: methods.map((m) {
      final selected = value == m.$1;
      return GestureDetector(
        onTap: () => onChanged(m.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(AppColors.primaryInt).withValues(alpha: 0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(AppColors.primaryInt) : Colors.grey.shade300,
              width: selected ? 2 : 1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(m.$3, size: 18,
                color: selected ? const Color(AppColors.primaryInt) : Colors.grey),
            const SizedBox(width: 6),
            Text(m.$2, style: TextStyle(
              color: selected ? const Color(AppColors.primaryInt) : Colors.grey.shade700,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13)),
          ])));
    }).toList());
  }
}

class _ReceiptPicker extends StatelessWidget {
  final File? image; final VoidCallback onPick; final VoidCallback onClear;
  const _ReceiptPicker({required this.image, required this.onPick, required this.onClear});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity, height: image != null ? 180 : 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: image != null ? Colors.green : Colors.grey.shade300,
            width: image != null ? 2 : 1)),
        child: image != null
            ? ClipRRect(borderRadius: BorderRadius.circular(10),
                child: Image.file(image!, fit: BoxFit.cover))
            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.cloud_upload_outlined, size: 36, color: Colors.grey),
                SizedBox(height: 6),
                Text('اضغط لرفع صورة الإيصال', style: TextStyle(color: Colors.grey)),
              ]))),
    if (image != null)
      TextButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.delete, color: Colors.red, size: 16),
        label: const Text('حذف الصورة', style: TextStyle(color: Colors.red, fontSize: 12))),
  ]);
}

class _SubmitBar extends StatelessWidget {
  final bool loading; final VoidCallback onSubmit;
  const _SubmitBar({required this.loading, required this.onSubmit});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))]),
    child: SafeArea(child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52)),
      onPressed: loading ? null : onSubmit,
      icon: loading
          ? const SizedBox(height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.send),
      label: Text(loading ? 'جاري الإرسال...' : 'إرسال الطلب'))));
}
