import 'package:flutter/foundation.dart';
import '../models/partner.dart';
import '../database/daos/partner_dao.dart';

class PartnerProvider extends ChangeNotifier {
  final PartnerDao _dao = PartnerDao();

  List<Partner> _partners = [];
  bool _loading = false;
  double _adminFeeRate = 0.05;

  List<Partner> get partners => _partners;
  bool get loading => _loading;
  double get adminFeeRate => _adminFeeRate;

  int get totalShares =>
      _partners.fold(0, (s, p) => s + p.shares);

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    _partners = await _dao.getAll();
    _loading = false;
    notifyListeners();
  }

  Future<int> addPartner(Partner p) async {
    final id = await _dao.insertPartner(p);
    await loadAll();
    return id;
  }

  Future<void> updatePartner(Partner p) async {
    await _dao.update(p);
    await loadAll();
  }

  Future<int> recordTransaction(PartnerTransaction t) async {
    final id = await _dao.insertTransaction(t);
    notifyListeners();
    return id;
  }

  Future<List<PartnerTransaction>> getTransactions({
    String? fromDate,
    String? toDate,
  }) =>
      _dao.getTransactions(fromDate: fromDate, toDate: toDate);

  Future<Map<String, dynamic>> calculateProfitDistribution(
      double totalProfit) =>
      _dao.getProfitDistribution(
        totalProfit: totalProfit,
        adminFeeRate: _adminFeeRate,
      );

  void setAdminFeeRate(double rate) {
    _adminFeeRate = rate;
    notifyListeners();
  }

  double partnerSharePercentage(Partner p) {
    if (totalShares == 0) return 0;
    return (p.shares / totalShares) * 100;
  }

  double partnerProfitShare(Partner p, double distributable) {
    if (totalShares == 0) return 0;
    return (p.shares / totalShares) * distributable;
  }
}
