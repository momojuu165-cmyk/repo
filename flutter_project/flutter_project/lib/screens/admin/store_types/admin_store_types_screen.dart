import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/constants.dart';
import '../../../database/daos/user_dao.dart';
import '../../../models/user.dart' as app_models;
import '../installment_products/installment_products_screen.dart';
import '../requests/requests_screen.dart';

// ── AdminStoreTypesScreen ─────────────────────────────────────────────────────
// Full system management hub. Admin creates custom systems that each have their
// own products, categories, requests, and an assigned manager.

class AdminStoreTypesScreen extends StatefulWidget {
  const AdminStoreTypesScreen({super.key});

  @override
  State<AdminStoreTypesScreen> createState() => _AdminStoreTypesScreenState();
}

class _AdminStoreTypesScreenState extends State<AdminStoreTypesScreen> {
  List<Map<String, dynamic>> _systems = [];
  List<app_models.User> _managers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.teal;
    try {
      return Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);
    } catch (_) {
      return Colors.teal;
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('custom_store_types')
          .select()
          .order('name', ascending: true);
      List<app_models.User> managers = [];
      try {
        managers = await UserDao().getByRole('manager');
      } catch (_) {}
      if (mounted) {
        setState(() {
          _systems = List<Map<String, dynamic>>.from(rows);
          _managers = managers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id, String slug) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف النظام'),
        content: const Text('هل تريد حذف هذا النظام؟ سيتم حذف جميع فئاته المرتبطة.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await Supabase.instance.client
            .from('item_groups')
            .delete()
            .eq('store_type', slug);
        await Supabase.instance.client
            .from('custom_store_types')
            .delete()
            .eq('id', id);
      } catch (_) {}
      _load();
    }
  }

  void _showForm([Map<String, dynamic>? existing]) {
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');
    final colors = [
      Colors.teal, Colors.indigo, Colors.brown, Colors.deepPurple,
      Colors.cyan, Colors.pink, Colors.orange, Colors.green,
      Colors.red, Colors.blueGrey, Colors.deepOrange, Colors.purple,
    ];
    Color selectedColor = Colors.teal;
    int? selectedManagerId = existing?['manager_user_id'] as int?;

    if (existing != null) {
      final hex = existing['color_hex'] as String? ?? '';
      try {
        selectedColor =
            Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'نظام جديد' : 'تعديل النظام'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'اسم النظام *',
                    hintText: 'مثال: موبايلات، ساعات...',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                    labelText: 'وصف النظام (اختياري)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('لون النظام:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors
                    .map((c) => GestureDetector(
                          onTap: () => setS(() => selectedColor = c),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == c
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: selectedColor == c
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        ))
                    .toList(),
              ),
              if (_managers.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: selectedManagerId,
                  decoration: const InputDecoration(
                      labelText: 'المدير المسؤول عن النظام',
                      prefixIcon: Icon(Icons.manage_accounts),
                      border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('بدون مدير مخصص')),
                    ..._managers.map((m) => DropdownMenuItem<int?>(
                        value: m.id, child: Text(m.name))),
                  ],
                  onChanged: (v) => setS(() => selectedManagerId = v),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final colorHex =
                    '#${(selectedColor.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
                final slug = existing != null
                    ? existing['slug'] as String
                    : 'custom_${DateTime.now().millisecondsSinceEpoch}';
                final baseRow = <String, dynamic>{
                  'name': name,
                  'color_hex': colorHex,
                  'description': descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  'manager_user_id': selectedManagerId,
                };
                try {
                  if (existing == null) {
                    await Supabase.instance.client
                        .from('custom_store_types')
                        .insert({
                      ...baseRow,
                      'slug': slug,
                      'created_at': DateTime.now().toIso8601String(),
                    });
                  } else {
                    await Supabase.instance.client
                        .from('custom_store_types')
                        .update(baseRow)
                        .eq('id', existing['id'] as int);
                  }
                } catch (_) {
                  // Retry without optional columns if they don't exist yet in DB
                  final safeRow = <String, dynamic>{
                    'name': name,
                    'color_hex': colorHex,
                  };
                  if (existing == null) {
                    await Supabase.instance.client
                        .from('custom_store_types')
                        .insert({
                      ...safeRow,
                      'slug': slug,
                      'created_at': DateTime.now().toIso8601String(),
                    });
                  } else {
                    await Supabase.instance.client
                        .from('custom_store_types')
                        .update(safeRow)
                        .eq('id', existing['id'] as int);
                  }
                }
                _load();
                if (dlgCtx.mounted) Navigator.pop(dlgCtx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأنظمة'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('نظام جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                width: double.infinity,
                color: const Color(AppColors.primaryInt),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  '${_systems.length} نظام مخصص',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
              if (_systems.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.store_mall_directory,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('لا توجد أنظمة مخصصة بعد',
                          style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 4),
                      Text('اضغط على + لإضافة نظام جديد',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _systems.length,
                    itemBuilder: (ctx, i) {
                      final sys = _systems[i];
                      final color = _parseColor(sys['color_hex'] as String?);
                      final managerId = sys['manager_user_id'] as int?;
                      final managerName = managerId == null
                          ? null
                          : _managers
                              .where((m) => m.id == managerId)
                              .map((m) => m.name)
                              .firstOrNull;
                      return _SystemCard(
                        sys: sys,
                        color: color,
                        managerName: managerName,
                        onEdit: () => _showForm(sys),
                        onDelete: () =>
                            _delete(sys['id'] as int, sys['slug'] as String),
                      );
                    },
                  ),
                ),
            ]),
    );
  }
}

