import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/expense.dart';
import '../../../models/treasury.dart';
import '../../../database/daos/treasury_dao.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = [];
  bool _loading = true;
  String _section = 'all';

  static const _sections = [
    ('all', 'الكل'),
    ('store', 'المتجر'),
    ('electrical', 'الكهربائية'),
    ('installments', 'الأقساط'),
    ('general', 'عام'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await Supabase.instance.client
        .from('expenses')
        .select()
        .order('created_at', ascending: false);
    if (mounted) {
      setState(() {
        _expenses = List<Map<String, dynamic>>.from(rows).map(Expense.fromMap).toList();
        _loading = false;
      });
    }
  }

  List<Expense> get _filtered {
    if (_section == 'all') return _expenses;
    return _expenses.where((e) => (e.section ?? 'general') == _section).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('فواتير المصروفات'),
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
                // ── Section filter chips ────────────────────────────────────
                Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _sections.map((s) {
                        final sel = _section == s.$1;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(s.$2),
                            selected: sel,
                            selectedColor: const Color(AppColors.primaryInt),
                            labelStyle: TextStyle(
                              color: sel ? Colors.white : Colors.black87,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) => setState(() => _section = s.$1),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('لا توجد مصروفات', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else ...[
                  _SummaryBar(expenses: filtered),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final e = filtered[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(AppColors.primaryInt),
                              child: Icon(Icons.money_off, color: Colors.white),
                            ),
                            title: Text(e.description,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${e.type} | ${e.section != null ? '${e.section} | ' : ''}${AppFormatters.formatDateFromString(e.date)}'),
                            trailing: Text(
                              AppFormatters.formatCurrency(e.amount),
                              style: const TextStyle(
                                  color: Color(AppColors.dangerInt),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showAddExpenseSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('مصروف جديد'),
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddExpenseSheet(onSaved: _load),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final List<Expense> expenses;

  const _SummaryBar({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final total = expenses.fold(0.0, (s, e) => s + e.amount);
    return Container(
      width: double.infinity,
      color: const Color(AppColors.primaryInt),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('إجمالي المصروفات',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            AppFormatters.formatCurrency(total),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const _AddExpenseSheet({required this.onSaved});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _treasuryDao = TreasuryDao();
  String _type = 'عام';
  String _section = 'general';
  int? _treasuryId;
  List<Treasury> _treasuries = [];
  bool _saving = false;

  static const List<String> _types = [
    'عام',
    'إيجار',
    'رواتب',
    'كهرباء',
    'مياه',
    'صيانة',
    'مواصلات',
    'تسويق',
    'أخرى',
  ];

  static const List<(String, String)> _sectionOptions = [
    ('general', 'عام'),
    ('store', 'المتجر'),
    ('electrical', 'الكهربائية'),
    ('installments', 'الأقساط'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTreasuries();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTreasuries() async {
    final t = await _treasuryDao.getAll();
    if (mounted) setState(() => _treasuries = t);
  }

  Future<void> _save() async {
    if (_descCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
      );
      return;
    }
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')),
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    String? errorMsg;
    try {
      final row = <String, dynamic>{
        'type': _type,
        'amount': amount,
        'description': _descCtrl.text.trim(),
        'date': now.substring(0, 10),
        'created_at': now,
      };
      // Try inserting with optional columns first, stripping on failure
      bool inserted = false;
      for (final attempt in [
        {...row, 'section': _section, 'treasury_id': _treasuryId},
        {...row, 'treasury_id': _treasuryId},
        row,
      ]) {
        try {
          await Supabase.instance.client
              .from('expenses')
              .insert(attempt)
              .timeout(const Duration(seconds: 15));
          inserted = true;
          break;
        } catch (e) {
          final msg = e.toString();
          if (!msg.contains('column') && !msg.contains('schema')) {
            errorMsg = msg;
            break;
          }
        }
      }
      if (inserted) {
        if (_treasuryId != null) {
          try {
            await _treasuryDao.addMovement(TreasuryMovement(
              treasuryId: _treasuryId!,
              type: 'withdrawal',
              amount: amount,
              description: _descCtrl.text.trim(),
              date: now.substring(0, 10),
              createdAt: now,
            ));
          } catch (_) {}
        }
      }
    } catch (e) {
      errorMsg = e.toString();
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    if (errorMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الحفظ: $errorMsg'), backgroundColor: Colors.red),
      );
    } else {
      widget.onSaved();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ المصروف ✓'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إضافة مصروف',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
                labelText: 'نوع المصروف *', border: OutlineInputBorder()),
            items: _types
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _section,
            decoration: const InputDecoration(
                labelText: 'القسم *', border: OutlineInputBorder()),
            items: _sectionOptions
                .map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2)))
                .toList(),
            onChanged: (v) => setState(() => _section = v ?? _section),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descCtrl,
            decoration: const InputDecoration(
                labelText: 'الوصف / البيان *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'المبلغ *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _treasuryId,
            decoration: const InputDecoration(
                labelText: 'الخزنة (اختياري)', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('— بدون خزنة —')),
              ..._treasuries.map((t) =>
                  DropdownMenuItem(value: t.id, child: Text(t.name))),
            ],
            onChanged: (v) => setState(() => _treasuryId = v),
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
                  : const Text('حفظ المصروف'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
