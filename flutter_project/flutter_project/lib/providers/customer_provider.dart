import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/customer_points_log.dart';
import '../database/daos/customer_dao.dart';
import '../database/daos/customer_points_dao.dart';
import '../utils/formatters.dart';
import '../utils/whatsapp_helper.dart';

class CustomerProvider extends ChangeNotifier {
  final CustomerDao _dao = CustomerDao();
  final CustomerPointsDao _pointsDao = CustomerPointsDao();

  List<Customer> _customers = [];
  bool _loading = false;

  List<Customer> get customers => _customers;
  bool get loading => _loading;

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    _customers = await _dao.getAll();
    _loading = false;
    notifyListeners();
  }

  void _patchCustomerPoints(int customerId, int newPoints) {
    final index = _customers.indexWhere((customer) => customer.id == customerId);
    if (index == -1) return;

    _customers[index] = _customers[index].copyWith(points: newPoints);
    notifyListeners();
  }

  Future<List<Customer>> getAll() => _dao.getAll();
  Future<List<Customer>> search(String query) => _dao.search(query);
  Future<Customer?> getById(int id) => _dao.findById(id);

  Future<int> addCustomer(Customer c) async {
    final id = await _dao.insert(c);
    await loadAll();
    return id;
  }

  Future<void> updateCustomer(Customer c) async {
    await _dao.update(c);
    await loadAll();
  }

  Future<void> deleteCustomer(int id) async {
    await _dao.delete(id);
    await loadAll();
  }

  Future<String> generateAndSaveLoginCode(int customerId) async {
    final code = AppFormatters.generateAccessCode();
    await _dao.updateLoginCode(customerId, code);
    await loadAll();
    return code;
  }

  Future<bool> sendCodeViaWhatsApp(Customer customer, String code) async {
    if (customer.phone == null || customer.phone!.isEmpty) return false;
    await WhatsAppHelper.sendCustomerCode(
      phone: customer.phone!,
      name: customer.name,
      code: code,
    );
    return true;
  }

  /// Adds (or subtracts) points directly on the customer record.
  /// Throws a descriptive exception if the update fails (e.g. RLS blocked).
  Future<void> addPoints(int customerId, int points) async {
    await _dao.addPoints(customerId, points);
    await loadAll();
  }

  /// Inserts a points-log entry and increments the customer's total.
  ///
  /// Throws if either operation fails so callers can surface the error.
  Future<void> logPointsForInvoice({
    required int customerId,
    required int invoiceId,
    required String invoiceNo,
    required String date,
    required int pointsEarned,
    required double pointValue,
    required String pointCurrency,
  }) async {
    if (pointsEarned <= 0) return;

    final entry = CustomerPointsLog(
      customerId: customerId,
      invoiceId: invoiceId,
      invoiceNo: invoiceNo,
      date: date,
      pointsEarned: pointsEarned,
      pointValue: pointValue,
      pointCurrency: pointCurrency,
      isSettled: false,
      createdAt: DateTime.now().toIso8601String(),
    );

    // Insert into points log — throws if table missing or RLS blocks insert
    await _pointsDao.insert(entry);

    // Update the customer's total points — throws if RLS blocks update
    await _dao.addPoints(customerId, pointsEarned);

    // Refresh the in-memory customer list so all listening screens update
    await loadAll();
  }

  Future<List<CustomerPointsLog>> getPointsLog(int customerId) =>
      _pointsDao.getByCustomer(customerId);

  Future<int> getUnsettledPoints(int customerId) =>
      _pointsDao.getTotalUnsettledPoints(customerId);

  /// Settles a single points-log entry and deducts the points from the customer.
  ///
  /// Both operations must succeed — if either fails an exception is thrown so
  /// the UI can surface the error to the user.
  Future<void> settlePointsEntry(
      int entryId, int customerId, int points) async {
    debugPrint('[CustomerProvider] settlePointsEntry: entryId=$entryId, customerId=$customerId, points=$points');
    await _pointsDao.settleEntry(entryId, customerId, points);
    debugPrint('[CustomerProvider] settlePointsEntry: RPC complete');

    final index = _customers.indexWhere((customer) => customer.id == customerId);
    if (index != -1) {
      final current = _customers[index].points;
      debugPrint('[CustomerProvider] settlePointsEntry: patching customer points from $current to ${(current - points).clamp(0, 2147483647)}');
      _patchCustomerPoints(customerId, (current - points).clamp(0, 2147483647));
    }
  }

  /// Settles ALL unsettled entries for a customer.
  Future<void> settleAllPoints(int customerId) async {
    debugPrint('[CustomerProvider] settleAllPoints: customerId=$customerId');
    final unsettled = await _pointsDao.getTotalUnsettledPoints(customerId);
    debugPrint('[CustomerProvider] settleAllPoints: unsettled=$unsettled');
    if (unsettled == 0) {
      debugPrint('[CustomerProvider] settleAllPoints: nothing to settle');
      return;
    }

    await _pointsDao.settleAllForCustomer(customerId);
    debugPrint('[CustomerProvider] settleAllPoints: RPC complete');

    final index = _customers.indexWhere((customer) => customer.id == customerId);
    if (index != -1) {
      final current = _customers[index].points;
      debugPrint('[CustomerProvider] settleAllPoints: patching customer points from $current to ${(current - unsettled).clamp(0, 2147483647)}');
      _patchCustomerPoints(customerId, (current - unsettled).clamp(0, 2147483647));
    }
  }

  Future<List<Map<String, dynamic>>> getDebtors() => _dao.getDebtors();

  String priceTypeName(String type) {
    switch (type) {
      case 'wholesale':
        return 'جملة';
      case 'semi_wholesale':
        return 'نصف جملة';
      case 'special':
        return 'خاص';
      default:
        return 'قطاعي';
    }
  }

  String customerTypeName(String type) {
    switch (type) {
      case 'technician':
        return 'فني';
      case 'engineer':
        return 'مهندس';
      default:
        return 'عادي';
    }
  }
}
