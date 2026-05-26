import 'package:flutter/foundation.dart';
import '../models/installment.dart';
import '../models/app_settings.dart';
import '../database/daos/installment_dao.dart';
import '../database/daos/customer_dao.dart';
import '../database/daos/app_settings_dao.dart';
import '../database/daos/partner_group_dao.dart';

class InstallmentProvider extends ChangeNotifier {
  final InstallmentDao _dao = InstallmentDao();
  final CustomerDao _customerDao = CustomerDao();
  final AppSettingsDao _settingsDao = AppSettingsDao();
  final PartnerGroupDao _groupDao = PartnerGroupDao();

  List<Map<String, dynamic>> _installments = [];
  bool _loading = false;
  AppSettings _settings = const AppSettings();

  List<Map<String, dynamic>> get installments => _installments;
  bool get loading => _loading;
  AppSettings get settings => _settings;

  Future<void> loadSettings() async {
    _settings = await _settingsDao.getSettings();
    notifyListeners();
  }

  Future<void> loadAll({String? status, String? storeType}) async {
    _loading = true;
    notifyListeners();
    _installments = await _dao.getInstallmentsWithCustomer(
        status: status, storeType: storeType);
    _loading = false;
    notifyListeners();
  }

  Future<void> loadByCustomer(int customerId, {String? storeType}) async {
    _loading = true;
    notifyListeners();
    final all = await _dao.getInstallmentsWithCustomer(storeType: storeType);
    _installments = all.where((m) => m['customer_id'] == customerId).toList();
    _loading = false;
    notifyListeners();
  }

  Future<int> createInstallment({
    required int customerId,
    required String productName,
    required double purchasePrice,
    required double salePrice,
    required int numInstallments,
    required double downPayment,
    int? itemId,
    int? invoiceId,
    String storeType = 'installment',
    int? partnerGroupId,
    double? customInstallmentRate,
    String? startDateOverride,
  }) async {
    final now = DateTime.now();

    final rate = customInstallmentRate ?? _settings.rateForMonths(numInstallments);
    final totalPrice = salePrice * (1.0 + rate / 100.0);
    final remaining = totalPrice - downPayment;
    final monthly = remaining / numInstallments;

    DateTime startDt = now;
    if (startDateOverride != null) {
      try { startDt = DateTime.parse(startDateOverride.replaceAll('/', '-')); } catch (_) {}
    }
    final endDt = DateTime(startDt.year, startDt.month + numInstallments, startDt.day);

    final installmentId = await _dao.insertInstallment(Installment(
      customerId: customerId,
      itemId: itemId,
      invoiceId: invoiceId,
      productName: productName,
      purchasePrice: purchasePrice,
      salePrice: salePrice,
      totalInstallmentPrice: totalPrice,
      downPayment: downPayment,
      numInstallments: numInstallments,
      monthlyAmount: monthly,
      startDate: startDt.toIso8601String().substring(0, 10),
      endDate: endDt.toIso8601String().substring(0, 10),
      createdAt: now.toIso8601String(),
      storeType: storeType,
      partnerGroupId: partnerGroupId,
      installmentRate: rate,
    ));

    final payments = InstallmentDao.generatePaymentSchedule(
      installmentId: installmentId,
      numInstallments: numInstallments,
      monthlyAmount: monthly,
      startDate: DateTime(startDt.year, startDt.month + 1, startDt.day),
    );
    for (final p in payments) {
      await _dao.insertPayment(p);
    }

    // ── خصم تكلفة المنتج من رأس مال الجروب تلقائياً ─────────────────────────
    if (partnerGroupId != null && purchasePrice > 0) {
      try {
        await _groupDao.deductProductCostFromCapital(
          groupId: partnerGroupId,
          cost: purchasePrice,
          productName: productName,
          date: now.toIso8601String().substring(0, 10),
        );
      } catch (_) {}
    }

    // ── خصم المقدم من رصيد العميل ────────────────────────────────────────────
    if (downPayment > 0) {
      final customer = await _customerDao.findById(customerId);
      if (customer != null) {
        await _customerDao.updateBalance(customerId, customer.balance - downPayment);
        // إذا كان للتقسيط جروب — يضاف المقدم كـ in
        if (partnerGroupId != null) {
          try {
            final customerName = customer.name;
            await _groupDao.addCollectedInstallmentToBalance(
              groupId: partnerGroupId,
              amount: downPayment,
              customerName: customerName,
              productName: '$productName (مقدم)',
              date: now.toIso8601String().substring(0, 10),
            );
          } catch (_) {}
        }
      }
    }

    await loadAll();
    return installmentId;
  }

