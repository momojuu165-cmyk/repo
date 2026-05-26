import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/installment_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import 'installments_screen.dart';

class InstallmentsBySectionScreen extends StatefulWidget {
  const InstallmentsBySectionScreen({super.key});
  @override
  State<InstallmentsBySectionScreen> createState() => _InstallmentsBySectionScreenState();
}

class _InstallmentsBySectionScreenState extends State<InstallmentsBySectionScreen> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<InstallmentProvider>().loadAll();
      if (mounted) setState(() {
        _all = List.from(context.read<InstallmentProvider>().installments);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> _forSection(String storeType) =>
      _all.where((m) => (m['store_type'] as String? ?? 'installment') == storeType).toList();

  _SectionStats _stats(List<Map<String, dynamic>> rows) {
    final active    = rows.where((r) => r['status'] == 'active').length;
    final completed = rows.where((r) => r['status'] == 'completed').length;
    final total     = rows.fold(0.0, (s, r) =>
        s + ((r['total_price'] ?? r['total_installment_price'] ?? 0) as num).toDouble());
    final remaining = rows.fold(0.0, (s, r) =>
        s + ((r['remaining_amount'] ?? 0) as num).toDouble());
    final collected = total - remaining;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    // overdue: active installments whose start_date is past and status still active
    // We approximate overdue by checking remaining > 0 and status == active
    final overdue = rows.where((r) {
      if (r['status'] != 'active') return false;
      final end = r['end_date'] as String?;
      if (end == null || end.isEmpty) return false;
      return end.compareTo(today) < 0;
    }).length;
    return _SectionStats(
      total: rows.length,
      active: active,
      completed: completed,
      overdue: overdue,
      totalAmount: total,
      collected: collected,
      remaining: remaining,
    );
  }

  @override
  Widget build(BuildContext context) {
    final installmentRows  = _forSection(AppConstants.storeInstallment);
    final electricalRows   = _forSection(AppConstants.storeElectrical);
    final installmentStats = _stats(installmentRows);
    final electricalStats  = _stats(electricalRows);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأقساط حسب القسم'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // ── Overall summary ──────────────────────────────────
                      _OverallSummaryCard(all: _all),
                      const SizedBox(height: 16),

                      // ── Installment section ──────────────────────────────
                      _SectionHeader(
                        title: 'قسم التقسيط',
                        icon: Icons.payment,
                        color: const Color(AppColors.installmentInt),
                      ),
                      const SizedBox(height: 8),
                      _SectionStatsGrid(
                        stats: installmentStats,
                        color: const Color(AppColors.installmentInt),
                      ),
                      const SizedBox(height: 8),
                      _ViewAllButton(
                        label: 'عرض جميع أقساط التقسيط',
                        color: const Color(AppColors.installmentInt),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const InstallmentsScreen(
                              initialStoreType: AppConstants.storeInstallment),
                        )),
                      ),
                      const SizedBox(height: 20),

                      // ── Electrical section ───────────────────────────────
                      _SectionHeader(
                        title: 'قسم الكهربائيات',
                        icon: Icons.electrical_services,
                        color: const Color(AppColors.electricalInt),
                      ),
                      const SizedBox(height: 8),
                      _SectionStatsGrid(
                        stats: electricalStats,
                        color: const Color(AppColors.electricalInt),
                      ),
                      const SizedBox(height: 8),
                      _ViewAllButton(
                        label: 'عرض جميع أقساط الكهربائيات',
                        color: const Color(AppColors.electricalInt),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const InstallmentsScreen(
                              initialStoreType: AppConstants.storeElectrical),
                        )),
                      ),
                      const SizedBox(height: 20),

                      // ── Recent contracts across all sections ─────────────
                      if (_all.isNotEmpty) ...[
                        const _SectionHeader(
                          title: 'أحدث العقود (جميع الأقسام)',
                          icon: Icons.history,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        ..._all.take(5).map((row) => _MiniInstallmentCard(row: row)),
                      ],

                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
    );
  }
}

// ─── Overall summary ──────────────────────────────────────────────────────────

class _OverallSummaryCard extends StatelessWidget {
  final List<Map<String, dynamic>> all;
  const _OverallSummaryCard({required this.all});

