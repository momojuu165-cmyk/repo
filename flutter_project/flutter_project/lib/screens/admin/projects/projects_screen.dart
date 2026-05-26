import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/project.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> _projects = [];
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
        .from('projects')
        .select()
        .order('created_at', ascending: false);
    if (mounted) {
      setState(() {
        _projects = List<Map<String, dynamic>>.from(rows).map(Project.fromMap).toList();
        _loading = false;
      });
    }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المشاريع'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? const Center(child: Text('لا توجد مشاريع'))
              : ListView.builder(
                  itemCount: _projects.length,
                  itemBuilder: (ctx, i) {
                    final p = _projects[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _statusColor(p.status).withValues(alpha: 0.1),
                          child: Icon(Icons.construction,
                              color: _statusColor(p.status)),
                        ),
                        title: Text('${p.projectNo} - ${p.type}'),
                        subtitle: Text(
                            AppFormatters.formatDateFromString(p.date)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusChip(p.status),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 20),
                              tooltip: 'حذف المشروع',
                              onPressed: () => _confirmDelete(context, p),
                            ),
                          ],
                        ),
                        onTap: () => _showDetail(context, p),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  void _showDetail(BuildContext context, Project p) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _ProjectDetailSheet(project: p),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Project p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المشروع'),
        content: Text('هل تريد حذف المشروع "${p.projectNo} - ${p.type}"؟\nسيتم حذف جميع حركاته أيضاً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client
          .from('project_items')
          .delete()
          .eq('project_id', p.id!);
      await Supabase.instance.client
          .from('projects')
          .delete()
          .eq('id', p.id!);
      _load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حذف المشروع'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddDialog(BuildContext context) {
    final noCtrl = TextEditingController(
        text: 'PRJ-${_projects.length + 1}');
    final typeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة مشروع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
                controller: noCtrl,
                decoration:
                    const InputDecoration(labelText: 'رقم المشروع')),
            TextFormField(
                controller: typeCtrl,
                decoration: const InputDecoration(
                    labelText: 'النوع (توريد / تركيب / صيانة)')),
            TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'الوصف'),
                maxLines: 2),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final now = DateTime.now().toIso8601String();
              await Supabase.instance.client.from('projects').insert(Project(
                projectNo: noCtrl.text.trim(),
                type: typeCtrl.text.trim(),
                date: now.substring(0, 10),
                description: descCtrl.text.trim().isEmpty
                    ? null
                    : descCtrl.text.trim(),
                createdAt: now,
              ).toMap());
              _load();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _ProjectDetailSheet extends StatefulWidget {
  final Project project;

  const _ProjectDetailSheet({required this.project});

  @override
  State<_ProjectDetailSheet> createState() =>
      _ProjectDetailSheetState();
}

class _ProjectDetailSheetState extends State<_ProjectDetailSheet> {
  List<ProjectItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await Supabase.instance.client
        .from('project_items')
        .select()
        .eq('project_id', widget.project.id!);
    if (mounted) {
      setState(() => _items = List<Map<String, dynamic>>.from(rows).map(ProjectItem.fromMap).toList());
    }
  }

  double get totalExpenses => _items
      .where((i) => i.type == 'expense')
      .fold(0, (s, i) => s + i.amount);

  double get totalRevenue => _items
      .where((i) => i.type == 'revenue')
      .fold(0, (s, i) => s + i.amount);

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${p.projectNo} - ${p.type}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Text(AppFormatters.formatDateFromString(p.date),
              style: const TextStyle(color: Colors.grey)),
          if (p.description != null) Text(p.description!),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SumTile('المصروفات',
                  AppFormatters.formatCurrency(totalExpenses),
                  Colors.red),
              _SumTile('الإيرادات',
                  AppFormatters.formatCurrency(totalRevenue),
                  Colors.green),
              _SumTile('الصافي',
                  AppFormatters.formatCurrency(
                      totalRevenue - totalExpenses),
                  totalRevenue >= totalExpenses
                      ? Colors.green
                      : Colors.red),
            ],
          ),
          const Divider(),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('لا توجد حركات'))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          item.type == 'revenue'
                              ? Icons.add_circle
                              : Icons.remove_circle,
                          color: item.type == 'revenue'
                              ? Colors.green
                              : Colors.red,
                          size: 20,
                        ),
                        title: Text(item.description),
                        subtitle: Text(AppFormatters
                            .formatDateFromString(item.date)),
                        trailing: Text(
                          AppFormatters.formatCurrency(item.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: item.type == 'revenue'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryInt),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showAddItemDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('إضافة حركة'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String type = 'expense';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة حركة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'الوصف')),
            TextFormField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
            StatefulBuilder(builder: (ctx, setS) {
              return DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'النوع'),
                items: const [
                  DropdownMenuItem(
                      value: 'expense', child: Text('مصروف')),
                  DropdownMenuItem(
                      value: 'revenue', child: Text('إيراد')),
                ],
                onChanged: (v) => setS(() => type = v ?? type),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final now = DateTime.now().toIso8601String();
              await Supabase.instance.client.from('project_items').insert(
                  ProjectItem(
                    projectId: widget.project.id!,
                    type: type,
                    amount: double.tryParse(amountCtrl.text) ?? 0,
                    description: descCtrl.text,
                    date: now.substring(0, 10),
                  ).toMap());
              _load();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _SumTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SumTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        Text(label,
            style:
                const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    switch (status) {
      case 'completed':
        c = Colors.green;
        label = 'مكتمل';
        break;
      case 'cancelled':
        c = Colors.red;
        label = 'ملغي';
        break;
      default:
        c = Colors.blue;
        label = 'نشط';
    }
    return Chip(
      label: Text(label,
          style: TextStyle(color: c, fontSize: 11)),
      backgroundColor: c.withValues(alpha: 0.1),
      side: BorderSide(color: c),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}