  Future<List<InstallmentPayment>> getPayments(int installmentId) =>
      _dao.getPayments(installmentId);

  Future<Installment?> getById(int id) => _dao.findById(id);

  Future<List<Installment>> getByCustomer(int customerId) =>
      _dao.getByCustomer(customerId);

  /// تسجيل الدفع الكامل وإضافة المبلغ لرصيد الجروب تلقائياً
  Future<void> markPaymentPaid(int paymentId, int installmentId, {
    String paymentMethod = 'in_store',
    String? receiptPath,
  }) async {
    await _dao.markPaymentPaid(
      paymentId,
      paymentMethod: paymentMethod,
      receiptPath: receiptPath,
    );
    await _dao.checkAndUpdateInstallmentStatus(installmentId);

    // ── إضافة الأقساط المحصلة لرصيد الجروب تلقائياً ─────────────────────────
    try {
      final installment = await _dao.findById(installmentId);
      if (installment != null && installment.partnerGroupId != null) {
        final payments = await _dao.getPayments(installmentId);
        final payment = payments.firstWhere((p) => p.id == paymentId,
            orElse: () => payments.first);
        final amount = payment.amount + payment.carriedAmount;
        final customer = await _customerDao.findById(installment.customerId);
        await _groupDao.addCollectedInstallmentToBalance(
          groupId: installment.partnerGroupId!,
          amount: amount,
          customerName: customer?.name ?? 'عميل',
          productName: installment.productName,
        );
      }
    } catch (_) {}

    await loadAll();
  }

  /// دفع جزئي مع ترحيل الباقي للقسط التالي
  Future<void> partialPayment(
    int paymentId,
    int installmentId,
    double paidAmount, {
    String? notes,
  }) async {
    await _dao.partialPayment(paymentId, paidAmount, notes: notes);
    await _dao.checkAndUpdateInstallmentStatus(installmentId);

    // ── إضافة المبلغ الجزئي المحصّل لرصيد الجروب ─────────────────────────────
    try {
      final installment = await _dao.findById(installmentId);
      if (installment != null && installment.partnerGroupId != null && paidAmount > 0) {
        final customer = await _customerDao.findById(installment.customerId);
        await _groupDao.addCollectedInstallmentToBalance(
          groupId: installment.partnerGroupId!,
          amount: paidAmount,
          customerName: customer?.name ?? 'عميل',
          productName: '${installment.productName} (جزئي)',
        );
      }
    } catch (_) {}

    await loadAll();
  }

  /// تأجيل القسط لشهر آخر مع تسجيل السبب
  Future<void> postponePayment(
    int paymentId,
    int installmentId,
    String reason,
  ) async {
    await _dao.postponePayment(paymentId, reason);
    await loadAll();
  }

  Future<List<InstallmentPayment>> getOverduePayments() =>
      _dao.getOverduePayments();

  Future<List<InstallmentPayment>> getOverduePaymentsByMonth(
          int year, int month) =>
      _dao.getOverduePaymentsByMonth(year, month);

  Future<Map<String, dynamic>> getSummary(int installmentId) =>
      _dao.getInstallmentSummary(installmentId);

  static Map<String, dynamic> calculateInstallment({
    required double salePrice,
    required double purchasePrice,
    required int numInstallments,
    required double downPayment,
    double installmentRatePct = 10.0,
  }) {
    final rate = installmentRatePct / 100.0;
    final totalPrice = salePrice * (1.0 + rate);
    final remaining = totalPrice - downPayment;
    final monthly = remaining / numInstallments;
    final installmentFee = totalPrice - salePrice;
    final profitMargin = salePrice - purchasePrice;
    return {
      'total_price': totalPrice,
      'installment_fee': installmentFee,
      'remaining': remaining,
      'monthly_amount': monthly,
      'profit_margin': profitMargin,
      'rate_pct': installmentRatePct,
    };
  }
}
