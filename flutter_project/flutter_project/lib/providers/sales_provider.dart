import 'package:flutter/foundation.dart';
import '../models/sales_invoice.dart';
import '../models/item.dart';
import '../database/daos/invoice_dao.dart';
import '../database/daos/item_dao.dart';
import '../database/daos/customer_dao.dart';
import '../database/daos/treasury_dao.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class CartItem {
  final Item item;
  double qty;
  String priceType;
  double unitPrice;
  double discount;

  CartItem({
    required this.item,
    this.qty = 1,
    this.priceType = 'retail',
    required this.unitPrice,
    this.discount = 0,
  });

  double get total => (unitPrice * qty) - discount;
  double get costTotal => item.purchasePrice * qty;
}

class SalesProvider extends ChangeNotifier {
  final InvoiceDao _invoiceDao = InvoiceDao();
  final ItemDao _itemDao = ItemDao();
  final CustomerDao _customerDao = CustomerDao();

  List<CartItem> _cart = [];
  int? _selectedCustomerId;
  int? _selectedEmployeeId;
  double _extraDiscount = 0;

  List<CartItem> get cart => _cart;
  int? get selectedCustomerId => _selectedCustomerId;
  double get extraDiscount => _extraDiscount;

  double get subtotal => _cart.fold(0.0, (s, i) => s + (i.unitPrice * i.qty));
  double get totalDiscount =>
      _cart.fold<double>(0.0, (s, i) => s + i.discount) + _extraDiscount;
  double get total => subtotal - totalDiscount;

  void setCustomer(int? customerId) {
    _selectedCustomerId = customerId;
    notifyListeners();
  }

  void setEmployee(int? employeeId) {
    _selectedEmployeeId = employeeId;
    notifyListeners();
  }

  void setExtraDiscount(double d) {
    _extraDiscount = d;
    notifyListeners();
  }

  void addItem(Item item, {String priceType = 'retail'}) {
    final existing = _cart.where((c) => c.item.id == item.id).firstOrNull;
    if (existing != null) {
      existing.qty += 1;
    } else {
      _cart.add(CartItem(
        item: item,
        priceType: priceType,
        unitPrice: item.priceForType(priceType),
      ));
    }
    notifyListeners();
  }

  void updateItem(int index,
      {double? qty, double? unitPrice, double? discount, String? priceType}) {
    if (index >= _cart.length) return;
    if (qty != null) _cart[index].qty = qty;
    if (unitPrice != null) _cart[index].unitPrice = unitPrice;
    if (discount != null) _cart[index].discount = discount;
    if (priceType != null) {
      _cart[index].priceType = priceType;
      _cart[index].unitPrice = _cart[index].item.priceForType(priceType);
    }
    notifyListeners();
  }

  void removeItem(int index) {
    _cart.removeAt(index);
    notifyListeners();
  }

  void clearCart() {
    _cart = [];
    _selectedCustomerId = null;
    _selectedEmployeeId = null;
    _extraDiscount = 0;
    notifyListeners();
  }

  Future<int> saveInvoice({
    required String paymentType,
    required double amountPaid,
    required int? treasuryId,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final today = now.substring(0, 10);
    final remaining = total - amountPaid;
    String status = AppConstants.invoiceStatusPaid;
    if (paymentType == AppConstants.paymentInstallment) {
      status = AppConstants.invoiceStatusPartial;
    } else if (remaining > 0) {
      status = AppConstants.invoiceStatusPartial;
    }

    final invoiceId = await _invoiceDao.insertSalesInvoice(SalesInvoice(
      invoiceNo: 'TEMP',
      customerId: _selectedCustomerId,
      employeeId: _selectedEmployeeId,
      date: today,
      subtotal: subtotal,
      discount: totalDiscount,
      total: total,
      paymentType: paymentType,
      amountPaid: amountPaid,
      remaining: remaining,
      status: status,
      notes: notes,
      createdAt: now,
    ));

    if (invoiceId == -1) {
      throw Exception('فشل حفظ الفاتورة في قاعدة البيانات. تحقق من الاتصال بالإنترنت.');
    }

    final invoiceNo = AppFormatters.generateInvoiceNo('INV-', invoiceId);
    try {
      await Supabase.instance.client
          .from('sales_invoices')
          .update({'invoice_no': invoiceNo})
          .eq('id', invoiceId);
    } catch (_) {
      // Supabase sync is optional — continue if it fails
    }

    for (final cartItem in _cart) {
      await _invoiceDao.insertSalesInvoiceItem(SalesInvoiceItem(
        invoiceId: invoiceId,
        itemId: cartItem.item.id!,
        itemName: cartItem.item.name,
        barcode: cartItem.item.barcode,
        qty: cartItem.qty,
        costPrice: cartItem.item.purchasePrice,
        priceType: cartItem.priceType,
        unitPrice: cartItem.unitPrice,
        discount: cartItem.discount,
        total: cartItem.total,
      ));
      await _itemDao.updateQuantity(cartItem.item.id!, -cartItem.qty);
    }

    if (_selectedCustomerId != null && remaining > 0) {
      final customer = await _customerDao.findById(_selectedCustomerId!);
      if (customer != null) {
        await _customerDao.updateBalance(
            _selectedCustomerId!, customer.balance + remaining);
      }
    }

    // if (treasuryId != null && amountPaid > 0) {
    //   await _treasuryDao.addMovement(TreasuryMovement(
    //     treasuryId: treasuryId,
    //     type: 'deposit',
    //     amount: amountPaid,
    //     reference: invoiceNo,
    //     description: 'مبيعات - فاتورة $invoiceNo',
    //     date: today,
    //     createdBy: _selectedEmployeeId,
    //     createdAt: now,
    //   ));
    // }

    // Note: loyalty-points logging is handled by the invoice screen
    // via CustomerProvider.logPointsForInvoice(), which also calls addPoints().
    // Do NOT add points here to avoid double-counting.

    clearCart();
    return invoiceId;
  }

  Future<List<SalesInvoice>> getInvoices({
    int? customerId,
    String? fromDate,
    String? toDate,
    int? employeeId,
  }) =>
      _invoiceDao.getSalesInvoices(
          customerId: customerId,
          fromDate: fromDate,
          toDate: toDate,
          employeeId: employeeId);

  Future<List<SalesInvoiceItem>> getInvoiceItems(int invoiceId) =>
      _invoiceDao.getSalesInvoiceItems(invoiceId);

  Future<SalesInvoice?> findByBarcode(String barcode) =>
      _invoiceDao.findSalesInvoiceByBarcode(barcode);

  Future<Map<String, double>> getSummary(String fromDate, String toDate) =>
      _invoiceDao.getSalesSummary(fromDate, toDate);
}
