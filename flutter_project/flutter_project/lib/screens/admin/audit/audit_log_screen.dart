import 'package:flutter/material.dart';
import '../../../database/daos/audit_log_dao.dart';
import '../../../utils/constants.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _dao = AuditLogDao();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String _filterEntity = 'الكل';

  static const _entities = [
    'الكل', 'فاتورة', 'قسط', 'دفع قسط',
    'منتج', 'عميل', 'مورد',
  ];

  static const _entityToDb = {
    'فاتورة': 'invoice',
    'قسط': 'installment',
    'دفع قسط': 'installment_payment',
    'منتج': 'item',
    'عميل': 'customer',
    'مورد': 'supplier',
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final entity = _filterEntity == 'الكل' ? null : _entityToDb[_filterEntity];
      final rows = await _dao.getRecent(limit: 200, entity: entity);
      if (mounted) setState(() { _logs = rows; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل العمليات (Audit Log)'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(children: [
        // Filter bar
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Text('تصفية: ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: _filterEntity,
                isExpanded: true,
                underline: const SizedBox(),
                items: _entities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) {
                  if (v != null) { setState(() => _filterEntity = v); _load(); }
                },
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('لا توجد سجلات بعد', style: TextStyle(color: Colors.grey)),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) => _AuditTile(log: _logs[i]),
                    ),
        ),
      ]),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final Map<String, dynamic> log;
  const _AuditTile({required this.log});

  Color _actionColor(String action) {
    final a = action.toLowerCase();
    if (a.contains('delete') || a.contains('حذف')) return Colors.red;
    if (a.contains('update') || a.contains('تعديل')) return Colors.orange;
    if (a.contains('insert') || a.contains('إضافة') || a.contains('create')) return Colors.green;
    if (a.contains('pay') || a.contains('دفع')) return Colors.blue;
    return Colors.grey;
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final action = log['action'] as String? ?? '';
    final entity = log['entity'] as String? ?? '';
    final entityId = log['entity_id'];
    final by = log['performed_by_name'] ?? log['performed_by_user_id']?.toString() ?? 'النظام';
    final notes = log['notes'] as String?;
    final createdAt = log['created_at'] as String?;
    final color = _actionColor(action);

    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.history, color: color, size: 18),
      ),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
          child: Text(action, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Text('$entity${entityId != null ? ' #$entityId' : ''}',
            style: const TextStyle(fontSize: 13)),
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text('بواسطة: $by', style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 10),
          const Icon(Icons.access_time, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(_formatDate(createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        if (notes != null && notes.isNotEmpty)
          Text(notes, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
      onTap: () {
        final before = log['before_data'] as String?;
        final after = log['after_data'] as String?;
        if (before != null || after != null) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('تفاصيل: $action'),
              content: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (before != null) ...[
                    const Text('قبل:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Text(before, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    const SizedBox(height: 10),
                  ],
                  if (after != null) ...[
                    const Text('بعد:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text(after, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  ],
                ]),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
            ),
          );
        }
      },
    );
  }
}
