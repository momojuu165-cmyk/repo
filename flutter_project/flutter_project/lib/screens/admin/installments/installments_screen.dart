import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../providers/installment_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../models/installment.dart';
import '../../../models/customer.dart';
import '../../../models/installment_product.dart';
import '../../../models/partner_group.dart';
import '../../../database/daos/partner_group_dao.dart';
import '../../../database/daos/installment_product_dao.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/whatsapp_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'installment_contract_screen.dart';
import '../../../services/push_notification_service.dart';
import '../../../utils/notification_messages.dart';

class InstallmentsScreen extends StatefulWidget {
  final String? initialStoreType;
  const InstallmentsScreen({super.key, this.initialStoreType});
  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  int _refreshSeq = 0;

  String get _sectionLabel {
    if (widget.initialStoreType == AppConstants.storeElectrical) return 'الكهربائيات';
    if (widget.initialStoreType == AppConstants.storeInstallment) return 'التقسيط';
    return 'الأقساط';
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_sectionLabel),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'نشط'),
            Tab(text: 'مكتمل'),
            Tab(text: 'متأخر'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _InstallmentList(
              key: ValueKey('active_${widget.initialStoreType}_$_refreshSeq'),
              status: 'active',
              storeType: widget.initialStoreType),
          _InstallmentList(
              key: ValueKey('completed_${widget.initialStoreType}_$_refreshSeq'),
              status: 'completed',
              storeType: widget.initialStoreType),
          _OverduePaymentsList(
              key: ValueKey('overdue_${widget.initialStoreType}_$_refreshSeq'),
              storeType: widget.initialStoreType),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showAddInstallmentDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('قسط جديد'),
      ),
    );
  }

  void _showAddInstallmentDialog(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _AddInstallmentSheet(storeType: widget.initialStoreType),
        ))
        .then((_) {
      if (mounted) setState(() => _refreshSeq++);
    });
  }
}

// ─── Installment list tab ────────────────────────────────────────────────────

class _InstallmentList extends StatefulWidget {
  final String? status;
  final String? storeType;
  const _InstallmentList({super.key, this.status, this.storeType});
  @override
  State<_InstallmentList> createState() => _InstallmentListState();
}

