import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../database/daos/partner_group_dao.dart';
import '../../../models/partner_group.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

/// شاشة إدارة الحركات المالية للمجموعات (للأدمن)
/// تتيح إضافة / تعديل / حذف حركات group_cash_flows لكل مجموعة
class GroupCashFlowsScreen extends StatefulWidget {
  const GroupCashFlowsScreen({super.key});

  @override
  State<GroupCashFlowsScreen> createState() => _GroupCashFlowsScreenState();
}

class _GroupCashFlowsScreenState extends State<GroupCashFlowsScreen> {
  final _dao = PartnerGroupDao();

  List<PartnerGroup> _groups = [];
  PartnerGroup? _selectedGroup;
  List<Map<String, dynamic>> _flows = [];
  bool _loadingGroups = true;
  bool _loadingFlows = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    final g = await _dao.getAllGroups();
    if (mounted) {
      setState(() {
        _groups = g;
        _loadingGroups = false;
        if (g.isNotEmpty && _selectedGroup == null) {
          _selectedGroup = g.first;
          _loadFlows();
        }
      });
    }
  }

  Future<void> _loadFlows() async {
    if (_selectedGroup?.id == null) return;
    setState(() => _loadingFlows = true);
    final flows = await _dao.getCashFlowsForGroup(_selectedGroup!.id!);
    if (mounted) setState(() { _flows = flows; _loadingFlows = false; });
  }

  double get _totalIn => _flows
      .where((f) => f['type'] == 'in')
      .fold(0.0, (s, f) => s + (f['amount'] as num? ?? 0).toDouble());

  double get _totalOut => _flows
      .where((f) => f['type'] == 'out')
      .fold(0.0, (s, f) => s + (f['amount'] as num? ?? 0).toDouble());

  Future<void> _deleteFlow(Map<String, dynamic> flow) async {
    final id = flow['id'] as int?;
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذه الحركة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _dao._deleteFlow(id);
      _loadFlows();
    }
  }

  void _showFlowForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CashFlowFormSheet(
        group: _selectedGroup!,
        dao: _dao,
        existing: existing,
        onSaved: _loadFlows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحركات المالية للمجموعات'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFlows)],
      ),
      floatingActionButton: _selectedGroup != null
          ? FloatingActionButton.extended(
              backgroundColor: const Color(AppColors.primaryInt),
              foregroundColor: Colors.white,
              onPressed: () => _showFlowForm(),
              icon: const Icon(Icons.add),
              label: const Text('حركة جديدة'),
            )
          : null,
      body: _loadingGroups
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // ── Group selector ───────────────────────────────────────────────
              if (_groups.isNotEmpty)
                Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: DropdownButtonFormField<PartnerGroup>(
                    value: _selectedGroup,
                    decoration: InputDecoration(
                      labelText: 'اختر المجموعة',
                      prefixIcon: const Icon(Icons.group),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _groups
                        .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                        .toList(),
                    onChanged: (g) {
                      setState(() => _selectedGroup = g);
                      _loadFlows();
                    },
                  ),
                ),

              if (_groups.isEmpty)
                const Expanded(
                  child: Center(child: Text('لا توجد مجموعات شركاء بعد', style: TextStyle(color: Colors.grey))),
                )
              else if (_selectedGroup != null) ...[
                // ── Summary ─────────────────────────────────────────────────────
                Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(children: [
                    Expanded(child: _SumCard(
                      label: 'إجمالي الوارد',
                      value: AppFormatters.formatCurrency(_totalIn),
                      color: Colors.green, icon: Icons.arrow_downward,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _SumCard(
                      label: 'إجمالي الصادر',
                      value: AppFormatters.formatCurrency(_totalOut),
                      color: Colors.red, icon: Icons.arrow_upward,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _SumCard(
                      label: 'الصافي',
                      value: AppFormatters.formatCurrency(_totalIn - _totalOut),
                      color: (_totalIn - _totalOut) >= 0 ? Colors.teal : Colors.orange,
                      icon: Icons.account_balance_wallet,
                    )),
                  ]),
                ),

                // ── Flows list ───────────────────────────────────────────────
                Expanded(
                  child: _loadingFlows
                      ? const Center(child: CircularProgressIndicator())
                      : _flows.isEmpty
                          ? Center(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.swap_horiz, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                const Text('لا توجد حركات مالية بعد', style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(AppColors.primaryInt),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _showFlowForm(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('أضف حركة'),
                                ),
                              ]),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                              itemCount: _flows.length,
                              itemBuilder: (ctx, i) {
                                final f = _flows[i];
                                return _FlowCard(
                                  flow: f,
                                  onEdit: () => _showFlowForm(existing: f),
                                  onDelete: () => _deleteFlow(f),
                                );
                              },
                            ),
                ),
              ],
            ]),
    );
  }
}

