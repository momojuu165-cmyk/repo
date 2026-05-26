import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/installment_provider.dart';
import '../../database/daos/request_dao.dart';
import '../../database/daos/installment_product_dao.dart';
import '../../database/daos/customer_invoice_dao.dart';
import '../../models/item.dart';
import '../../models/installment_product.dart';
import '../../models/app_settings.dart';
import '../../models/product_request.dart';
import '../../models/customer_invoice.dart';
import '../../services/push_notification_service.dart';
import '../../utils/notification_messages.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

// Feature 5: customer selects installment months from 1 to product.maxInstallmentMonths
class ProductRequestScreen extends StatefulWidget {
  final Item? item;
  final InstallmentProduct? installmentProduct; // Feature 5: for installment products
  final String? productName;
  final String? storeType; // filter product picker to this store type
  final int? initialInstallmentMonths;

  const ProductRequestScreen(
      {super.key, this.item, this.installmentProduct, this.productName, this.storeType, this.initialInstallmentMonths});

  @override
  State<ProductRequestScreen> createState() => _ProductRequestScreenState();
}

class _ProductRequestScreenState extends State<ProductRequestScreen> {
  String _paymentMethod = AppConstants.paymentMethodStore;
  int _installmentMonths = AppConstants.defaultMaxInstallmentMonths;
  double _depositAmount = 0;
  double _qty = 1;
  String? _receiptPath;
  bool _saving = false;
  final _invoiceDao = CustomerInvoiceDao();
  Map<String, dynamic>? _installCalc;
  final _productNameCtrl = TextEditingController();
  final _manualPriceCtrl = TextEditingController();