class _InstallmentListState extends State<_InstallmentList> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<InstallmentProvider>().loadAll(
          status: widget.status, storeType: widget.storeType);
      if (mounted) {
        setState(() {
          _items = List.from(context.read<InstallmentProvider>().installments);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items.where((m) {
      final name = (m['customer_name'] as String? ?? '').toLowerCase();
      final product = (m['item_name'] as String? ?? (m['product_name'] as String? ?? '')).toLowerCase();
      final phone = (m['customer_phone'] as String? ?? '');
      return name.contains(q) || product.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          const Text('حدث خطأ في تحميل البيانات',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_error!,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة')),
        ]),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو المنتج أو الهاتف...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              Text('${_filtered.length} عقد',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Spacer(),
              Text(
                'إجمالي المتبقي: ${AppFormatters.formatCurrency(_filtered.fold(0.0, (s, m) {
                  final total = ((m['total_price'] ?? m['total_installment_price']) as num? ?? 0).toDouble();
                  final dp = (m['down_payment'] as num? ?? 0).toDouble();
                  final rem = (m['remaining_amount'] as num? ?? (total - dp)).toDouble();
                  return s + rem;
                }))}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ]),
          ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.payment_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      widget.status == 'active'
                          ? 'لا توجد أقساط نشطة'
                          : widget.status == 'completed'
                              ? 'لا توجد أقساط مكتملة'
                              : 'لا توجد أقساط',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) => _InstallmentCard(
                      row: _filtered[i],
                      onChanged: _load,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Installment card ────────────────────────────────────────────────────────

class _InstallmentCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback? onChanged;
  const _InstallmentCard({required this.row, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final installmentId = row['id'] as int;
    final productName =
        (row['item_name'] ?? row['product_name'] ?? '') as String;
    final customerName = row['customer_name'] as String? ?? 'غير محدد';
    final customerPhone = row['customer_phone'] as String?;
    final monthlyAmount = (row['monthly_amount'] as num).toDouble();
    final numInstallments = row['num_installments'] as int;
    final status = row['status'] as String;
    final totalPrice =
        ((row['total_price'] ?? row['total_installment_price']) as num? ?? 0)
            .toDouble();
    final downPayment = (row['down_payment'] as num? ?? 0).toDouble();
    final remainingAmount =
        (row['remaining_amount'] as num? ?? (totalPrice - downPayment))
            .toDouble();
    final startDate = row['start_date'] as String? ?? '';
    final installmentRate = (row['installment_rate'] as num?)?.toDouble();

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'مكتمل';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusLabel = 'ملغي';
        break;
      default:
        statusColor = const Color(AppColors.primaryInt);
        statusLabel = 'نشط';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPaymentsSheet(context, installmentId, customerName,
            monthlyAmount, numInstallments),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header row
            Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    const Color(AppColors.primaryInt).withValues(alpha: 0.1),
                child: const Icon(Icons.person,
                    color: Color(AppColors.primaryInt), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(productName,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      if (customerPhone != null)
                        Text(customerPhone,
                            style: const TextStyle(
                                color: Colors.blue, fontSize: 11)),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                if (installmentRate != null && installmentRate > 0)
                  Text('نسبة: $installmentRate%',
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
            ]),

            const Divider(height: 16),

            // Financial summary
            Row(children: [
              _MiniStat(label: 'الإجمالي', value: AppFormatters.formatCurrency(totalPrice), color: Colors.black87),
              _MiniStat(label: 'المدفوع', value: AppFormatters.formatCurrency(totalPrice - remainingAmount), color: Colors.green),
              _MiniStat(label: 'المتبقي', value: AppFormatters.formatCurrency(remainingAmount), color: remainingAmount > 0 ? Colors.red : Colors.green),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _MiniStat(label: 'القسط الشهري', value: AppFormatters.formatCurrency(monthlyAmount), color: Colors.blue),
              _MiniStat(label: 'عدد الأقساط', value: '$numInstallments شهر', color: Colors.black87),
              _MiniStat(label: 'تاريخ البدء', value: startDate.length >= 10 ? startDate.substring(0, 10) : startDate, color: Colors.black87),
            ]),

            // Action buttons
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (customerPhone != null)
                TextButton.icon(
                  onPressed: () => WhatsAppHelper.sendMessage(
                    phone: customerPhone,
                    message: 'السلام عليكم، تذكير بموعد القسط الشهري ${AppFormatters.formatCurrency(monthlyAmount)}',
                  ),
                  icon: const Icon(Icons.send, size: 14, color: Colors.green),
                  label: const Text('واتساب',
                      style: TextStyle(color: Colors.green, fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => InstallmentContractScreen(
                            installment: Installment.fromMap(row),
                            customerName: customerName,
                            customerPhone: customerPhone))),
                icon: const Icon(Icons.description, size: 14, color: Colors.indigo),
                label: const Text('العقد', style: TextStyle(color: Colors.indigo, fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
              TextButton.icon(
                onPressed: () => _showPaymentsSheet(context, installmentId,
                    customerName, monthlyAmount, numInstallments),
                icon: const Icon(Icons.payment, size: 14, color: Color(AppColors.primaryInt)),
                label: const Text('الأقساط', style: TextStyle(color: Color(AppColors.primaryInt), fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
              TextButton.icon(
                onPressed: () => _confirmDelete(context, installmentId),
                icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                label: const Text('حذف', style: TextStyle(color: Colors.red, fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, int installmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف القسط'),
        content: const Text('هل أنت متأكد من حذف هذا القسط؟ سيتم حذف جميع الأقساط الشهرية المرتبطة به. لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        // Delete child installment_payments first (FK constraint), then the installment
        await Supabase.instance.client
            .from('installment_payments')
            .delete()
            .eq('installment_id', installmentId);
        await Supabase.instance.client
            .from('installments')
            .delete()
            .eq('id', installmentId);
        onChanged?.call();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف القسط بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ أثناء الحذف: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showPaymentsSheet(
    BuildContext context,
    int installmentId,
    String customerName,
    double monthlyAmount,
    int numInstallments,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PaymentsSheet(
        installmentId: installmentId,
        customerName: customerName,
        monthlyAmount: monthlyAmount,
        numInstallments: numInstallments,
        onChanged: onChanged,
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ─── Payments bottom sheet ───────────────────────────────────────────────────

class _PaymentsSheet extends StatefulWidget {
  final int installmentId;
  final String customerName;
  final double monthlyAmount;
  final int numInstallments;
  final VoidCallback? onChanged;

  const _PaymentsSheet({
    required this.installmentId,
    required this.customerName,
    required this.monthlyAmount,
    required this.numInstallments,
    this.onChanged,
  });

  @override
  State<_PaymentsSheet> createState() => _PaymentsSheetState();
}

class _PaymentsSheetState extends State<_PaymentsSheet> {
  List<InstallmentPayment> _payments = [];
  bool _loading = true;
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final payments = await context
        .read<InstallmentProvider>()
        .getPayments(widget.installmentId);
    final summary = await context
        .read<InstallmentProvider>()
        .getSummary(widget.installmentId);
    if (mounted) {
      setState(() {
        _payments = payments;
        _summary = summary;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, sc) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              Text('أقساط: ${widget.customerName}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (!_loading && _summary.isNotEmpty) ...[
                Row(children: [
                  _SummaryChip(
                    label: '${_summary['paid']}/${_summary['total']} مدفوع',
                    color: Colors.green,
                    icon: Icons.check_circle,
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: 'متبقي: ${AppFormatters.formatCurrency((_summary['remaining_amount'] as num? ?? 0).toDouble())}',
                    color: Colors.red,
                    icon: Icons.account_balance_wallet,
                  ),
                ]),
                if ((_summary['postponed'] as int? ?? 0) > 0 ||
                    (_summary['partial'] as int? ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      if ((_summary['postponed'] as int? ?? 0) > 0)
                        _SummaryChip(
                          label: '${_summary['postponed']} مؤجل',
                          color: Colors.amber,
                          icon: Icons.access_time,
                        ),
                      const SizedBox(width: 8),
                      if ((_summary['partial'] as int? ?? 0) > 0)
                        _SummaryChip(
                          label: '${_summary['partial']} جزئي',
                          color: Colors.orange,
                          icon: Icons.more_horiz,
                        ),
                    ]),
                  ),
              ],
            ]),
          ),
          const Divider(height: 16),
          // Payment list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: _payments.length,
                    itemBuilder: (ctx, i) => _PaymentRow(
                      payment: _payments[i],
                      installmentId: widget.installmentId,
                      onChanged: () async {
                        await _load();
                        widget.onChanged?.call();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _SummaryChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── Payment row with color-coded status ─────────────────────────────────────

class _PaymentRow extends StatelessWidget {
  final InstallmentPayment payment;
  final int installmentId;
  final VoidCallback onChanged;

  const _PaymentRow({
    required this.payment,
    required this.installmentId,
    required this.onChanged,
  });

  /// Derived status: if DB says pending but date is past → treat as overdue
  String get _effectiveStatus {
    if (payment.status == 'pending' &&
        DateTime.now().isAfter(DateTime.parse(payment.dueDate))) {
      return 'overdue';
    }
    return payment.status;
  }

  Color get _statusColor {
    final c = InstallmentPayment.statusColor(_effectiveStatus, payment.dueDate);
    return Color(c);
  }

  String get _statusLabel {
    switch (_effectiveStatus) {
      case 'paid': return 'مدفوع';
      case 'postponed': return 'مؤجل';
      case 'partial': return 'جزئي';
      case 'overdue': return 'متأخر';
      default: return 'قادم';
    }
  }

  IconData get _statusIcon {
    switch (_effectiveStatus) {
      case 'paid': return Icons.check_circle;
      case 'postponed': return Icons.schedule;
      case 'partial': return Icons.remove_circle_outline;
      case 'overdue': return Icons.warning;
      default: return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final totalDue = payment.amount + payment.carriedAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Color indicator
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            // Due date
            Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(payment.dueDate,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            // Amount
            Text(
              AppFormatters.formatCurrency(totalDue),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon, size: 11, color: Colors.white),
                const SizedBox(width: 3),
                Text(_statusLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          if (payment.carriedAmount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'القسط الأصلي: ${AppFormatters.formatCurrency(payment.amount)} + مرحّل: ${AppFormatters.formatCurrency(payment.carriedAmount)}',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
            ),
          ],
          if (payment.isPartial) ...[
            const SizedBox(height: 4),
            Text(
              'مدفوع: ${AppFormatters.formatCurrency(payment.paidAmount)} | متبقي: ${AppFormatters.formatCurrency(totalDue - payment.paidAmount)}',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
            ),
          ],
          if (payment.paidDate != null && payment.isPaid) ...[
            const SizedBox(height: 4),
            Text('تاريخ الدفع: ${payment.paidDate}',
                style: const TextStyle(fontSize: 11, color: Colors.green)),
          ],
          if (payment.postponeReason != null) ...[
            const SizedBox(height: 4),
            Text('سبب التأجيل: ${payment.postponeReason}',
                style: TextStyle(fontSize: 11, color: Colors.amber.shade900)),
          ],

          // Action buttons for unpaid
          if (!payment.isPaid) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              // Mark paid
              _ActionBtn(
                label: 'دفع كامل',
                icon: Icons.check_circle_outline,
                color: Colors.green,
                onTap: () => _markPaid(context),
              ),
              const SizedBox(width: 8),
              // Partial payment
              _ActionBtn(
                label: 'دفع جزئي',
                icon: Icons.remove_circle_outline,
                color: Colors.orange,
                onTap: () => _showPartialDialog(context),
              ),
              const SizedBox(width: 8),
              // Postpone
              _ActionBtn(
                label: 'تأجيل',
                icon: Icons.schedule,
                color: Colors.amber.shade700,
                onTap: () => _showPostponeDialog(context),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _markPaid(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الدفع'),
        content: Text('هل تم استلام ${AppFormatters.formatCurrency(payment.amount + payment.carriedAmount)}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الدفع'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<InstallmentProvider>().markPaymentPaid(
        payment.id!,
        installmentId,
      );
      onChanged();
    }
  }

  Future<void> _showPartialDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('دفع جزئي'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('المبلغ المستحق: ${AppFormatters.formatCurrency(payment.amount + payment.carriedAmount)}',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          TextFormField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'المبلغ المدفوع *',
              prefixIcon: Icon(Icons.attach_money),
              suffixText: 'ج.م',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'ملاحظات'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () {
              final val = double.tryParse(amountCtrl.text);
              if (val != null && val > 0) Navigator.pop(ctx, val);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (amount != null && context.mounted) {
      await context.read<InstallmentProvider>().partialPayment(
        payment.id!, installmentId, amount,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      onChanged();
    }
  }

  Future<void> _showPostponeDialog(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأجيل القسط'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 16, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(child: Text('سيتم تأجيل القسط لمدة شهر واحد', style: TextStyle(fontSize: 12, color: Colors.amber))),
            ]),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: reasonCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'سبب التأجيل *',
              hintText: 'مثال: ظروف مالية، سفر...',
              prefixIcon: Icon(Icons.note_add),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.white),
            onPressed: () {
              if (reasonCtrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('تأجيل القسط'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<InstallmentProvider>().postponePayment(
        payment.id!, installmentId, reasonCtrl.text.trim(),
      );
      onChanged();
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─── Overdue payments tab ────────────────────────────────────────────────────

class _OverduePaymentsList extends StatefulWidget {
  final String? storeType;
  const _OverduePaymentsList({super.key, this.storeType});
  @override
  State<_OverduePaymentsList> createState() => _OverduePaymentsListState();
}

class _OverduePaymentsListState extends State<_OverduePaymentsList> {
  List<InstallmentPayment> _payments = [];
  bool _loading = true;

  // Month filter — null means "all overdue" (current behaviour)
  int? _filterYear;
  int? _filterMonth;

  static const _monthNames = [
    '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    List<InstallmentPayment> p;
    if (_filterYear != null && _filterMonth != null) {
      p = await context
          .read<InstallmentProvider>()
          .getOverduePaymentsByMonth(_filterYear!, _filterMonth!);
    } else {
      p = await context.read<InstallmentProvider>().getOverduePayments();
    }
    if (mounted) setState(() { _payments = p; _loading = false; });
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    int tempYear = _filterYear ?? now.year;
    int tempMonth = _filterMonth ?? now.month;

    final picked = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: const Text('اختر الشهر'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // Year selector
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setInner(() => tempYear--),
              ),
              Text(
                '$tempYear',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setInner(() => tempYear++),
              ),
            ]),
            const SizedBox(height: 8),
            // Month grid
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(12, (i) {
                final m = i + 1;
                final selected = m == tempMonth;
                return GestureDetector(
                  onTap: () => setInner(() => tempMonth = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(AppColors.primaryInt)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? const Color(AppColors.primaryInt)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      _monthNames[m],
                      style: TextStyle(
                        fontSize: 13,
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                setState(() { _filterYear = null; _filterMonth = null; });
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('عرض الكل', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, {'year': tempYear, 'month': tempMonth}),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _filterYear = picked['year'];
        _filterMonth = picked['month'];
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _filterYear != null && _filterMonth != null;
    final filterLabel = hasFilter
        ? '${_monthNames[_filterMonth!]} $_filterYear'
        : 'جميع المتأخرات';

    return Column(
      children: [
        // Month filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(children: [
            const Icon(Icons.filter_list, size: 18, color: Colors.grey),
            const SizedBox(width: 6),
            const Text('الشهر:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: _pickMonth,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: hasFilter
                        ? const Color(AppColors.primaryInt).withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasFilter
                          ? const Color(AppColors.primaryInt).withValues(alpha: 0.4)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      Icons.calendar_month,
                      size: 16,
                      color: hasFilter
                          ? const Color(AppColors.primaryInt)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      filterLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: hasFilter ? FontWeight.bold : FontWeight.normal,
                        color: hasFilter
                            ? const Color(AppColors.primaryInt)
                            : Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    if (hasFilter)
                      GestureDetector(
                        onTap: () {
                          setState(() { _filterYear = null; _filterMonth = null; });
                          _load();
                        },
                        child: const Icon(Icons.close, size: 16, color: Colors.red),
                      )
                    else
                      const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
                  ]),
                ),
              ),
            ),
          ]),
        ),

        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_payments.isEmpty)
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 12),
                Text(
                  hasFilter
                      ? 'لا توجد أقساط متأخرة في $filterLabel'
                      : 'لا توجد أقساط متأخرة',
                  style: const TextStyle(color: Colors.green, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          )
        else ...[
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber, color: Colors.red),
              const SizedBox(width: 10),
              Expanded(child: Text(
                '${_payments.length} قسط متأخر | إجمالي: ${AppFormatters.formatCurrency(_payments.fold(0.0, (s, p) => s + p.amount + p.carriedAmount))}',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: _payments.length,
                itemBuilder: (ctx, i) {
                  final p = _payments[i];
                  return _PaymentRow(
                    payment: p,
                    installmentId: p.installmentId,
                    onChanged: _load,
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Add Installment sheet ───────────────────────────────────────────────────

class _AddInstallmentSheet extends StatefulWidget {
  final String? storeType;
  const _AddInstallmentSheet({this.storeType});
  @override
  State<_AddInstallmentSheet> createState() => _AddInstallmentSheetState();
}

class _AddInstallmentSheetState extends State<_AddInstallmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _productNameCtrl = TextEditingController();
  final _manualNameCtrl = TextEditingController();
  final _manualPhoneCtrl = TextEditingController();
  TextEditingController? _purchasePriceCtrl;
  TextEditingController? _salePriceCtrl;
  Customer? _selectedCustomer;
  String _productName = '';
  double _purchasePrice = 0;
  double _salePrice = 0;
  double _downPayment = 0;
  int _numInstallments = 12;
  double _customRate = 0;
  bool _saving = false;

  // Customer input mode: 'app' | 'manual' | 'contacts'
  String _inputMode = 'app';

  List<Customer> _customers = [];
  bool _loadingCustomers = true;
  String _customerSearch = '';

  // Partner group selection
  final _groupDao = PartnerGroupDao();
  List<PartnerGroup> _partnerGroups = [];
  PartnerGroup? _selectedGroup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomers();
      _loadPartnerGroups();
    });
  }

  Future<void> _loadCustomers() async {
    final cp = context.read<CustomerProvider>();
    await cp.loadAll();
    if (mounted) {
      setState(() {
        _customers = cp.customers;
        _loadingCustomers = false;
      });
    }
  }

  Future<void> _loadPartnerGroups() async {
    try {
      final groups = await _groupDao.getAllGroups();
      if (mounted) setState(() => _partnerGroups = groups);
    } catch (_) {}
  }

  Future<void> _pickProduct() async {
    try {
      final products = await InstallmentProductDao().getAll();
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
                ? products
                : products.where((p) => p.name.toLowerCase().contains(query)).toList();
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
                const Text('اختر منتجاً من قائمة التقسيط',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: searchCtrl,
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
                            final prod = visible[i];
                            final displayPrice = prod.effectiveCashPrice > 0
                                ? prod.effectiveCashPrice
                                : prod.salePrice;
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.inventory_2_outlined, size: 20),
                              title: Text(prod.name, style: const TextStyle(fontSize: 14)),
                              subtitle: prod.category != null
                                  ? Text(prod.category!, style: const TextStyle(fontSize: 11, color: Colors.grey))
                                  : null,
                              trailing: displayPrice > 0
                                  ? Text(
                                      '${displayPrice.toStringAsFixed(0)} ج',
                                      style: TextStyle(color: Colors.green[700], fontSize: 13),
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _productName = prod.name;
                                  _productNameCtrl.text = prod.name;
                                  // Always update prices when product is selected
                                  if (displayPrice > 0) {
                                    _salePrice = displayPrice;
                                    _salePriceCtrl?.text = displayPrice.toStringAsFixed(0);
                                  }
                                  if (prod.purchasePrice > 0) {
                                    _purchasePrice = prod.purchasePrice;
                                    _purchasePriceCtrl?.text = prod.purchasePrice.toStringAsFixed(0);
                                  }
                                });
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

  Future<void> _pickContact() async {
    try {
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('يجب منح إذن الوصول لجهات الاتصال'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null && mounted) {
        final full = await FlutterContacts.getContact(contact.id, withProperties: true);
        setState(() {
          _manualNameCtrl.text = full?.displayName ?? contact.displayName;
          final phone = full?.phones.isNotEmpty == true
              ? full!.phones.first.number
              : contact.phones.isNotEmpty
                  ? contact.phones.first.number
                  : '';
          _manualPhoneCtrl.text = phone;
          _inputMode = 'contacts';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر فتح جهات الاتصال: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  void dispose() {
    _productNameCtrl.dispose();
    _manualNameCtrl.dispose();
    _manualPhoneCtrl.dispose();
    _purchasePriceCtrl?.dispose();
    _salePriceCtrl?.dispose();
    super.dispose();
  }

  Future<void> _printBlankContract() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    pw.Widget labelRow(String label) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(children: [
            pw.Text(label,
                style: pw.TextStyle(font: bold, fontSize: 11),
                textDirection: pw.TextDirection.rtl),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: pw.Container(
                    height: 1, color: PdfColors.grey400)),
          ]),
        );
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: font, bold: bold),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('عقد بيع بالتقسيط',
              style: pw.TextStyle(font: bold, fontSize: 18),
              textDirection: pw.TextDirection.rtl),
          pw.Divider(color: PdfColors.blue800),
          pw.SizedBox(height: 8),
          labelRow('التاريخ:'),
          labelRow('اسم العميل:'),
          labelRow('العنوان:'),
          labelRow('رقم الهاتف:'),
          labelRow('اسم الضامن:'),
          labelRow('هاتف الضامن:'),
          pw.SizedBox(height: 8),
          labelRow('الصنف:'),
          labelRow('سعر البيع الكلي:'),
          labelRow('المقدم المدفوع:'),
          labelRow('إجمالي الدين:'),
          labelRow('قيمة القسط الشهري:'),
          labelRow('عدد الأشهر:'),
          labelRow('بداية التقسيط:'),
          labelRow('نهاية التقسيط:'),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                children: ['م', 'تاريخ السداد', 'المبلغ', 'م', 'تاريخ السداد', 'المبلغ']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(h,
                              style: pw.TextStyle(font: bold, fontSize: 9),
                              textDirection: pw.TextDirection.rtl),
                        ))
                    .toList(),
              ),
              ...List.generate(
                  12,
                  (i) => pw.TableRow(children: [
                        '${i + 1}', '', '', '${i + 13}', '', ''
                      ]
                          .map((c) => pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(c,
                                    style: pw.TextStyle(
                                        font: font, fontSize: 9)),
                              ))
                          .toList())),
            ],
          ),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _printBlankSchedule() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: font, bold: bold),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('جدول سداد الأقساط',
              style: pw.TextStyle(font: bold, fontSize: 16),
              textDirection: pw.TextDirection.rtl),
          pw.Divider(color: PdfColors.blue800),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Text('اسم العميل: ',
                style: pw.TextStyle(font: bold, fontSize: 11),
                textDirection: pw.TextDirection.rtl),
            pw.Expanded(child: pw.Container(height: 1, color: PdfColors.grey400)),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Text('الصنف: ',
                style: pw.TextStyle(font: bold, fontSize: 11),
                textDirection: pw.TextDirection.rtl),
            pw.Expanded(child: pw.Container(height: 1, color: PdfColors.grey400)),
            pw.SizedBox(width: 16),
            pw.Text('قيمة القسط: ',
                style: pw.TextStyle(font: bold, fontSize: 11),
                textDirection: pw.TextDirection.rtl),
            pw.Expanded(child: pw.Container(height: 1, color: PdfColors.grey400)),
          ]),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                children: ['م', 'تاريخ الاستحقاق', 'المبلغ', 'تاريخ السداد', 'ملاحظات']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(h,
                              style: pw.TextStyle(font: bold, fontSize: 9),
                              textDirection: pw.TextDirection.rtl),
                        ))
                    .toList(),
              ),
              ...List.generate(
                  24,
                  (i) => pw.TableRow(children: [
                        '${i + 1}', '', '', '', ''
                      ]
                          .map((c) => pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(c,
                                    style: pw.TextStyle(
                                        font: font, fontSize: 9)),
                              ))
                          .toList())),
            ],
          ),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  List<Customer> get _filteredCustomers {
    if (_customerSearch.isEmpty) return _customers;
    final q = _customerSearch.toLowerCase();
    return _customers.where((c) =>
        c.name.toLowerCase().contains(q) ||
        (c.phone?.contains(q) ?? false)).toList();
  }

  // Preview calculation
  Map<String, dynamic> get _preview {
    final provider = context.read<InstallmentProvider>();
    final rate = _customRate > 0
        ? _customRate
        : provider.settings.rateForMonths(_numInstallments);
    return InstallmentProvider.calculateInstallment(
      salePrice: _salePrice,
      purchasePrice: _purchasePrice,
      numInstallments: _numInstallments,
      downPayment: _downPayment,
      installmentRatePct: rate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قسط جديد'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'طباعة نموذج فارغ',
            onSelected: (v) {
              if (v == 'empty_contract') _printBlankContract();
              if (v == 'empty_schedule') _printBlankSchedule();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'empty_contract',
                child: Row(children: [
                  Icon(Icons.description_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('نموذج عقد فارغ'),
                ]),
              ),
              PopupMenuItem(
                value: 'empty_schedule',
                child: Row(children: [
                  Icon(Icons.table_chart_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('جدول أقساط فارغ'),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Customer section ─────────────────────────────────────────────
            const Text('العميل *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),

            // Mode selector tabs
            Row(children: [
              _modeTab('من التطبيق', Icons.people, 'app'),
              const SizedBox(width: 6),
              _modeTab('يدوي', Icons.edit, 'manual'),
              const SizedBox(width: 6),
              _modeTab('جهات الاتصال', Icons.contacts, 'contacts'),
            ]),
            const SizedBox(height: 10),

            // ── App list mode ─────────────────────────────────────────────────
            if (_inputMode == 'app') ...[
              TextField(
                decoration: const InputDecoration(
                  hintText: 'ابحث عن العميل...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _customerSearch = v),
              ),
              const SizedBox(height: 8),
              if (_loadingCustomers)
                const Center(child: CircularProgressIndicator())
              else
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (ctx, i) {
                      final c = _filteredCustomers[i];
                      return ListTile(
                        dense: true,
                        title: Text(c.name),
                        subtitle: Text(c.phone ?? ''),
                        selected: _selectedCustomer?.id == c.id,
                        selectedTileColor: Colors.yellow.withValues(alpha: 0.5),
                        onTap: () => setState(() => _selectedCustomer = c),
                      );
                    },
                  ),
                ),
              if (_selectedCustomer != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text('تم اختيار: ${_selectedCustomer!.name}',
                        style: const TextStyle(color: Colors.green, fontSize: 12)),
                  ]),
                ),
            ],

            // ── Manual / Contacts mode ────────────────────────────────────────
            if (_inputMode == 'manual' || _inputMode == 'contacts') ...[
              if (_inputMode == 'contacts')
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _pickContact,
                    icon: const Icon(Icons.contacts_rounded, size: 16),
                    label: const Text('استيراد من جهات الاتصال',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Colors.teal),
                      foregroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              TextField(
                controller: _manualNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _manualPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'سيتم البحث عن العميل تلقائياً في قاعدة البيانات عند الحفظ. إذا لم يُوجد، أضفه أولاً من شاشة العملاء.',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 16),

            // Product
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _productNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنتج *',
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                    onChanged: (v) => setState(() => _productName = v),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: _pickProduct,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('من التقسيط', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                      side: const BorderSide(color: Color(AppColors.primaryInt)),
                      foregroundColor: Color(AppColors.primaryInt),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Prices row
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: (_purchasePriceCtrl ??= TextEditingController()),
                  decoration: const InputDecoration(
                    labelText: 'سعر الشراء *',
                    suffixText: 'ج.م',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (double.tryParse(v ?? '') ?? 0) <= 0 ? 'مطلوب' : null,
                  onChanged: (v) =>
                      setState(() => _purchasePrice = double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: (_salePriceCtrl ??= TextEditingController()),
                  decoration: const InputDecoration(
                    labelText: 'سعر البيع *',
                    suffixText: 'ج.م',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (double.tryParse(v ?? '') ?? 0) <= 0 ? 'مطلوب' : null,
                  onChanged: (v) =>
                      setState(() => _salePrice = double.tryParse(v) ?? 0),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'المقدم',
                    suffixText: 'ج.م',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _downPayment = double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _numInstallments,
                  decoration: const InputDecoration(labelText: 'عدد الأشهر'),
                  items: [3, 6, 9, 12, 18, 24].map((n) =>
                    DropdownMenuItem(value: n, child: Text('$n شهر'))).toList(),
                  onChanged: (v) => setState(() => _numInstallments = v!),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            TextFormField(
              decoration: const InputDecoration(
                labelText: 'نسبة التقسيط المخصصة',
                suffixText: '%',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  setState(() => _customRate = double.tryParse(v) ?? 0),
            ),

            const SizedBox(height: 16),

            // ── Partner group assignment ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    Icon(Icons.group, color: Colors.purple, size: 18),
                    SizedBox(width: 6),
                    Text('توجيه الفاتورة لمجموعة شركاء',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.purple)),
                  ]),
                  const SizedBox(height: 4),
                  const Text(
                    'اختر المجموعة التي ستتحمل تكلفة هذا المنتج وتظهر الأقساط في لوحة شركائها',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  if (_partnerGroups.isEmpty)
                    const Text('لا توجد مجموعات شركاء — أضف مجموعة أولاً',
                        style: TextStyle(color: Colors.grey, fontSize: 12))
                  else
                    DropdownButtonFormField<PartnerGroup?>(
                      value: _selectedGroup,
                      decoration: const InputDecoration(
                        labelText: 'مجموعة الشركاء (اختياري)',
                        prefixIcon: Icon(Icons.group_work),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<PartnerGroup?>(
                            value: null, child: Text('بدون مجموعة')),
                        ..._partnerGroups.map((g) => DropdownMenuItem<PartnerGroup?>(
                            value: g, child: Text(g.name))),
                      ],
                      onChanged: (g) => setState(() => _selectedGroup = g),
                    ),
                  if (_selectedGroup != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'سيتم خصم سعر الشراء من رصيد مجموعة "${_selectedGroup!.name}" تلقائياً عند الحفظ',
                            style: const TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Preview card
            if (_salePrice > 0) ...[
              Builder(builder: (ctx) {
                final calc = _preview;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.primaryInt).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(AppColors.primaryInt).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('معاينة حساب القسط',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    _PreviewRow('نسبة التقسيط', '${(calc['rate_pct'] as double).toStringAsFixed(1)}%'),
                    _PreviewRow('إجمالي مع الزيادة', AppFormatters.formatCurrency(calc['total_price'] as double)),
                    _PreviewRow('المقدم', AppFormatters.formatCurrency(_downPayment)),
                    _PreviewRow('المتبقي', AppFormatters.formatCurrency(calc['remaining'] as double)),
                    _PreviewRow('القسط الشهري', AppFormatters.formatCurrency(calc['monthly_amount'] as double),
                        highlight: true),
                    _PreviewRow('هامش الربح', AppFormatters.formatCurrency(calc['profit_margin'] as double),
                        color: Colors.green),
                  ]),
                );
              }),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: const Text('حفظ عقد القسط',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _modeTab(String label, IconData icon, String mode) {
    final active = _inputMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _inputMode = mode;
          _selectedCustomer = null;
          _manualNameCtrl.clear();
          _manualPhoneCtrl.clear();
          _customerSearch = '';
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? const Color(AppColors.primaryInt)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? const Color(AppColors.primaryInt)
                  : Colors.grey.shade300,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: active ? Colors.white : Colors.grey),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? Colors.white : Colors.grey,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                )),
          ]),
        ),
      ),
    );
  }

  Widget _PreviewRow(String label, String value, {bool highlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              fontSize: highlight ? 16 : 13,
              color: color ?? (highlight ? const Color(AppColors.primaryInt) : Colors.black87),
            )),
      ]),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Resolve customer based on input mode
    Customer? resolvedCustomer = _selectedCustomer;
    if (_inputMode == 'manual' || _inputMode == 'contacts') {
      final name = _manualNameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إدخال اسم العميل'), backgroundColor: Colors.red),
        );
        return;
      }
      // Search existing customers by name
      final match = _customers.where(
        (c) => c.name.trim().toLowerCase() == name.toLowerCase(),
      ).toList();
      if (match.isNotEmpty) {
        resolvedCustomer = match.first;
      } else {
        // Auto-create the customer in the database
        final now = DateTime.now().toIso8601String();
        final phone = _manualPhoneCtrl.text.trim();
        final newCustomer = Customer(
          name: name,
          phone: phone.isEmpty ? null : phone,
          customerType: AppConstants.customerTypeRegular,
          priceType: AppConstants.priceRetail,
          storeType: widget.storeType ?? AppConstants.storeInstallment,
          createdAt: now,
          loginCode: AppFormatters.generateAccessCode(),
        );
        final cp = context.read<CustomerProvider>();
        final newId = await cp.addCustomer(newCustomer);
        await cp.loadAll();
        resolvedCustomer = newCustomer.copyWith(id: newId);
        if (mounted) {
          setState(() => _customers = cp.customers);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إضافة العميل "$name" للنظام ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }

    if (resolvedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار عميل'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم المنتج'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<InstallmentProvider>().createInstallment(
        customerId: resolvedCustomer.id!,
        productName: _productName,
        purchasePrice: _purchasePrice,
        salePrice: _salePrice,
        numInstallments: _numInstallments,
        downPayment: _downPayment,
        storeType: widget.storeType ?? AppConstants.storeInstallment,
        customInstallmentRate: _customRate > 0 ? _customRate : null,
        partnerGroupId: _selectedGroup?.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء عقد القسط ✓'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
      // Notify all admins of new installment contract
      await PushNotificationService.sendToRole(
        role: 'admin',
        title: NotifMsg.newInstallmentAdminTitle,
        body: NotifMsg.newInstallmentAdminBody,
        type: 'installment',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
