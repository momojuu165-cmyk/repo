import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/installment_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/customer.dart';
import '../../models/installment.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class CustomerInstallmentsScreen extends StatefulWidget {
  final Customer? customer;

  const CustomerInstallmentsScreen({super.key, this.customer});

  @override
  State<CustomerInstallmentsScreen> createState() =>
      _CustomerInstallmentsScreenState();
}

class _CustomerInstallmentsScreenState
    extends State<CustomerInstallmentsScreen> {
  List<Installment> _installments = [];
  List<InstallmentPayment> _allPayments = [];
  bool _loading = true;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('customer_installments_payments')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'installment_payments',
          callback: (_) {
            if (mounted) _load();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'installments',
          callback: (_) {
            if (mounted) _load();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final customerId =
        widget.customer?.id ?? auth.currentCustomer?.id;
    if (customerId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final provider = context.read<InstallmentProvider>();
    final items = await provider.getByCustomer(customerId);

    final List<InstallmentPayment> allPayments = [];
    for (final inst in items) {
      if (inst.id != null) {
        final payments = await provider.getPayments(inst.id!);
        allPayments.addAll(payments);
      }
    }

    if (mounted) {
      setState(() {
        _installments = items;
        _allPayments = allPayments;
        _loading = false;
      });
    }
  }

  double get _totalAmount =>
      _installments.fold(0.0, (s, i) => s + i.totalInstallmentPrice);

  double get _totalPaid {
    double paid = 0;
    for (final inst in _installments) {
      final payments =
          _allPayments.where((p) => p.installmentId == inst.id && p.isPaid);
      paid += payments.fold(0.0, (s, p) => s + p.amount);
    }
    paid += _installments.fold(0.0, (s, i) => s + (i.downPayment));
    return paid;
  }

  double get _totalRemaining =>
      (_totalAmount - _totalPaid).clamp(0.0, double.infinity);

  int get _overdueCount =>
      _allPayments.where((p) => !p.isPaid && p.isOverdue).length;

  Future<void> _showPaymentDialog(BuildContext ctx) async {
    final activeInst = _installments.where((i) => i.status == 'active').toList();
    if (activeInst.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('لا توجد أقساط نشطة للدفع')));
      return;
    }
    Installment? selectedInst = activeInst.length == 1 ? activeInst.first : null;
    String? receiptPath;
    final notesCtrl = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (dlgCtx, setS) => AlertDialog(
        title: const Row(children: [Icon(Icons.payment, color: Colors.orange), SizedBox(width: 8), Text('رفع دفعة للموافقة')]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (activeInst.length > 1) ...[
            const Text('اختر القسط:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Installment>(
              value: selectedInst,
              decoration: const InputDecoration(labelText: 'القسط', border: OutlineInputBorder(), isDense: true),
              items: activeInst.map((i) => DropdownMenuItem(value: i, child: Text(i.productName))).toList(),
              onChanged: (v) => setS(() => selectedInst = v),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () async {
              final picker = ImagePicker();
              final xfile = await picker.pickImage(source: ImageSource.gallery);
              if (xfile != null) setS(() => receiptPath = xfile.path);
            },
            icon: const Icon(Icons.upload_file),
            label: Text(receiptPath != null ? 'تم رفع الإيصال ✓' : 'رفع صورة الإيصال'),
          ),
          if (receiptPath != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(receiptPath!), height: 100, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder(), isDense: true),
            maxLines: 2,
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: submitting ? null : () async {
              if (selectedInst == null) {
                ScaffoldMessenger.of(dlgCtx).showSnackBar(const SnackBar(content: Text('اختر القسط أولاً')));
                return;
              }
              setS(() => submitting = true);
              try {
                final customerId = widget.customer?.id ?? context.read<AuthProvider>().currentCustomer?.id;
                final now = DateTime.now();
                await Supabase.instance.client.from('customer_payments').insert({
                  'customer_id': customerId,
                  'installment_id': selectedInst!.id,
                  'amount': selectedInst!.monthlyAmount,
                  'payment_method': 'receipt',
                  'receipt_path': receiptPath,
                  'status': 'pending',
                  'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  'date': now.toIso8601String().substring(0, 10),
                  'created_at': now.toIso8601String(),
                });
                if (dlgCtx.mounted) {
                  Navigator.pop(dlgCtx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('تم إرسال الدفعة بنجاح، في انتظار موافقة الإدارة'), backgroundColor: Colors.green));
                }
              } catch (e) {
                setS(() => submitting = false);
                ScaffoldMessenger.of(dlgCtx).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
              }
            },
            child: submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('إرسال'),
          ),
        ],
      )),
    );
  }

  InstallmentPayment? get _nextPayment {
    final upcoming = _allPayments
        .where((p) => !p.isPaid && !p.isOverdue)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _InstallmentsDashboardHeader(
            totalAmount: _totalAmount,
            totalPaid: _totalPaid,
            totalRemaining: _totalRemaining,
            overdueCount: _overdueCount,
            nextPayment: _nextPayment,
            activeCount: _installments
                .where((i) => i.status != 'completed')
                .length,
          ),
          if (_installments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment_outlined,
                        size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('لا توجد أقساط',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            ...(_installments.map((inst) => _InstallmentCard(
                  installment: inst,
                  payments: _allPayments
                      .where((p) => p.installmentId == inst.id)
                      .toList(),
                ))),
          const SizedBox(height: 80),
        ],
      ),
        ),
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _showPaymentDialog(context),
            icon: const Icon(Icons.upload_file),
            label: const Text('ادفع دفعة — رفع إيصال', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _InstallmentsDashboardHeader extends StatelessWidget {
  final double totalAmount;
  final double totalPaid;
  final double totalRemaining;
  final int overdueCount;
  final int activeCount;
  final InstallmentPayment? nextPayment;

  const _InstallmentsDashboardHeader({
    required this.totalAmount,
    required this.totalPaid,
    required this.totalRemaining,
    required this.overdueCount,
    required this.activeCount,
    required this.nextPayment,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        totalAmount > 0 ? (totalPaid / totalAmount).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(AppColors.primaryInt),
            Color(0xFF283593),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لوحة الأقساط',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                AppFormatters.formatCurrency(totalRemaining),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
              const Text(
                'إجمالي المتبقي',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('نسبة السداد',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _StatBubble(
                    label: 'المدفوع',
                    value: AppFormatters.formatCurrency(totalPaid),
                    icon: Icons.check_circle,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(width: 8),
                  _StatBubble(
                    label: 'الإجمالي',
                    value: AppFormatters.formatCurrency(totalAmount),
                    icon: Icons.receipt_long,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  _StatBubble(
                    label: 'نشطة',
                    value: '$activeCount قسط',
                    icon: Icons.pending_actions,
                    color: Colors.lightBlueAccent,
                  ),
                ],
              ),
              if (overdueCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orangeAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '$overdueCount دفعة متأخرة',
                        style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
              if (nextPayment != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الدفعة القادمة: ${AppFormatters.formatDateFromString(nextPayment!.dueDate)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      Text(
                        AppFormatters.formatCurrency(nextPayment!.amount),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBubble({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
              textAlign: TextAlign.center,
            ),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InstallmentCard extends StatefulWidget {
  final Installment installment;
  final List<InstallmentPayment> payments;

  const _InstallmentCard({
    required this.installment,
    required this.payments,
  });

  @override
  State<_InstallmentCard> createState() => _InstallmentCardState();
}

class _InstallmentCardState extends State<_InstallmentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final inst = widget.installment;
    final payments = widget.payments;
    final paid = payments.where((p) => p.isPaid).length;
    final total = inst.numInstallments;
    final paidAmount = payments.where((p) => p.isPaid).fold(0.0, (s, p) => s + p.amount);
    final actualRemaining = (inst.totalInstallmentPrice - inst.downPayment - paidAmount).clamp(0.0, double.maxFinite);
    final overduePayments = payments.where((p) => !p.isPaid && p.isOverdue);
    final hasOverdue = overduePayments.isNotEmpty;
    final isCompleted = inst.status == 'completed';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : BorderRadius.circular(12),
              color: hasOverdue
                  ? Colors.red.withValues(alpha: 0.05)
                  : isCompleted
                      ? Colors.green.withValues(alpha: 0.05)
                      : null,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isCompleted
                    ? Colors.green.withValues(alpha: 0.1)
                    : hasOverdue
                        ? Colors.red.withValues(alpha: 0.1)
                        : const Color(AppColors.primaryInt).withValues(alpha: 0.1),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : hasOverdue
                          ? Icons.warning_amber
                          : Icons.schedule,
                  color: isCompleted
                      ? Colors.green
                      : hasOverdue
                          ? Colors.red
                          : const Color(AppColors.primaryInt),
                ),
              ),
              title: Text(inst.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppFormatters.formatCurrency(inst.monthlyAmount)} / شهر',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (!isCompleted) ...[
                    const SizedBox(height: 2),
                    Text(
                      'متبقي ${total - paid} شهر من $total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: (total - paid) <= 2 ? Colors.orange.shade700 : Colors.green.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: total > 0 ? paid / total : 0,
                          backgroundColor: Colors.grey.shade200,
                          color: isCompleted
                              ? Colors.green
                              : const Color(AppColors.primaryInt),
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$paid/$total',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  if (hasOverdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${overduePayments.length} دفعة متأخرة',
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () =>
                    setState(() => _expanded = !_expanded),
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MiniStat(
                          'الإجمالي',
                          AppFormatters.formatCurrency(
                              inst.totalInstallmentPrice),
                          Colors.grey.shade700),
                      _MiniStat(
                          'المقدم',
                          AppFormatters.formatCurrency(inst.downPayment),
                          Colors.blue),
                      _MiniStat(
                          'المتبقي',
                          AppFormatters.formatCurrency(actualRemaining),
                          actualRemaining > 0 ? Colors.orange : Colors.green),
                    ],
                  ),
                  const Divider(height: 20),
                  ...payments.map((p) => _PaymentRow(payment: p)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final InstallmentPayment payment;

  const _PaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            payment.isPaid
                ? Icons.check_circle
                : payment.isOverdue
                    ? Icons.warning_amber
                    : Icons.radio_button_unchecked,
            color: payment.isPaid
                ? Colors.green
                : payment.isOverdue
                    ? Colors.red
                    : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppFormatters.formatDateFromString(payment.dueDate),
              style: TextStyle(
                fontSize: 13,
                color: payment.isOverdue && !payment.isPaid
                    ? Colors.red
                    : null,
              ),
            ),
          ),
          if (payment.isPaid && payment.paidDate != null)
            Text(
              'دُفع ${AppFormatters.formatDateFromString(payment.paidDate!)}',
              style: const TextStyle(color: Colors.green, fontSize: 10),
            ),
          if (!payment.isPaid && payment.isOverdue)
            const Text('متأخر',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(
            AppFormatters.formatCurrency(payment.amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: payment.isPaid
                  ? Colors.green
                  : payment.isOverdue
                      ? Colors.red
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
