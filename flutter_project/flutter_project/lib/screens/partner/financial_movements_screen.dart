import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// شاشة الحركات المالية للشريك
/// تعرض: خصم تكلفة المنتج عند إضافته + الأقساط الواردة
class FinancialMovementsScreen extends StatefulWidget {
  final List<int> groupIds;
  final List<String> groupNames;

  const FinancialMovementsScreen({
    super.key,
    required this.groupIds,
    required this.groupNames,
  });

  @override
  State<FinancialMovementsScreen> createState() => _FinancialMovementsScreenState();
}

class _FinancialMovementsScreenState extends State<FinancialMovementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final SupabaseClient _client = Supabase.instance.client;

  List<Map<String, dynamic>> _allFlows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final List<Map<String, dynamic>> all = [];
      for (int i = 0; i < widget.groupIds.length; i++) {
        final gId = widget.groupIds[i];
        final gName = i < widget.groupNames.length ? widget.groupNames[i] : 'مجموعة $gId';
        final flows = await _client
            .from('group_cash_flows')
            .select()
            .eq('group_id', gId)
            .order('date', ascending: false);
        for (final f in flows) {
          all.add({...Map<String, dynamic>.from(f), 'group_name': gName});
        }
      }
      // Sort all by date descending
      all.sort((a, b) => (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
      if (mounted) setState(() { _allFlows = all; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _flowsIn =>
      _allFlows.where((f) => f['type'] == 'in').toList();
  List<Map<String, dynamic>> get _flowsOut =>
      _allFlows.where((f) => f['type'] == 'out').toList();

  double get _totalIn => _flowsIn.fold(0.0, (s, f) => s + (f['amount'] as num? ?? 0).toDouble());
  double get _totalOut => _flowsOut.fold(0.0, (s, f) => s + (f['amount'] as num? ?? 0).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحركات المالية'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.swap_horiz), text: 'الكل'),
            Tab(icon: Icon(Icons.arrow_downward), text: 'أقساط واردة'),
            Tab(icon: Icon(Icons.arrow_upward), text: 'تكاليف منتجات'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Summary banner ────────────────────────────────────────────
                Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Expanded(child: _SummaryCard(
                      label: 'إجمالي الوارد\n(أقساط)',
                      value: AppFormatters.formatCurrency(_totalIn),
                      color: Colors.green,
                      icon: Icons.arrow_downward,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryCard(
                      label: 'إجمالي الصادر\n(تكاليف)',
                      value: AppFormatters.formatCurrency(_totalOut),
                      color: Colors.red,
                      icon: Icons.arrow_upward,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryCard(
                      label: 'صافي الحركات',
                      value: AppFormatters.formatCurrency(_totalIn - _totalOut),
                      color: (_totalIn - _totalOut) >= 0 ? Colors.teal : Colors.orange,
                      icon: Icons.account_balance_wallet,
                    )),
                  ]),
                ),
                // ── Tabs ─────────────────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _FlowList(flows: _allFlows),
                      _FlowList(flows: _flowsIn, emptyLabel: 'لا توجد أقساط واردة بعد'),
                      _FlowList(flows: _flowsOut, emptyLabel: 'لا توجد تكاليف منتجات بعد'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _FlowList extends StatelessWidget {
  final List<Map<String, dynamic>> flows;
  final String emptyLabel;

  const _FlowList({
    required this.flows,
    this.emptyLabel = 'لا توجد حركات بعد',
  });

  @override
  Widget build(BuildContext context) {
    if (flows.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.swap_horiz, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(emptyLabel, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      itemCount: flows.length,
      itemBuilder: (ctx, i) {
        final f = flows[i];
        final isIn = f['type'] == 'in';
        final amount = (f['amount'] as num? ?? 0).toDouble();
        final description = f['description'] as String? ?? '';
        final date = f['date'] as String? ?? '';
        final groupName = f['group_name'] as String? ?? '';
        final color = isIn ? Colors.green : Colors.red;

        // Determine icon based on description content
        IconData tileIcon;
        if (description.contains('قسط')) {
          tileIcon = Icons.credit_card;
        } else if (description.contains('تكلفة منتج') || description.contains('تكلفة')) {
          tileIcon = Icons.shopping_bag;
        } else {
          tileIcon = isIn ? Icons.arrow_downward : Icons.arrow_upward;
        }

        String displayDate = date;
        try {
          if (date.isNotEmpty) {
            final d = DateTime.parse(date);
            displayDate = '${d.day}/${d.month}/${d.year}';
          }
        } catch (_) {}

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(tileIcon, color: color, size: 20),
            ),
            title: Text(
              description.isNotEmpty
                  ? description
                  : (isIn ? 'قسط وارد' : 'تكلفة منتج'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (groupName.isNotEmpty)
                  Text(groupName,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(displayDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isIn ? '+ ${AppFormatters.formatCurrency(amount)}' : '- ${AppFormatters.formatCurrency(amount)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isIn ? 'وارد' : 'صادر',
                    style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