  @override
  Widget build(BuildContext context) {
    final total = all.fold(0.0, (s, r) =>
        s + ((r['total_price'] ?? r['total_installment_price'] ?? 0) as num).toDouble());
    final remaining = all.fold(0.0, (s, r) =>
        s + ((r['remaining_amount'] ?? 0) as num).toDouble());
    final active = all.where((r) => r['status'] == 'active').length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(AppColors.primaryInt), Color(AppColors.primary2Int)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(AppColors.primaryInt).withValues(alpha: 0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          const Text('ملخص جميع الأقسام', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${all.length} عقد',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _SummaryItem(label: 'إجمالي العقود', value: AppFormatters.formatCurrency(total))),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(child: _SummaryItem(label: 'المحصّل', value: AppFormatters.formatCurrency(total - remaining))),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(child: _SummaryItem(label: 'المتبقي', value: AppFormatters.formatCurrency(remaining), highlight: true)),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: total > 0 ? (total - remaining) / total : 0,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 4),
        Text(
          '${total > 0 ? (((total - remaining) / total) * 100).toStringAsFixed(1) : 0}% تم تحصيله  •  $active عقد نشط',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ]),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label; final String value; final bool highlight;
  const _SummaryItem({required this.label, required this.value, this.highlight = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(
        color: highlight ? Colors.yellowAccent : Colors.white,
        fontWeight: FontWeight.bold, fontSize: 13)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]);
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon; final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    ),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
  ]);
}

// ─── Stats grid ───────────────────────────────────────────────────────────────

class _SectionStats {
  final int total, active, completed, overdue;
  final double totalAmount, collected, remaining;
  const _SectionStats({
    required this.total, required this.active, required this.completed,
    required this.overdue, required this.totalAmount,
    required this.collected, required this.remaining,
  });
}

class _SectionStatsGrid extends StatelessWidget {
  final _SectionStats stats;
  final Color color;
  const _SectionStatsGrid({required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: _StatTile(label: 'إجمالي العقود', value: '${stats.total}',
              icon: Icons.receipt_long, color: color)),
          Expanded(child: _StatTile(label: 'نشط', value: '${stats.active}',
              icon: Icons.play_circle, color: Colors.blue)),
          Expanded(child: _StatTile(label: 'مكتمل', value: '${stats.completed}',
              icon: Icons.check_circle, color: Colors.green)),
          Expanded(child: _StatTile(label: 'منتهي الأجل', value: '${stats.overdue}',
              icon: Icons.warning_amber,
              color: stats.overdue > 0 ? Colors.red : Colors.grey)),
        ]),
        const Divider(height: 20),
        Row(children: [
          Expanded(child: _AmountTile(
              label: 'إجمالي المبالغ', amount: stats.totalAmount, color: color)),
          Expanded(child: _AmountTile(
              label: 'المحصّل', amount: stats.collected, color: Colors.green)),
          Expanded(child: _AmountTile(
              label: 'المتبقي', amount: stats.remaining,
              color: stats.remaining > 0 ? Colors.orange : Colors.grey)),
        ]),
        if (stats.totalAmount > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stats.collected / stats.totalAmount,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${((stats.collected / stats.totalAmount) * 100).toStringAsFixed(1)}% محصّل',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 20),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
    Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center),
  ]);
}

class _AmountTile extends StatelessWidget {
  final String label; final double amount; final Color color;
  const _AmountTile({required this.label, required this.amount, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(AppFormatters.formatCurrency(amount),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
    Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center),
  ]);
}

// ─── View all button ──────────────────────────────────────────────────────────

class _ViewAllButton extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _ViewAllButton({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: onTap,
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}

// ─── Mini installment card ────────────────────────────────────────────────────

class _MiniInstallmentCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _MiniInstallmentCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final name        = (row['item_name'] ?? row['product_name'] ?? '') as String;
    final customer    = (row['customer_name'] ?? '') as String;
    final status      = (row['status'] ?? 'active') as String;
    final monthly     = ((row['monthly_amount'] ?? 0) as num).toDouble();
    final storeType   = (row['store_type'] ?? 'installment') as String;
    final isElectrical = storeType == AppConstants.storeElectrical;
    final color = isElectrical
        ? const Color(AppColors.electricalInt)
        : const Color(AppColors.installmentInt);
    final sectionLabel = isElectrical ? 'كهربائيات' : 'تقسيط';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(isElectrical ? Icons.electrical_services : Icons.payment,
              color: color, size: 18),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('$customer  •  $sectionLabel',
            style: const TextStyle(fontSize: 11)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(AppFormatters.formatCurrency(monthly),
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          Text(_statusLabel(status), style: TextStyle(fontSize: 10, color: _statusColor(status))),
        ]),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'completed': return 'مكتمل';
      case 'overdue': return 'متأخر';
      default: return 'نشط';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed': return Colors.green;
      case 'overdue': return Colors.red;
      default: return Colors.blue;
    }
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error; final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, size: 48, color: Colors.red),
    const SizedBox(height: 12),
    const Text('حدث خطأ في تحميل البيانات',
        style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text(error, style: const TextStyle(color: Colors.grey, fontSize: 12),
        textAlign: TextAlign.center),
    const SizedBox(height: 16),
    ElevatedButton.icon(onPressed: onRetry,
        icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
  ]));
}
