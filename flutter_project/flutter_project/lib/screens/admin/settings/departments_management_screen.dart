import 'package:flutter/material.dart';
import '../../../database/daos/department_dao.dart';
import '../../../models/department.dart';
import '../../../utils/constants.dart';
import '../installment_products/installment_products_screen.dart';

class DepartmentsManagementScreen extends StatefulWidget {
  const DepartmentsManagementScreen({super.key});

  @override
  State<DepartmentsManagementScreen> createState() =>
      _DepartmentsManagementScreenState();
}

class _DepartmentsManagementScreenState
    extends State<DepartmentsManagementScreen> {
  final _dao = DepartmentDao();
  List<Department> _departments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final depts = await _dao.getAll();
    if (mounted) setState(() { _departments = depts; _loading = false; });
  }

  void _showAddDialog([Department? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final storeTypeCtrl = TextEditingController(text: existing?.storeType ?? 'dept_${DateTime.now().millisecondsSinceEpoch}');
    final descCtrl = TextEditingController(text: existing?.description);
    bool isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'إضافة قسم جديد' : 'تعديل القسم'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم القسم *',
                  hintText: 'مثال: قسم الملابس',
                  border: OutlineInputBorder(),
                ),
              ),
              if (existing != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: storeTypeCtrl,
                  enabled: !existing.isSystem,
                  decoration: InputDecoration(
                    labelText: 'معرف القسم (بالإنجليزية)',
                    hintText: 'مثال: clothing',
                    helperText: existing.isSystem
                        ? 'لا يمكن تغيير معرف الأقسام الأساسية'
                        : 'يجب أن يكون فريداً وبالحروف الإنجليزية فقط',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'وصف القسم (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('القسم مفعّل'),
                value: isActive,
                onChanged: (v) => setS(() => isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final storeType = existing != null
                    ? storeTypeCtrl.text.trim().toLowerCase()
                    : 'dept_${DateTime.now().millisecondsSinceEpoch}';
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('اسم القسم مطلوب'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                try {
                  if (existing == null) {
                    await _dao.create(Department(
                      name: name,
                      storeType: storeType,
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                      isActive: isActive,
                      createdAt: DateTime.now().toIso8601String(),
                    ));
                  } else {
                    await _dao.update(existing.copyWith(
                      name: name,
                      storeType: existing.isSystem ? existing.storeType : storeType,
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                      isActive: isActive,
                    ));
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(existing == null
                            ? 'تم إضافة القسم بنجاح ✓'
                            : 'تم تحديث القسم بنجاح ✓'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('خطأ: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Department d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف القسم'),
        content: Text(
            'هل أنت متأكد من حذف قسم "${d.name}"؟\nلن يتمكن المديرون المرتبطون به من الوصول.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _dao.delete(d.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأقسام'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _departments.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.category_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('لا توجد أقسام بعد',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة قسم'),
                    ),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _departments.length,
                  itemBuilder: (ctx, i) {
                    final d = _departments[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: d.isActive
                              ? const Color(AppColors.primaryInt).withValues(alpha: 0.1)
                              : Colors.grey.shade200,
                          child: Icon(
                            Icons.category,
                            color: d.isActive
                                ? const Color(AppColors.primaryInt)
                                : Colors.grey,
                          ),
                        ),
                        title: Row(children: [
                          Expanded(
                            child: Text(d.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                          if (d.isSystem)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: const Text('أساسي',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.blue)),
                            ),
                          if (!d.isActive) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: const Text('معطّل',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.red)),
                            ),
                          ],
                        ]),
                        subtitle: Text(
                          'المعرف: ${d.storeType}${d.description != null ? ' • ${d.description}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InstallmentProductsScreen(
                              initialStoreType: d.storeType,
                              departmentName: d.name,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'إدارة الفئات والمنتجات',
                              child: IconButton(
                                icon: const Icon(Icons.inventory_2_outlined, color: Colors.teal),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InstallmentProductsScreen(
                                      initialStoreType: d.storeType,
                                      departmentName: d.name,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _showAddDialog(d);
                                if (v == 'delete' && !d.isSystem) _delete(d);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('تعديل'),
                                    ])),
                                if (!d.isSystem)
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('حذف', style: TextStyle(color: Colors.red)),
                                      ])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showAddDialog(),
        icon: const Icon(Icons.add),
        label: const Text('قسم جديد'),
      ),
    );
  }
}
