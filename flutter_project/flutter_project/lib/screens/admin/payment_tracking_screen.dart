import 'package:flutter/material.dart';
import '../../database/daos/customer_dao.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/daos/installment_dao.dart';
import '../../models/customer.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class PaymentTrackingScreen extends StatefulWidget {
  const PaymentTrackingScreen({super.key});

  @override
  State<PaymentTrackingScreen> createState() =>
      _PaymentTrackingScreenState();
}

class _PaymentTrackingScreenState extends State<PaymentTrackingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dao = CustomerDao();
    final all = await dao.getAll();
    if (mounted) setState(() {
      _customers = all.where((c) => c.isApproved).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('متابعة الدفعات'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'فواتير بانتظار الموافقة'),
            Tab(text: 'دفعات بانتظار الموافقة'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _PendingInvoicesTab(customers: _customers),
                _PendingPaymentsTab(customers: _customers),
              ],
            ),
    );
  }
}

// ─── Pending Invoices ─────────────────────────────────────────────────────────

class _PendingInvoicesTab extends StatefulWidget {
  final List<Customer> customers;

  const _PendingInvoicesTab({required this.customers});

  @override
  State<_PendingInvoicesTab> createState() => _PendingInvoicesTabState();
}

class _PendingInvoicesTabState extends State<_PendingInvoicesTab> {
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dao = CustomerDao();
    final all = <Map<String, dynamic>>[];
    for (final c in widget.customers) {
      if (c.id == null) continue;
      final invs = await dao.getCustomerInvoices(c.id!);
      for (final inv in invs) {
        all.add({...inv, 'customer_name': c.name, 'customer': c});
      }
    }
    all.sort((a, b) =>
        (b['created_at'] as String? ?? '')
            .compareTo(a['created_at'] as String? ?? ''));
    if (mounted) setState(() {
      _invoices = all;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _pending =>
      _invoices.where((i) => i['status'] == 'pending').toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text('لا توجد فواتير بانتظار الموافقة',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pending.length,
      itemBuilder: (_, i) {
        final inv = _pending[i];
        final customer = inv['customer'] as Customer;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange.shade50,
                      child: const Icon(Icons.receipt_long,
                          color: Colors.orange, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inv['invoice_no'] as String? ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Text(inv['customer_name'] as String? ?? '',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(
                      AppFormatters.formatCurrency(
                          (inv['total'] as num? ?? 0).toDouble()),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(AppColors.primaryInt)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      (inv['payment_method'] as String?) ==
                              AppConstants.paymentMethodReceipt
                          ? Icons.upload_file
                          : Icons.store,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      (inv['payment_method'] as String?) ==
                              AppConstants.paymentMethodReceipt
                          ? 'إيصال مرفق'
                          : 'دفع في المحل',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      AppFormatters.formatDateFromString(
                          inv['date'] as String?),
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                if (inv['notes'] != null) ...[
                  const SizedBox(height: 4),
                  Text(inv['notes'] as String,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () =>
                            _updateStatus(inv['id'] as int, 'approved'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('قبول'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        onPressed: () =>
                            _updateStatus(inv['id'] as int, 'rejected'),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('رفض'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(int id, String status) async {
    final dao = CustomerDao();
    await dao.updateInvoiceStatus(id, status);
    _load();
  }
}

// ─── Pending Payments ─────────────────────────────────────────────────────────

class _PendingPaymentsTab extends StatefulWidget {
  final List<Customer> customers;

  const _PendingPaymentsTab({required this.customers});

  @override
  State<_PendingPaymentsTab> createState() => _PendingPaymentsTabState();
}

class _PendingPaymentsTabState extends State<_PendingPaymentsTab> {
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dao = CustomerDao();
    final all = <Map<String, dynamic>>[];
    for (final c in widget.customers) {
      if (c.id == null) continue;
      final pays = await dao.getCustomerPayments(c.id!);
      for (final p in pays) {
        all.add({...p, 'customer_name': c.name, 'customer': c});
      }
    }
    all.sort((a, b) =>
        (b['created_at'] as String? ?? '')
            .compareTo(a['created_at'] as String? ?? ''));
    if (mounted) setState(() {
      _payments = all;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _pending =>
      _payments.where((p) => p['status'] == 'pending').toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text('لا توجد دفعات بانتظار الموافقة',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pending.length,
      itemBuilder: (_, i) {
        final p = _pending[i];
        final method = p['payment_method'] as String?;
        final isInstallmentReq = method == 'installment_request';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isInstallmentReq
                          ? Colors.purple.shade50
                          : Colors.blue.shade50,
                      child: Icon(
                        isInstallmentReq
                            ? Icons.credit_card
                            : Icons.payments,
                        color: isInstallmentReq
                            ? Colors.purple
                            : Colors.blue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['customer_name'] as String? ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isInstallmentReq
                                ? 'طلب تقسيط'
                                : method ==
                                        AppConstants.paymentMethodReceipt
                                    ? 'إيصال مرفق'
                                    : 'دفع في المحل',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormatters.formatCurrency(
                              (p['amount'] as num? ?? 0).toDouble()),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(AppColors.primaryInt)),
                        ),
                        Text(
                          AppFormatters.formatDateFromString(
                              p['date'] as String?),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                if (p['notes'] != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p['notes'] as String,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () =>
                            _updateStatus(p['id'] as int, 'approved'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('قبول'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        onPressed: () =>
                            _updateStatus(p['id'] as int, 'rejected'),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('رفض'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(int id, String status) async {
    final dao = CustomerDao();
    await dao.updatePaymentStatus(id, status);

    if (status == 'approved') {
      final payment = _payments.firstWhere(
        (p) => p['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      final installmentId = payment['installment_id'] as int?;
      final customerId = payment['customer_id'] as int?;
      final amt = (payment['amount'] as num? ?? 0).toDouble();
      final payDate = payment['date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10);

      if (installmentId != null) {
        final instDao = InstallmentDao();
        final instPayments = await instDao.getPayments(installmentId);
        final unpaid = instPayments.where((p) => !p.isPaid).toList();
        if (unpaid.isNotEmpty && unpaid.first.id != null) {
          await instDao.markPaymentPaid(unpaid.first.id!);
          await instDao.checkAndUpdateInstallmentStatus(installmentId);
        }
      }

      if (customerId != null) {
        try {
          await Supabase.instance.client.from('notifications').insert({
            'target_type': 'customer',
            'target_id': customerId,
            'title': 'تم تأكيد دفعتك ✓',
            'body': 'تم استلام دفعتك بمبلغ ${amt.toStringAsFixed(0)} ج.م بتاريخ $payDate وتسجيلها في حسابك.',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'approved' ? 'تم قبول الدفعة وإخطار العميل ✓' : 'تم رفض الدفعة'),
        backgroundColor: status == 'approved' ? Colors.green : Colors.red,
      ));
    }

    _load();
  }
}