// ── System card widget ────────────────────────────────────────────────────────

class _SystemCard extends StatelessWidget {
  final Map<String, dynamic> sys;
  final Color color;
  final String? managerName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SystemCard({
    required this.sys,
    required this.color,
    this.managerName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = sys['name'] as String;
    final slug = sys['slug'] as String;
    final desc = sys['description'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: color,
              child: const Icon(Icons.store, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: color)),
                    if (desc != null && desc.isNotEmpty)
                      Text(desc,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    Row(children: [
                      Icon(Icons.manage_accounts,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                          managerName != null
                              ? 'المدير: $managerName'
                              : 'بدون مدير مخصص',
                          style: TextStyle(
                              fontSize: 11,
                              color: managerName != null
                                  ? Colors.grey.shade700
                                  : Colors.grey)),
                    ]),
                  ]),
            ),
            IconButton(
                icon: Icon(Icons.edit_outlined, color: color, size: 20),
                onPressed: onEdit),
            IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: onDelete),
          ]),
        ),

        // ── Action buttons ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: _ActionBtn(
                icon: Icons.inventory_2_outlined,
                label: 'المنتجات',
                color: color,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          InstallmentProductsScreen(initialStoreType: slug)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                icon: Icons.category_outlined,
                label: 'الفئات',
                color: color,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomStoreCategoriesScreen(
                      storeTypeName: name,
                      storeTypeSlug: slug,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                icon: Icons.list_alt_outlined,
                label: 'الطلبات',
                color: color,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RequestsScreen(storeType: slug)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

// ── Generic categories screen for any custom store type ───────────────────────

class CustomStoreCategoriesScreen extends StatefulWidget {
  final String storeTypeName;
  final String storeTypeSlug;
  final Color color;

  const CustomStoreCategoriesScreen({
    super.key,
    required this.storeTypeName,
    required this.storeTypeSlug,
    required this.color,
  });

  @override
  State<CustomStoreCategoriesScreen> createState() =>
      _CustomStoreCategoriesScreenState();
}

class _CustomStoreCategoriesScreenState
    extends State<CustomStoreCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await Supabase.instance.client
        .from('item_groups')
        .select()
        .eq('store_type', widget.storeTypeSlug)
        .order('name', ascending: true);
    if (mounted) {
      setState(() {
        _categories = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الفئة'),
        content: const Text('هل تريد حذف هذه الفئة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client.from('item_groups').delete().eq('id', id);
      _load();
    }
  }

  void _showAddDialog([Map<String, dynamic>? existing]) {
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(existing == null ? 'فئة جديدة' : 'تعديل الفئة'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'اسم الفئة *', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              if (existing == null) {
                await Supabase.instance.client.from('item_groups').insert({
                  'name': name,
                  'store_type': widget.storeTypeSlug,
                  'created_at': DateTime.now().toIso8601String(),
                });
              } else {
                await Supabase.instance.client
                    .from('item_groups')
                    .update({'name': name}).eq('id', existing['id'] as int);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('فئات ${widget.storeTypeName}'),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('فئة جديدة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.category,
                        size: 64, color: widget.color.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    const Text('لا توجد فئات بعد',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Text('اضغط على + لإضافة فئة',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    final g = _categories[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: widget.color.withValues(alpha: 0.15),
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  color: widget.color,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(g['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              icon: Icon(Icons.edit_outlined,
                                  color: widget.color),
                              onPressed: () => _showAddDialog(g)),
                          IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _delete(g['id'] as int)),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
