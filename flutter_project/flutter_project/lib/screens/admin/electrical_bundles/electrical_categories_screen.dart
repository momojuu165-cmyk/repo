import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/constants.dart';

class ElectricalCategoriesScreen extends StatefulWidget {
  const ElectricalCategoriesScreen({super.key});
  @override
  State<ElectricalCategoriesScreen> createState() => _ElectricalCategoriesScreenState();
}

class _ElectricalCategoriesScreenState extends State<ElectricalCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {

    final rows = await Supabase.instance.client
        .from('item_groups')
        .select()
        .eq('store_type', AppConstants.storeElectrical)
        .order('name', ascending: true);
    if (mounted) setState(() { _categories = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذه الفئة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.from('item_groups').delete().eq('id', id);
      _load();
    }
  }

  Future<void> _showAddDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(existing == null ? 'إضافة فئة جديدة' : 'تعديل الفئة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl, autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم الفئة *', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              if (existing == null) {
                await Supabase.instance.client.from('item_groups').insert({
                  'name': name,
                  'store_type': AppConstants.storeElectrical,
                  'created_at': DateTime.now().toIso8601String(),
                });
              } else {
                await Supabase.instance.client
                    .from('item_groups')
                    .update({'name': name})
                    .eq('id', existing['id'] as int);
              }
              if (dlgCtx.mounted) Navigator.pop(dlgCtx, true);
            },
            child: Text(existing == null ? 'إضافة' : 'حفظ'),
          ),
        ],
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فئات الأدوات الكهربائية'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showAddDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة فئة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('لا توجد فئات بعد', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(onPressed: () => _showAddDialog(), icon: const Icon(Icons.add), label: const Text('إضافة أول فئة')),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    final cat = _categories[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x1A2196F3),
                          child: Icon(Icons.electrical_services, color: Color(AppColors.primaryInt)),
                        ),
                        title: Text(cat['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            onPressed: () => _showAddDialog(existing: cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _delete(cat['id'] as int),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
