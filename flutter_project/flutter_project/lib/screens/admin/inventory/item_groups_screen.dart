import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/item_group.dart';
import '../../../utils/constants.dart';

class ItemGroupsScreen extends StatefulWidget {
  const ItemGroupsScreen({super.key});

  @override
  State<ItemGroupsScreen> createState() => _ItemGroupsScreenState();
}

class _ItemGroupsScreenState extends State<ItemGroupsScreen> {
  List<ItemGroup> _groups = [];
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
        .from('item_groups')
        .select()
        .or("store_type.eq.electrical,store_type.is.null")
        .order('id', ascending: true);
    if (mounted) {
      setState(() {
        _groups = List<Map<String, dynamic>>.from(rows).map(ItemGroup.fromMap).toList();
        _loading = false;
      });
    }
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
        content: const Text('هل تريد حذف هذه المجموعة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.from('item_groups').delete().eq('id', id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مجموعات الأصناف'),
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
                _CountBanner(count: _groups.length),
                Expanded(
                  child: _groups.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category, size: 64, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('لا توجد مجموعات',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _groups.length,
                          itemBuilder: (ctx, i) {
                            final g = _groups[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      const Color(AppColors.primaryInt),
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(g.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: g.parentId != null
                                    ? Text('فرعية من: ${g.parentId}')
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          color: Color(AppColors.primaryInt)),
                                      onPressed: () =>
                                          _showEditDialog(context, g),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Color(AppColors.dangerInt)),
                                      onPressed: () => _delete(g.id!),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('مجموعة جديدة'),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    _showGroupDialog(context, null);
  }

  void _showEditDialog(BuildContext context, ItemGroup group) {
    _showGroupDialog(context, group);
  }

  void _showGroupDialog(BuildContext context, ItemGroup? existing) {
    final nameCtrl = TextEditingController(text: existing?.name);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(existing == null ? 'إضافة مجموعة' : 'تعديل المجموعة'),
        content: TextFormField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم المجموعة *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryInt),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              if (existing == null) {
                await Supabase.instance.client.from('item_groups').insert({
                  'name': nameCtrl.text.trim(),
                  'store_type': 'electrical',
                  'created_at': DateTime.now().toIso8601String(),
                });
              } else {
                await Supabase.instance.client
                    .from('item_groups')
                    .update({'name': nameCtrl.text.trim()})
                    .eq('id', existing.id!);
              }
              _load();
              if (dlgCtx.mounted) Navigator.pop(dlgCtx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _CountBanner extends StatelessWidget {
  final int count;
  const _CountBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(AppColors.primaryInt),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('إجمالي المجموعات',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            '$count مجموعة',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
