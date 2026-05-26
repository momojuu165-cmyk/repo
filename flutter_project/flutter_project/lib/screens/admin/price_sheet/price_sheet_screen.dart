import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../database/daos/customer_invoice_dao.dart';
import '../../../models/customer_invoice.dart';
import '../../../models/item.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../services/push_notification_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/notification_messages.dart';
import '../../widgets/barcode_scanner_screen.dart';
import '../customer_invoices/customer_invoices_admin_screen.dart';

/// كشف الأسعار — يتيح للعميل اختيار منتجات وكميات ونوع السعر
/// ثم تحويله لفاتورة بضغطة واحدة.
class PriceSheetScreen extends StatefulWidget {
  const PriceSheetScreen({super.key});

  @override
  State<PriceSheetScreen> createState() => _PriceSheetScreenState();
}

class _PriceSheetScreenState extends State<PriceSheetScreen> {
  final _searchCtrl = TextEditingController();
  List<Item> _searchResults = [];
  String _priceType = AppConstants.priceRetail;
  final List<_SheetItem> _items = [];
  bool _sending = false;

  static const Map<String, String> _priceTypeLabels = {
    AppConstants.priceRetail: 'قطاعي',
    AppConstants.priceWholesale: 'جملة',
    AppConstants.priceSemiWholesale: 'نصف جملة',
    AppConstants.priceSpecial: 'خاص',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0.0, (s, i) => s + i.total(_priceType));

  Future<void> _search(String query) async {
    final provider = context.read<InventoryProvider>();
    if (query.isEmpty) {
      setState(() => _searchResults = provider.items);
      return;
    }
    final results = await provider.search(query);
    setState(() => _searchResults = results);
  }

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scanned != null && mounted) {
      _searchCtrl.text = scanned;
      await _search(scanned);
    }
  }

  void _addItem(Item item) {
    final existing = _items.indexWhere((i) => i.item.id == item.id);
    if (existing >= 0) {
      setState(() => _items[existing] =
          _items[existing].copyWith(qty: _items[existing].qty + 1));
    } else {
      setState(() => _items.add(_SheetItem(item: item, qty: 1)));
    }
    _searchCtrl.clear();
    setState(() => _searchResults = []);
  }

  Future<void> _sendInvoiceRequest() async {
    if (_items.isEmpty) return;
    final auth = context.read<AuthProvider>();
    final customer = auth.currentCustomer;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يرجى تسجيل الدخول كعميل لإرسال طلب الفاتورة'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _sending = true);
    try {
      final invoiceNo = await CustomerInvoiceDao().generateInvoiceNo();
      final now = DateTime.now().toIso8601String();
      final invoice = CustomerInvoice(
        customerId: customer.id!,
        invoiceNo: invoiceNo,
        total: _total,
        paymentMethod: 'in_store',
        status: 'pending',
        date: now.substring(0, 10),
        createdAt: now,
        customerStoreType: customer.storeType,
        items: _items
            .map((si) => CustomerInvoiceItem(
                  itemId: si.item.id,
                  itemName: si.item.name,
                  qty: si.qty.toDouble(),
                  unitPrice: si.item.priceForType(_priceType),
                  total: si.total(_priceType),
                ))
            .toList(),
      );
      final insertedId = await CustomerInvoiceDao().insertInvoice(invoice);
      PushNotificationService.sendToRole(
        role: 'admin',
        title: NotifMsg.newInvoiceAdminTitle,
        body: '${NotifMsg.newInvoiceAdminBody} $invoiceNo',
        type: 'invoice',
        referenceId: insertedId > 0 ? insertedId : null,
        referenceType: 'invoice',
      );
      if (mounted) {
        setState(() {
          _items.clear();
          _searchResults = [];
        });
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const CustomerInvoicesAdminScreen()),
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم إرسال طلب الفاتورة برقم $invoiceNo'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('حدث خطأ أثناء إرسال الطلب: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف الأسعار'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _sending ? null : _sendInvoiceRequest,
              icon: const Icon(Icons.receipt_long),
              label: const Text('إرسال طلب فاتورة'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── نوع السعر ──────────────────────────────────────────────────────
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              const Text('نوع السعر:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _priceTypeLabels.entries.map((e) {
                      final selected = _priceType == e.key;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(e.value),
                          selected: selected,
                          onSelected: (_) => setState(() {
                            _priceType = e.key;
                          }),
                          selectedColor: const Color(AppColors.primaryInt),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ]),
          ),

          // ── بحث ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن منتج أو الباركود...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _search,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.accentInt),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _scanBarcode,
                child: const Icon(Icons.qr_code_scanner),
              ),
            ]),
          ),

          // ── نتائج البحث ─────────────────────────────────────────────────────
          if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              color: Colors.white,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final item = _searchResults[i];
                  final price = item.priceForType(_priceType);
                  return ListTile(
                    dense: true,
                    title: Text(item.name),
                    subtitle: Text(
                        'المخزون: ${item.quantity} | السعر: ${AppFormatters.formatCurrency(price)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => _addItem(item),
                    ),
                  );
                },
              ),
            ),

          // ── قائمة الأصناف ───────────────────────────────────────────────────
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.price_check,
                          size: 72, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('ابحث عن منتج وأضفه للكشف',
                          style: TextStyle(color: Colors.grey, fontSize: 15)),
                    ]),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final si = _items[i];
                      final price = si.item.priceForType(_priceType);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(si.item.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        '${AppFormatters.formatCurrency(price)} / قطعة',
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                  ]),
                            ),
                            // Qty controls
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    size: 20),
                                onPressed: () {
                                  if (si.qty > 1) {
                                    setState(() => _items[i] =
                                        si.copyWith(qty: si.qty - 1));
                                  } else {
                                    setState(() => _items.removeAt(i));
                                  }
                                },
                              ),
                              Text('${si.qty}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline,
                                    size: 20),
                                onPressed: () => setState(() =>
                                    _items[i] = si.copyWith(qty: si.qty + 1)),
                              ),
                            ]),
                            // Total
                            SizedBox(
                              width: 80,
                              child: Text(
                                AppFormatters.formatCurrency(
                                    si.total(_priceType)),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),

          // ── الإجمالي والتحويل ────────────────────────────────────────────────
          if (_items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
              ),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('عدد الأصناف:', style: TextStyle(fontSize: 14)),
                    Text(
                        '${_items.length} صنف — ${_items.fold(0, (s, i) => s + i.qty)} قطعة',
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(
                      AppFormatters.formatCurrency(_total),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppColors.primaryInt),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _sending ? null : _sendInvoiceRequest,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.receipt_long),
                    label: const Text('إرسال طلب فاتورة',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _SheetItem {
  final Item item;
  final int qty;
  const _SheetItem({required this.item, required this.qty});

  double total(String priceType) => item.priceForType(priceType) * qty;

  _SheetItem copyWith({int? qty}) =>
      _SheetItem(item: item, qty: qty ?? this.qty);
}
