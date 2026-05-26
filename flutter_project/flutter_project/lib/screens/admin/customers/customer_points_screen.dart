import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/customer.dart';
import '../../../models/customer_points_log.dart';
import '../../../providers/customer_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class CustomerPointsScreen extends StatefulWidget {
  final Customer customer;

  const CustomerPointsScreen({super.key, required this.customer});

  @override
  State<CustomerPointsScreen> createState() => _CustomerPointsScreenState();
}

class _CustomerPointsScreenState extends State<CustomerPointsScreen> {
  List<CustomerPointsLog> _log = [];
  bool _loading = true;
  bool _settling = false;
  bool _suppressProviderReload = false;
  late Customer _customer;
  CustomerProvider? _providerRef;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _load();
    // Listen for provider changes (e.g. after an invoice is saved) and reload
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _providerRef = context.read<CustomerProvider>();
      _providerRef!.addListener(_onProviderChanged);
    });
  }

  void _onProviderChanged() {
    if (!mounted || _suppressProviderReload) return;

    // Reload points log and fresh customer balance whenever the provider notifies.
    // We intentionally reload even during an active fetch so updates are not lost
    // if the provider notifies while this screen is loading.
    _load();
  }

  @override
  void dispose() {
    _providerRef?.removeListener(_onProviderChanged);
    super.dispose();
  }

  String? _errorMsg;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final provider = context.read<CustomerProvider>();

    try {
      // Fetch points log
      final log = await provider.getPointsLog(_customer.id!);

      // Fetch fresh customer data for up-to-date points balance
      Customer? fresh;
      try {
        fresh = await provider.getById(_customer.id!);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _log = log;
        if (fresh != null) _customer = fresh;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = e.toString();
      });
    }
  }

  int get _totalUnsettled =>
      _log.where((e) => !e.isSettled).fold(0, (s, e) => s + e.pointsEarned);

  int get _totalSettled =>
      _log.where((e) => e.isSettled).fold(0, (s, e) => s + e.pointsEarned);

  Future<void> _runSettlement(
    Future<void> Function(CustomerProvider provider) action, {
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<CustomerProvider>();

    debugPrint('[PointsScreen] Starting settlement for customer ${_customer.id}');

    if (_customer.id == null) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد العميل للتسوية.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_settling) {
      debugPrint('[PointsScreen] Already settling, ignoring duplicate tap.');
      return;
    }

    setState(() => _settling = true);
    _suppressProviderReload = true;

    try {
      await action(provider);
      debugPrint('[PointsScreen] Settlement action completed for customer ${_customer.id}');
      if (!mounted) {
        debugPrint('[PointsScreen] Widget unmounted after settlement!');
        return;
      }
      await _load();
      debugPrint('[PointsScreen] Reloaded after settlement for customer ${_customer.id}');
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) {
        debugPrint('[PointsScreen] Widget unmounted after settlement error!');
        return;
      }
      debugPrint('[PointsScreen] Error in settlement: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text('خطأ في التسوية: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      _suppressProviderReload = false;
      if (mounted) {
        debugPrint('[PointsScreen] Settlement flow finished, setting _settling = false');
        setState(() => _settling = false);
      }
    }
  }

  Future<void> _settle(CustomerPointsLog entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسوية النقاط'),
        content: Text(
            'هل تريد تسوية ${entry.pointsEarned} نقطة من فاتورة #${entry.invoiceNo}؟\nسيتم خصمها من رصيد العميل.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسوية'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runSettlement(
      (provider) => provider.settlePointsEntry(
        entry.id!,
        _customer.id!,
        entry.pointsEarned,
      ),
      successMessage: 'تمت تسوية $entry.pointsEarned نقطة بنجاح.',
    );
  }

  Future<void> _settleAll() async {
    if (_totalUnsettled == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسوية كل النقاط'),
        content: Text(
            'هل تريد تسوية جميع النقاط غير المسواة ($_totalUnsettled نقطة)؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسوية الكل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runSettlement(
      (provider) => provider.settleAllPoints(_customer.id!),
      successMessage: 'تمت تسوية $_totalUnsettled نقطة بنجاح.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('نقاط ${_customer.name}'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading || _settling ? null : _load),
          if (_totalUnsettled > 0)
            TextButton.icon(
              onPressed: _settling || _loading ? null : _settleAll,
              icon: const Icon(Icons.done_all, color: Colors.white),
              label: Text(
                _settling ? 'جاري التسوية...' : 'تسوية الكل',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 52),
                        const SizedBox(height: 12),
                        const Text('فشل تحميل سجل النقاط',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SelectableText(
                          _errorMsg!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'تحقق من وجود جدول customer_points_log\nفي Supabase وصحة RLS policies',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _SummaryBanner(
                      totalUnsettled: _totalUnsettled,
                      totalSettled: _totalSettled,
                      customerPoints: _customer.points,
                    ),
                    Expanded(
                      child: _log.isEmpty
                          ? _EmptyState()
                          : _PointsTable(
                              log: _log,
                              isBusy: _settling,
                              onSettle: _settle,
                            ),
                    ),
                  ],
                ),
    );
  }
}

// ─── Summary Banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final int totalUnsettled;
  final int totalSettled;
  final int customerPoints;

  const _SummaryBanner({
    required this.totalUnsettled,
    required this.totalSettled,
    required this.customerPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(AppColors.primaryInt),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.stars,
            label: 'نقاط قابلة للتسوية',
            value: totalUnsettled.toString(),
            color: Colors.amber,
          ),
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.check_circle,
            label: 'مسواة',
            value: totalSettled.toString(),
            color: Colors.greenAccent,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Points Table ──────────────────────────────────────────────────────────────

class _PointsTable extends StatelessWidget {
  final List<CustomerPointsLog> log;
  final bool isBusy;
  final Future<void> Function(CustomerPointsLog) onSettle;

  const _PointsTable(
      {required this.log, required this.isBusy, required this.onSettle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Row(
              children: [
                _HeaderCell('رقم الفاتورة', flex: 2),
                _HeaderCell('التاريخ', flex: 2),
                _HeaderCell('النقاط', flex: 1),
                _HeaderCell('قيمة النقطة', flex: 2),
                _HeaderCell('الإجمالي', flex: 2),
                _HeaderCell('الحالة', flex: 2),
                _HeaderCell('تسوية', flex: 2),
              ],
            ),
          ),
          const Divider(height: 1),
          ...log.map((entry) => _PointsRow(
                entry: entry,
                isBusy: isBusy,
                onSettle: onSettle,
              )),
          _TotalRow(log: log),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _HeaderCell(this.text, {this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PointsRow extends StatelessWidget {
  final CustomerPointsLog entry;
  final bool isBusy;
  final Future<void> Function(CustomerPointsLog) onSettle;

  const _PointsRow(
      {required this.entry, required this.isBusy, required this.onSettle});

  @override
  Widget build(BuildContext context) {
    final settled = entry.isSettled;
    return Container(
      decoration: BoxDecoration(
        color: settled ? Colors.grey.shade50 : Colors.white,
        border: const Border(
            bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '#${entry.invoiceNo}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: settled
                    ? Colors.grey
                    : const Color(AppColors.primaryInt),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entry.date.length >= 10 ? entry.date.substring(0, 10) : entry.date,
              style: TextStyle(
                  fontSize: 12,
                  color: settled ? Colors.grey : Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${entry.pointsEarned}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: settled ? Colors.grey : Colors.indigo,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${entry.pointValue.toStringAsFixed(0)} ${entry.currencyLabel}',
              style: TextStyle(
                  fontSize: 12,
                  color: settled ? Colors.grey : Colors.teal),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              AppFormatters.formatCurrency(entry.totalValueEgp),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: settled ? Colors.grey : Colors.green.shade700,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: settled
                      ? Colors.grey.shade200
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  settled ? 'مسوّاة' : 'معلقة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: settled ? Colors.grey : Colors.orange.shade800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: settled
                ? Center(
                    child: Text(
                      entry.settledAt != null &&
                              entry.settledAt!.length >= 10
                          ? entry.settledAt!.substring(0, 10)
                          : '—',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      onPressed: isBusy ? null : () => onSettle(entry),
                      child: const Text('تسوية',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final List<CustomerPointsLog> log;

  const _TotalRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final totalPts =
        log.fold<int>(0, (s, e) => s + e.pointsEarned);
    final unsettledPts =
        log.where((e) => !e.isSettled).fold<int>(0, (s, e) => s + e.pointsEarned);
    final totalVal =
        log.fold<double>(0, (s, e) => s + e.totalValueEgp);
    return Container(
      color: const Color(AppColors.primaryInt).withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text('الإجمالي: $totalPts نقطة',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
            child: Text('غير مسوّاة: $unsettledPts نقطة',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orange)),
          ),
          Expanded(
            child: Text(
              'القيمة الكلية: ${AppFormatters.formatCurrency(totalVal)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('لا توجد نقاط مسجّلة بعد',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          SizedBox(height: 6),
          Text('ستظهر النقاط هنا عند إنشاء فواتير لهذا العميل',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