// ── Summary card ─────────────────────────────────────────────────────────────

class _SumCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _SumCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 3),
      Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(value, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    ]),
  );
}

// ── Flow card ─────────────────────────────────────────────────────────────────

class _FlowCard extends StatelessWidget {
  final Map<String, dynamic> flow;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _FlowCard({required this.flow, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isIn = flow['type'] == 'in';
    final amount = (flow['amount'] as num? ?? 0).toDouble();
    final description = flow['description'] as String? ?? '';
    final date = flow['date'] as String? ?? '';
    final color = isIn ? Colors.green : Colors.red;

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
          child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
        ),
        title: Text(
          description.isNotEmpty ? description : (isIn ? 'وارد' : 'صادر'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isIn ? 'وارد' : 'صادر',
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Text(displayDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              isIn ? '+ ${AppFormatters.formatCurrency(amount)}' : '- ${AppFormatters.formatCurrency(amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ]),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'edit') onEdit(); else if (v == 'delete') onDelete(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [
                Icon(Icons.edit, size: 16, color: Colors.blue), SizedBox(width: 8), Text('تعديل'),
              ])),
              const PopupMenuItem(value: 'delete', child: Row(children: [
                Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('حذف'),
              ])),
            ],
          ),
        ]),
      ),
    );
  }
}

// ── Add/Edit form ─────────────────────────────────────────────────────────────

class _CashFlowFormSheet extends StatefulWidget {
  final PartnerGroup group;
  final PartnerGroupDao dao;
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _CashFlowFormSheet({required this.group, required this.dao, this.existing, required this.onSaved});

  @override
  State<_CashFlowFormSheet> createState() => _CashFlowFormSheetState();
}

class _CashFlowFormSheetState extends State<_CashFlowFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  String _type = 'in';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?['type'] as String? ?? 'in';
    _amountCtrl = TextEditingController(
        text: e != null ? (e['amount'] as num? ?? 0).toStringAsFixed(2) : '');
    _descCtrl = TextEditingController(text: e?['description'] as String? ?? '');
    if (e != null) {
      try {
        _date = DateTime.parse(e['date'] as String? ?? '');
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = widget.existing?['id'] as int?;
      final amount = double.tryParse(_amountCtrl.text) ?? 0;
      final dateStr = _date.toIso8601String().substring(0, 10);

      if (id != null) {
        await widget.dao._updateFlow(id, _type, amount, _descCtrl.text.trim(), dateStr);
      } else {
        await widget.dao.insertCashFlow(
          groupId: widget.group.id!,
          type: _type,
          amount: amount,
          description: _descCtrl.text.trim(),
          date: dateStr,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final dateStr = '${_date.day}/${_date.month}/${_date.year}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title
          Row(children: [
            Icon(isEditing ? Icons.edit : Icons.add_circle,
                color: const Color(AppColors.primaryInt)),
            const SizedBox(width: 8),
            Text(isEditing ? 'تعديل حركة مالية' : 'إضافة حركة مالية',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 4),
          Text('المجموعة: ${widget.group.name}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const Divider(height: 20),

          // Type selector
          const Text('نوع الحركة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _TypeBtn(
              label: 'وارد (قسط / دخل)',
              icon: Icons.arrow_downward,
              selected: _type == 'in',
              color: Colors.green,
              onTap: () => setState(() => _type = 'in'),
            )),
            const SizedBox(width: 8),
            Expanded(child: _TypeBtn(
              label: 'صادر (تكلفة / مصروف)',
              icon: Icons.arrow_upward,
              selected: _type == 'out',
              color: Colors.red,
              onTap: () => setState(() => _type = 'out'),
            )),
          ]),
          const SizedBox(height: 14),

          // Amount
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'المبلغ',
              prefixIcon: Icon(Icons.attach_money,
                  color: _type == 'in' ? Colors.green : Colors.red),
            ),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'أدخل مبلغاً صحيحاً';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Description
          TextFormField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'الوصف / الملاحظة',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),

          // Date
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'التاريخ',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(dateStr, style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(isEditing ? Icons.save : Icons.add),
              label: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الحركة'),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.icon, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: selected ? color : Colors.grey, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label,
            style: TextStyle(fontSize: 12, color: selected ? color : Colors.grey,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal))),
      ]),
    ),
  );
}

// Extension for internal DAO operations (update/delete individual flow rows)
extension _PartnerGroupDaoCashFlowOps on PartnerGroupDao {
  Future<void> _deleteFlow(int id) async {
    await Supabase.instance.client.from('group_cash_flows').delete().eq('id', id);
  }

  Future<void> _updateFlow(int id, String type, double amount, String description, String date) async {
    await Supabase.instance.client.from('group_cash_flows').update({
      'type': type,
      'amount': amount,
      'description': description,
      'date': date,
    }).eq('id', id);
  }
}
