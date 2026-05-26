import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../database/daos/customer_dao.dart';
import '../../../database/daos/treasury_dao.dart';
import '../../../models/customer.dart';
import '../../../models/treasury.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class CustomerPaymentsScreen extends StatefulWidget {
  const CustomerPaymentsScreen({super.key});

  @override
  State<CustomerPaymentsScreen> createState() => _CustomerPaymentsScreenState();
}

class _CustomerPaymentsScreenState extends State<CustomerPaymentsScreen> {
  final _customerDao = CustomerDao();
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('customer_payments')
          .select('*, customers(name)')
          .order('created_at', ascending: false);
      final mapped = List<Map<String, dynamic>>.from(rows).map((r) {
        final m = Map<String, dynamic>.from(r);
        final c = m['customers'] as Map<String, dynamic>?;
        m['customer_name'] = c?['name'];
        m.remove('customers');
        return m;
      }).toList();
      if (mounted) setState(() { _payments = mapped; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _totalToday {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _payments
        .where((p) => (p['date'] as String? ?? '').startsWith(today))
        .fold(0.0, (s, p) => s + (p['amount'] as num? ?? 0).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دفعات العملاء'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _SummaryHeader(totalToday: _totalToday, totalCount: _payments.length),
                Expanded(
                  child: _payments.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment, size: 64, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('لا توجد دفعات مسجلة', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _payments.length,
                          itemBuilder: (ctx, i) {
                            final p = _payments[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(AppColors.primaryInt),
                                  child: Icon(Icons.payment, color: Colors.white),
                                ),
                                title: Text(
                                  p['customer_name'] as String? ?? 'عميل غير معروف',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${AppFormatters.formatDateFromString(p['date'] as String? ?? '')} | ${p['payment_method'] == 'in_store' ? 'في المتجر' : 'إيصال'}',
                                ),
                                trailing: Text(
                                  AppFormatters.formatCurrency(
                                      (p['amount'] as num? ?? 0).toDouble()),
                                  style: const TextStyle(
                                    color: Color(AppColors.successInt),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showAddPaymentSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('دفعة جديدة'),
      ),
    );
  }

  void _showAddPaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddPaymentSheet(
        customerDao: _customerDao,
        onSaved: _load,
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final double totalToday;
  final int totalCount;

  const _SummaryHeader({required this.totalToday, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(AppColors.primaryInt),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('دفعات اليوم',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  AppFormatters.formatCurrency(totalToday),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('إجمالي الدفعات',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  '$totalCount دفعة',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPaymentSheet extends StatefulWidget {
  final CustomerDao customerDao;
  final VoidCallback onSaved;

  const _AddPaymentSheet({required this.customerDao, required this.onSaved});

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _treasuryDao = TreasuryDao();
  Customer? _selectedCustomer;
  List<Customer> _customers = [];
  List<Treasury> _treasuries = [];
  int? _treasuryId;
  String _paymentMethod = AppConstants.paymentMethodStore;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final customers = await widget.customerDao.getAll();
    final treasuries = await _treasuryDao.getAll();
    if (mounted) {
      setState(() {
        _customers = customers;
        _treasuries = treasuries;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار العميل')));
      return;
    }
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    await Supabase.instance.client.from('customer_payments').insert({
      'customer_id': _selectedCustomer!.id,
      'amount': amount,
      'payment_method': _paymentMethod,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'date': now.substring(0, 10),
      'status': 'completed',
      'created_at': now,
    });
    // Update customer balance
    await widget.customerDao.updateBalance(
        _selectedCustomer!.id!, _selectedCustomer!.balance - amount);
    // Record treasury movement
    if (_treasuryId != null) {
      await _treasuryDao.addMovement(TreasuryMovement(
        treasuryId: _treasuryId!,
        type: 'deposit',
        amount: amount,
        description: 'دفعة من عميل: ${_selectedCustomer!.name}',
        date: now.substring(0, 10),
        createdAt: now,
      ));
    }
    widget.onSaved();
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: _loading
          ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تسجيل دفعة عميل',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Customer>(
                    decoration: const InputDecoration(
                        labelText: 'العميل *', border: OutlineInputBorder()),
                    items: _customers
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                '${c.name} | رصيد: ${AppFormatters.formatCurrency(c.balance)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCustomer = v),
                  ),
                  if (_selectedCustomer != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(AppColors.primaryInt).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('رصيد العميل:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            AppFormatters.formatCurrency(_selectedCustomer!.balance),
                            style: TextStyle(
                              color: _selectedCustomer!.balance > 0
                                  ? const Color(AppColors.dangerInt)
                                  : const Color(AppColors.successInt),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'المبلغ *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(
                        labelText: 'طريقة الدفع', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                          value: AppConstants.paymentMethodStore,
                          child: Text('في المتجر (نقدي)')),
                      DropdownMenuItem(
                          value: AppConstants.paymentMethodReceipt,
                          child: Text('إيصال / تحويل')),
                    ],
                    onChanged: (v) => setState(() => _paymentMethod = v ?? _paymentMethod),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _treasuryId,
                    decoration: const InputDecoration(
                        labelText: 'الخزنة (اختياري)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('— بدون خزنة —')),
                      ..._treasuries
                          .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                    ],
                    onChanged: (v) => setState(() => _treasuryId = v),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'ملاحظات', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppColors.primaryInt),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('تسجيل الدفعة'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
