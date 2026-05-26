import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/installment_provider.dart';
import '../../../providers/sales_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../models/customer.dart';
import '../../../models/installment.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import 'customer_points_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  List<Installment> _installments = [];
  List<dynamic> _invoices = [];
  bool _loading = true;
  late Customer _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final from =
          DateTime(now.year - 1).toIso8601String().substring(0, 10);
      final to = now.toIso8601String().substring(0, 10);

      final results = await Future.wait([
        context
            .read<InstallmentProvider>()
            .getByCustomer(_customer.id!),
        context.read<SalesProvider>().getInvoices(
              customerId: _customer.id!,
              fromDate: from,
              toDate: to,
            ),
        // Always fetch fresh customer data so the points badge stays current
        context.read<CustomerProvider>().getById(_customer.id!),
      ]);

      if (mounted) {
        setState(() {
          _installments = results[0] as List<Installment>;
          _invoices = results[1] as List<dynamic>;
          final fresh = results[2] as Customer?;
          if (fresh != null) _customer = fresh;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل بيانات العميل: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  double get _totalSales =>
      _invoices.fold(0.0, (s, inv) => s + (inv.total as num).toDouble());

  double get _totalPaid =>
      _invoices.fold(0.0, (s, inv) => s + ((inv.amountPaid ?? 0) as num).toDouble());

  double get _totalInstallmentsRemaining =>
      _installments.fold(0.0, (s, i) => s + i.remaining);

  int get _activeInstallments =>
      _installments.where((i) => i.status != 'completed').length;

  Future<void> _generateCode() async {
    final provider = context.read<CustomerProvider>();
    final code =
        await provider.generateAndSaveLoginCode(_customer.id!);
    if (mounted) {
      setState(() {
        _customer = _customer.copyWith(loginCode: code);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تم إنشاء الكود: $code'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _sendViaWhatsApp() async {
    if (_customer.loginCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أنشئ كود الدخول أولاً')),
      );
      return;
    }
    final provider = context.read<CustomerProvider>();
    final sent = await provider.sendCodeViaWhatsApp(
        _customer, _customer.loginCode!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(sent ? 'تم فتح واتساب' : 'لا يوجد رقم هاتف'),
            backgroundColor: sent ? Colors.green : Colors.red),
      );
    }
  }

  Future<void> _callCustomer() async {
    final phone = _customer.phone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (_) => _EditCustomerDialog(
        customer: _customer,
        onSaved: (updated) => setState(() => _customer = updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider so the points badge updates the moment an invoice is saved
    final providerList = context.watch<CustomerProvider>().customers;
    final live = providerList.where((c) => c.id == _customer.id).firstOrNull;
    if (live != null) _customer = live;

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer.name),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          if (_customer.phone != null)
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: _callCustomer,
              tooltip: 'اتصال',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CustomerHeaderCard(customer: _customer),
                  const SizedBox(height: 16),
                  _FinancialSummaryGrid(
                    totalSales: _totalSales,
                    totalPaid: _totalPaid,
                    activeInstallments: _activeInstallments,
                    remainingInstallments: _totalInstallmentsRemaining,
                  ),
                  const SizedBox(height: 16),
                  _LoginCodeCard(
                    customer: _customer,
                    onGenerate: _generateCode,
                    onSendWhatsApp: _sendViaWhatsApp,
                  ),
                  const SizedBox(height: 16),
                  _PointsCard(customer: _customer),
                  const SizedBox(height: 16),
                  _InstallmentsSummaryCard(installments: _installments),
                  const SizedBox(height: 16),
                  _RecentInvoicesCard(invoices: _invoices),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ─── Customer Header Card ─────────────────────────────────────────────────────

class _CustomerHeaderCard extends StatelessWidget {
  final Customer customer;

  const _CustomerHeaderCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor:
                  const Color(AppColors.primaryInt).withValues(alpha: 0.1),
              child: Text(
                customer.name.isNotEmpty ? customer.name[0] : '?',
                style: const TextStyle(
                    fontSize: 28,
                    color: Color(AppColors.primaryInt),
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  if (customer.phone != null)
                    Text(customer.phone!,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13)),
                  if (customer.address != null)
                    Text(customer.address!,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (_priceLabel(customer.priceType).isNotEmpty)
                        _Badge(_priceLabel(customer.priceType), Colors.blue),
                      if (_typeLabel(customer.customerType).isNotEmpty)
                        _Badge(_typeLabel(customer.customerType), Colors.teal),
                      if (_statusLabel(customer.customerStatus).isNotEmpty)
                        _Badge(
                          _statusLabel(customer.customerStatus),
                          _statusColor(customer.customerStatus),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priceLabel(String t) {
    switch (t) {
      case 'wholesale':
        return 'جملة';
      case 'semi_wholesale':
        return 'نصف جملة';
      default:
        return '';
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'technician':
        return 'فني';
      case 'engineer':
        return 'مهندس';
      default:
        return '';
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'vip':
        return '⭐ VIP';
      case 'blacklist':
        return '🚫 محظور';
      default:
        return '';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'vip':
        return Colors.amber.shade700;
      case 'blacklist':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Financial Summary ────────────────────────────────────────────────────────

class _FinancialSummaryGrid extends StatelessWidget {
  final double totalSales;
  final double totalPaid;
  final double remainingInstallments;
  final int activeInstallments;

  const _FinancialSummaryGrid({
    required this.totalSales,
    required this.totalPaid,
    required this.remainingInstallments,
    required this.activeInstallments,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: [
        _SummaryCard(
          label: 'إجمالي المبيعات',
          value: AppFormatters.formatCurrency(totalSales),
          icon: Icons.trending_up,
          color: Colors.green,
        ),
        _SummaryCard(
          label: 'المحصّل',
          value: AppFormatters.formatCurrency(totalPaid),
          icon: Icons.payments,
          color: Colors.blue,
        ),
        _SummaryCard(
          label: 'أقساط نشطة',
          value: '$activeInstallments قسط',
          icon: Icons.payment,
          color: Colors.orange,
        ),
        _SummaryCard(
          label: 'متبقي الأقساط',
          value: AppFormatters.formatCurrency(remainingInstallments),
          icon: Icons.pending_actions,
          color: Colors.deepOrange,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Login Code Card ──────────────────────────────────────────────────────────

class _LoginCodeCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onGenerate;
  final VoidCallback onSendWhatsApp;

  const _LoginCodeCard({
    required this.customer,
    required this.onGenerate,
    required this.onSendWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.key, color: Colors.blue),
            title: const Text('كود تسجيل الدخول'),
            subtitle: customer.loginCode != null
                ? Text('الكود الحالي: ${customer.loginCode}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green))
                : const Text('لم يُنشأ بعد',
                    style: TextStyle(color: Colors.grey)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
              ),
              onPressed: onGenerate,
              child: const Text('إنشاء', style: TextStyle(fontSize: 12)),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.chat, color: Colors.green),
            title: const Text('إرسال الكود عبر واتساب'),
            trailing: const Icon(Icons.send, color: Colors.green),
            onTap: onSendWhatsApp,
          ),
        ],
      ),
    );
  }
}

// ─── Installments Summary ─────────────────────────────────────────────────────

class _InstallmentsSummaryCard extends StatelessWidget {
  final List<Installment> installments;

  const _InstallmentsSummaryCard({required this.installments});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الأقساط',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${installments.length} إجمالي',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            if (installments.isEmpty)
              const Text('لا توجد أقساط',
                  style: TextStyle(color: Colors.grey))
            else
              ...installments.map((inst) {
                final progress = inst.totalInstallmentPrice > 0
                    ? (1 -
                            (inst.remaining / inst.totalInstallmentPrice))
                        .clamp(0.0, 1.0)
                    : 1.0;
                final isCompleted = inst.status == 'completed';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(inst.productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isCompleted ? 'مكتمل' : 'نشط',
                              style: TextStyle(
                                  color: isCompleted
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade200,
                              color: isCompleted
                                  ? Colors.green
                                  : const Color(AppColors.primaryInt),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${AppFormatters.formatCurrency(inst.monthlyAmount)}/شهر',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            'متبقي: ${AppFormatters.formatCurrency(inst.remaining)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      if (inst != installments.last)
                        const Divider(height: 16),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Invoices ──────────────────────────────────────────────────────────

class _RecentInvoicesCard extends StatelessWidget {
  final List<dynamic> invoices;

  const _RecentInvoicesCard({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('آخر الفواتير',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${invoices.length} فاتورة',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            if (invoices.isEmpty)
              const Text('لا توجد فواتير',
                  style: TextStyle(color: Colors.grey))
            else
              ...invoices.take(10).map((inv) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFE8EAF6),
                      child: Icon(Icons.receipt,
                          color: Color(AppColors.primaryInt), size: 18),
                    ),
                    title: Text(inv.invoiceNo,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                        AppFormatters.formatDateFromString(inv.date),
                        style: const TextStyle(fontSize: 11)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormatters.formatCurrency(
                              (inv.total as num).toDouble()),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if ((inv.remaining as num) > 0)
                          Text(
                            'متبقي: ${AppFormatters.formatCurrency((inv.remaining as num).toDouble())}',
                            style: const TextStyle(
                                color: Colors.red, fontSize: 10),
                          ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Customer Dialog ─────────────────────────────────────────────────────

class _EditCustomerDialog extends StatefulWidget {
  final Customer customer;
  final void Function(Customer) onSaved;

  const _EditCustomerDialog(
      {required this.customer, required this.onSaved});

  @override
  State<_EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<_EditCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late String _customerType;
  late String _priceType;
  late String _customerStatus;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.customer.name);
    _phoneCtrl =
        TextEditingController(text: widget.customer.phone);
    _addressCtrl =
        TextEditingController(text: widget.customer.address);
    _customerType = widget.customer.customerType;
    _priceType = widget.customer.priceType;
    _customerStatus = widget.customer.customerStatus;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final updated = widget.customer.copyWith(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty
          ? null
          : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      customerType: _customerType,
      priceType: _priceType,
      customerStatus: _customerStatus,
    );
    await context.read<CustomerProvider>().updateCustomer(updated);
    if (mounted) {
      widget.onSaved(updated);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل العميل'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'الهاتف'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _customerType,
                decoration:
                    const InputDecoration(labelText: 'نوع العميل'),
                items: const [
                  DropdownMenuItem(
                      value: 'regular', child: Text('عادي')),
                  DropdownMenuItem(
                      value: 'technician', child: Text('فني')),
                  DropdownMenuItem(
                      value: 'engineer', child: Text('مهندس')),
                ],
                onChanged: (v) =>
                    setState(() => _customerType = v ?? _customerType),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _priceType,
                decoration:
                    const InputDecoration(labelText: 'نوع السعر'),
                items: const [
                  DropdownMenuItem(
                      value: 'retail', child: Text('قطاعي')),
                  DropdownMenuItem(
                      value: 'semi_wholesale', child: Text('نصف جملة')),
                  DropdownMenuItem(
                      value: 'wholesale', child: Text('جملة')),
                ],
                onChanged: (v) =>
                    setState(() => _priceType = v ?? _priceType),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _customerStatus,
                decoration: const InputDecoration(labelText: 'حالة العميل'),
                items: const [
                  DropdownMenuItem(value: 'regular', child: Text('عادي')),
                  DropdownMenuItem(
                    value: 'vip',
                    child: Row(children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      SizedBox(width: 6),
                      Text('VIP — عميل مميز'),
                    ]),
                  ),
                  DropdownMenuItem(
                    value: 'blacklist',
                    child: Row(children: [
                      Icon(Icons.block, color: Colors.red, size: 16),
                      SizedBox(width: 6),
                      Text('محظور — ممنوع من الدخول'),
                    ]),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _customerStatus = v ?? _customerStatus),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(onPressed: _save, child: const Text('حفظ')),
      ],
    );
  }
}

// ─── Points Card ──────────────────────────────────────────────────────────────

class _PointsCard extends StatelessWidget {
  final Customer customer;

  const _PointsCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CustomerPointsScreen(customer: customer)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.stars, color: Colors.amber, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('نقاط المبيعات',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      'رصيد النقاط: ${customer.points} نقطة',
                      style: const TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    const Text(
                      'اضغط لعرض سجل النقاط وتسويتها',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
