import 'package:flutter/material.dart';
import '../../../database/daos/treasury_dao.dart';
import '../../../models/treasury.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  final _dao = TreasuryDao();
  List<Treasury> _treasuries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await _dao.getAll();
      if (mounted) setState(() {
        _treasuries = t;
        _loading = false;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الخزنة'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTreasuryDialog(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSection('رئيسية', 'main', Icons.account_balance, Colors.blue),
                _buildSection('فرعية', 'sub', Icons.account_balance_wallet, Colors.teal),
                _buildSection('درج', 'drawer', Icons.inbox, Colors.orange),
                _buildSection('كهربائية', 'electrical', Icons.electrical_services, Colors.amber.shade700),
                _buildSection('تقسيط', 'installment', Icons.payment, Colors.green),
              ],
            ),
    );
  }

  Widget _buildSection(String label, String type, IconData icon, Color color) {
    final items = _treasuries.where((t) => t.type == type).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(10)),
              child: Text('${items.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        ...items.map((t) => _TreasuryCard(treasury: t, dao: _dao, onRefresh: _load)),
      ],
    );
  }

  void _showAddTreasuryDialog(BuildContext screenContext) {
    final nameCtrl = TextEditingController();
    String type = 'main';
    // Capture a reference to the dialog route context so we only close the dialog
    BuildContext? dialogRouteCtx;

    showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (routeCtx) {
        dialogRouteCtx = routeCtx;
        return StatefulBuilder(
          builder: (_, setDlg) => AlertDialog(
            title: const Text('إضافة خزنة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'اسم الخزنة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'النوع',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'main', child: Text('رئيسية')),
                    DropdownMenuItem(value: 'sub', child: Text('فرعية')),
                    DropdownMenuItem(value: 'drawer', child: Text('درج')),
                    DropdownMenuItem(value: 'electrical', child: Text('كهربائية')),
                    DropdownMenuItem(value: 'installment', child: Text('تقسيط')),
                  ],
                  onChanged: (v) => setDlg(() => type = v ?? type),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (dialogRouteCtx != null && Navigator.canPop(dialogRouteCtx!)) {
                    Navigator.pop(dialogRouteCtx!);
                  }
                },
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  try {
                    await _dao.insert(Treasury(name: name, type: type));
                    // Close ONLY the dialog, not the parent screen
                    if (dialogRouteCtx != null && Navigator.canPop(dialogRouteCtx!)) {
                      Navigator.pop(dialogRouteCtx!);
                    }
                    // Reload the list and show success on the parent screen
                    await _load();
                    if (screenContext.mounted) {
                      ScaffoldMessenger.of(screenContext).showSnackBar(
                        SnackBar(
                          content: Text('تم إضافة الخزنة "$name" بنجاح'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    if (screenContext.mounted) {
                      ScaffoldMessenger.of(screenContext).showSnackBar(
                        SnackBar(
                          content: Text('خطأ في الإضافة: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TreasuryCard extends StatelessWidget {
  final Treasury treasury;
  final TreasuryDao dao;
  final VoidCallback onRefresh;

  const _TreasuryCard({
    required this.treasury,
    required this.dao,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        leading: Icon(
          treasury.type == 'main'
              ? Icons.account_balance
              : Icons.account_balance_wallet,
          color: const Color(AppColors.primaryInt),
        ),
        title: Text(treasury.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          AppFormatters.formatCurrency(treasury.balance),
          style: TextStyle(
              color: treasury.balance >= 0 ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('إيداع'),
                    onPressed: () =>
                        _showMovementDialog(context, 'deposit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.remove),
                    label: const Text('سحب'),
                    onPressed: () =>
                        _showMovementDialog(context, 'withdrawal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.history),
                    label: const Text('الحركات'),
                    onPressed: () =>
                        _showMovements(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMovementDialog(BuildContext cardContext, String type) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    BuildContext? dialogCtx;

    showDialog(
      context: cardContext,
      builder: (routeCtx) {
        dialogCtx = routeCtx;
        return AlertDialog(
          title: Text(type == 'deposit' ? 'إيداع' : 'سحب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (dialogCtx != null && Navigator.canPop(dialogCtx!)) {
                  Navigator.pop(dialogCtx!);
                }
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) return;
                final now = DateTime.now().toIso8601String();
                await dao.addMovement(TreasuryMovement(
                  treasuryId: treasury.id!,
                  type: type,
                  amount: amount,
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  date: now.substring(0, 10),
                  createdAt: now,
                ));
                onRefresh();
                if (dialogCtx != null && Navigator.canPop(dialogCtx!)) {
                  Navigator.pop(dialogCtx!);
                }
                if (cardContext.mounted) {
                  ScaffoldMessenger.of(cardContext).showSnackBar(
                    SnackBar(
                      content: Text(type == 'deposit' ? 'تم الإيداع بنجاح' : 'تم السحب بنجاح'),
                      backgroundColor: type == 'deposit' ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void _showMovements(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _MovementsSheet(treasuryId: treasury.id!, dao: dao),
    );
  }
}

class _MovementsSheet extends StatefulWidget {
  final int treasuryId;
  final TreasuryDao dao;

  const _MovementsSheet({required this.treasuryId, required this.dao});

  @override
  State<_MovementsSheet> createState() => _MovementsSheetState();
}

class _MovementsSheetState extends State<_MovementsSheet> {
  List<TreasuryMovement> _movements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await widget.dao.getMovements(treasuryId: widget.treasuryId);
    if (mounted) setState(() => _movements = m);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('الحركات',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _movements.isEmpty
              ? const Center(child: Text('لا توجد حركات'))
              : ListView.builder(
                  itemCount: _movements.length,
                  itemBuilder: (ctx, i) {
                    final m = _movements[i];
                    return ListTile(
                      leading: Icon(
                        m.type == 'deposit'
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: m.type == 'deposit'
                            ? Colors.green
                            : Colors.red,
                      ),
                      title: Text(m.description ?? m.type),
                      subtitle: Text(
                          AppFormatters.formatDateFromString(m.date)),
                      trailing: Text(
                        AppFormatters.formatCurrency(m.amount),
                        style: TextStyle(
                          color: m.type == 'deposit'
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