  // Feature 5: max months — use the admin-configured product limit.
  int get _maxMonths {
    if (widget.installmentProduct != null) {
      final max = widget.installmentProduct!.maxInstallmentMonths;
      return max > 0 ? max : AppConstants.defaultMaxInstallmentMonths;
    }
    return AppConstants.defaultMaxInstallmentMonths;
  }

  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _installmentMonths = (widget.initialInstallmentMonths ?? 12).clamp(1, _maxMonths);
    if (widget.productName != null) {
      _productNameCtrl.text = widget.productName!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final provider = context.read<InstallmentProvider>();
        if (provider.settings.monthlyInstallmentRate == 0) {
          await provider.loadSettings();
        }
        if (mounted) {
          setState(() => _settings = provider.settings);
          _updateCalc();
        }
      } catch (_) {
        if (mounted) _updateCalc();
      }
    });
  }

  @override
  void dispose() {
    _productNameCtrl.dispose();
    _manualPriceCtrl.dispose();
    super.dispose();
  }

  // Returns the product base price; falls back to installment price then manual entry
  double get _unitPrice {
    if (widget.installmentProduct != null) {
      final cashP = widget.installmentProduct!.effectiveCashPrice;
      if (cashP > 0) return cashP;
      final instP = widget.installmentProduct!.effectiveInstallmentPrice;
      if (instP > 0) return instP;
    }
    if (widget.item != null) {
      final auth = context.read<AuthProvider>();
      final priceType =
          auth.currentCustomer?.priceType ?? AppConstants.priceRetail;
      final p = widget.item!.priceForType(priceType);
      if (p > 0) return p;
    }
    return double.tryParse(_manualPriceCtrl.text) ?? 0.0;
  }

  bool get _needsManualPrice =>
      (widget.item != null || widget.installmentProduct != null) &&
      _unitPrice == 0.0 &&
      (double.tryParse(_manualPriceCtrl.text) ?? 0) == 0;

  double get _requestBasePrice {
    if (widget.installmentProduct != null) {
      if (widget.installmentProduct!.installmentPrice > 0) {
        return widget.installmentProduct!.installmentPrice;
      }
      return widget.installmentProduct!.salePrice;
    }
    if (widget.item != null) {
      final auth = context.read<AuthProvider>();
      final priceType = auth.currentCustomer?.priceType ?? AppConstants.priceRetail;
      return widget.item!.priceForType(priceType);
    }
    return double.tryParse(_manualPriceCtrl.text) ?? 0.0;
  }

  double get _invoiceTotal => _installCalc != null
      ? ((_installCalc!['total_price'] as num?)?.toDouble() ?? _unitPrice * _qty)
      : _unitPrice * _qty;

  void _updateCalc() {
    final salePrice = _requestBasePrice * _qty;
    double purchasePrice = 0;
    if (widget.item != null) {
      purchasePrice = widget.item!.purchasePrice * _qty;
    } else if (widget.installmentProduct != null) {
      purchasePrice = widget.installmentProduct!.purchasePrice * _qty;
    }

    double rate = 0;
    if (widget.installmentProduct != null &&
        widget.installmentProduct!.installmentPrice > 0) {
      rate = 0.0;
    } else if (widget.installmentProduct != null &&
        widget.installmentProduct!.profitRate > 0) {
      rate = widget.installmentProduct!.profitRate * 100 * _installmentMonths;
    } else {
      rate = _settings.rateForMonths(_installmentMonths);
      if (rate <= 0) rate = 10.0;
    }

    final calc = InstallmentProvider.calculateInstallment(
      salePrice: salePrice,
      purchasePrice: purchasePrice,
      numInstallments: _installmentMonths,
      downPayment: _depositAmount,
      installmentRatePct: rate,
    );
    setState(() => _installCalc = calc);
  }

  Future<void> _pickFromProducts() async {
    try {
      final allProducts = await InstallmentProductDao().getAll(
        availableOnly: true,
        storeType: widget.storeType,
      );
      if (!mounted) return;
      final searchCtrl = TextEditingController();
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setInner) {
            final query = searchCtrl.text.trim().toLowerCase();
            final visible = query.isEmpty
                ? allProducts
                : allProducts.where((p) => p.name.toLowerCase().contains(query)).toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.92,
              builder: (_, scrollCtrl) => Column(children: [
                const SizedBox(height: 8),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('اختر منتجاً من القائمة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: searchCtrl,
                    textDirection: ui.TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'بحث عن منتج...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (_) => setInner(() {}),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('لا توجد منتجات', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          controller: scrollCtrl,
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = visible[i];
                            final price = p.effectiveCashPrice;
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.inventory_2_outlined, size: 20),
                              title: Text(p.name,
                                  style: const TextStyle(fontSize: 14),
                                  textDirection: ui.TextDirection.rtl),
                              subtitle: p.category != null
                                  ? Text(p.category!, style: const TextStyle(fontSize: 11, color: Colors.grey))
                                  : null,
                              trailing: price > 0
                                  ? Text(AppFormatters.formatCurrency(price),
                                      style: TextStyle(color: Colors.green[700], fontSize: 13))
                                  : null,
                              onTap: () {
                                setState(() {
                                  _productNameCtrl.text = p.name;
                                  if (price > 0) {
                                    _manualPriceCtrl.text = price.toStringAsFixed(0);
                                  }
                                });
                                _updateCalc();
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ]),
            );
          });
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر تحميل المنتجات: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _receiptPath = result.files.single.path);
    }
  }

  Future<void> _submitRequest() async {
    final auth = context.read<AuthProvider>();
    final customer = auth.currentCustomer;
    if (customer == null) return;
    final productName = widget.item?.name ??
        widget.installmentProduct?.name ??
        _productNameCtrl.text.trim();
    if (productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء إدخال اسم المنتج'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final requestStoreType = widget.storeType ?? customer.storeType;
      String? notesText;
      int? requestId;
      if (requestStoreType != AppConstants.storeElectrical) {
        requestId = await RequestDao().insert(ProductRequest(
          customerId: customer.id!,
          itemId: widget.item?.id,
          productName: productName,
          qty: _qty,
          paymentMethod: _paymentMethod,
          receiptPath: _receiptPath,
          depositAmount: _depositAmount,
          numInstallments: _paymentMethod == AppConstants.paymentMethodStore
              ? _installmentMonths
              : null,
          notes: notesText,
          date: now.substring(0, 10),
          createdAt: now,
          storeType: requestStoreType,
        ));
      }

      final invoiceNo = await _invoiceDao.generateInvoiceNo();
      final invoiceId = await _invoiceDao.insertInvoice(CustomerInvoice(
        customerId: customer.id!,
        invoiceNo: invoiceNo,
        total: _invoiceTotal,
        paymentMethod: _paymentMethod,
        receiptPath: _receiptPath,
        status: 'pending',
        notes: 'طلب منتج: $productName',
        date: now.substring(0, 10),
        createdAt: now,
        customerStoreType: requestStoreType,
        items: [
          CustomerInvoiceItem(
            itemId: widget.item?.id ?? widget.installmentProduct?.id,
            itemName: productName,
            qty: _qty,
            unitPrice: _qty > 0 ? _invoiceTotal / _qty : 0,
            total: _invoiceTotal,
          ),
        ],
      ));

      if (invoiceId > 0) {
        PushNotificationService.sendToRole(
          role: 'admin',
          title: NotifMsg.newInvoiceAdminTitle,
          body: '${NotifMsg.newInvoiceAdminBody} $invoiceNo',
          type: 'invoice',
          referenceId: invoiceId,
          referenceType: 'invoice',
        );
      }
      if (requestId != null && requestId > 0) {
        final storeLabel = AppConstants.deptLabels[customer.storeType] ?? customer.storeType ?? '';
        PushNotificationService.sendToRole(
          role: 'admin',
          title: NotifMsg.newRequestAdminTitle,
          body: '${NotifMsg.newRequestAdminBody}: $productName'
              '${storeLabel.isNotEmpty ? " ($storeLabel)" : ""}',
          type: 'request',
          referenceId: requestId,
          referenceType: 'request',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(invoiceId > 0
                  ? 'تم إرسال الطلب كفاتورة رقم $invoiceNo'
                  : 'تم إرسال طلبك بنجاح'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('حدث خطأ: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProduct =
        widget.item != null || widget.installmentProduct != null;
    final productName =
        widget.item?.name ?? widget.installmentProduct?.name ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(hasProduct ? productName : 'إنشاء طلب'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info
            if (hasProduct) ...[
              Text(productName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (_unitPrice > 0) ...[
                Text(
                  AppFormatters.formatCurrency(_unitPrice),
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                if (widget.installmentProduct != null &&
                    widget.installmentProduct!.showInstallmentPrice) ...[
                  const SizedBox(height: 4),
                  Text(
                    'سعر التقسيط: ${AppFormatters.formatCurrency(widget.installmentProduct!.effectiveInstallmentPrice)}',
                    style: const TextStyle(
                        color: Color(AppColors.installmentInt), fontSize: 14),
                  ),
                ],
              ] else ...[
                // Price not set in DB — let user enter it manually
                const SizedBox(height: 4),
                TextFormField(
                  controller: _manualPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'سعر المنتج (جنيه)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.attach_money),
                    hintText: 'أدخل سعر المنتج',
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _updateCalc();
                  },
                ),
              ],
            ] else ...[
              const Text('طلب منتج',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _productNameCtrl,
                      textDirection: ui.TextDirection.rtl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المنتج المطلوب',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickFromProducts,
                    icon: const Icon(Icons.list_alt, size: 16),
                    label: const Text('استيراد', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      side: const BorderSide(color: Color(AppColors.primaryInt)),
                      foregroundColor: Color(AppColors.primaryInt),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Quantity
            Row(children: [
              const Text('الكمية: '),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _qty > 1
                    ? () { setState(() => _qty--); _updateCalc(); }
                    : null,
              ),
              Text(_qty.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () { setState(() => _qty++); _updateCalc(); },
              ),
            ]),
            if (widget.installmentProduct != null && _paymentMethod == AppConstants.paymentMethodStore) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('عدد أشهر التقسيط',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('$_installmentMonths شهر',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(AppColors.installmentInt),
                  thumbColor: const Color(AppColors.installmentInt),
                  inactiveTrackColor:
                      const Color(AppColors.installmentInt).withValues(alpha: 0.3),
                ),
                child: Slider(
                  value: _installmentMonths.toDouble(),
                  min: 1,
                  max: _maxMonths.toDouble(),
                  divisions: _maxMonths > 1 ? _maxMonths - 1 : 1,
                  label: '$_installmentMonths',
                  onChanged: (value) {
                    setState(() {
                      _installmentMonths = value.round().clamp(1, _maxMonths);
                      _updateCalc();
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              if (_installCalc != null) ...[
                _CalcRow('السعر الإجمالي بعد الرسوم',
                    AppFormatters.formatCurrency(((_installCalc!['total_price'] as num?)?.toDouble() ?? 0)),
                    bold: true),
                _CalcRow('القسط الشهري',
                    AppFormatters.formatCurrency(((_installCalc!['monthly_amount'] as num?)?.toDouble() ?? 0)),
                    highlight: true),
                _CalcRow('رسوم التقسيط',
                    AppFormatters.formatCurrency(((_installCalc!['installment_fee'] as num?)?.toDouble() ?? 0))),
              ],
            ],
            const Divider(),
            // Payment method
            const Text('طريقة الدفع',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _PaymentOption(
                  icon: Icons.store,
                  label: 'في المحل',
                  selected: _paymentMethod == AppConstants.paymentMethodStore,
                  onTap: () => setState(
                      () => _paymentMethod = AppConstants.paymentMethodStore),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PaymentOption(
                  icon: Icons.upload_file,
                  label: 'رفع إيصال',
                  selected:
                      _paymentMethod == AppConstants.paymentMethodReceipt,
                  onTap: () => setState(() =>
                      _paymentMethod = AppConstants.paymentMethodReceipt),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (_paymentMethod == AppConstants.paymentMethodReceipt) ...[
              ElevatedButton.icon(
                onPressed: _pickReceipt,
                icon: const Icon(Icons.upload),
                label: Text(_receiptPath != null
                    ? 'تم رفع الإيصال ✓'
                    : 'رفع صورة الإيصال'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _receiptPath != null ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _saving ? null : _submitRequest,
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال الطلب',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(AppColors.primaryInt).withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(AppColors.primaryInt)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(children: [
          Icon(icon,
              color: selected
                  ? const Color(AppColors.primaryInt)
                  : Colors.grey),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: selected
                      ? const Color(AppColors.primaryInt)
                      : Colors.grey,
                  fontWeight: selected
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ]),
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool highlight;

  const _CalcRow(this.label, this.value,
      {this.bold = false, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: highlight ? 14 : 13)),
        Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: highlight ? 16 : 13,
                color: highlight
                    ? const Color(AppColors.installmentInt)
                    : null)),
      ]),
    );
  }
}
