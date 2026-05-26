import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/constants.dart';

class InstallmentCategoriesScreen extends StatefulWidget {
  /// When provided, shows/manages categories for that specific store type.
  /// Defaults to [AppConstants.storeInstallment] for backwards-compatibility.
  final String? initialStoreType;

  const InstallmentCategoriesScreen({super.key, this.initialStoreType});

  @override
  State<InstallmentCategoriesScreen> createState() =>
      _InstallmentCategoriesScreenState();
}

class _InstallmentCategoriesScreenState
    extends State<InstallmentCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  String get _storeType =>
      widget.initialStoreType ?? AppConstants.storeInstallment;

  String get _screenTitle {
    switch (_storeType) {
      case AppConstants.storeInstallment: return 'فئات التقسيط';
      case AppConstants.storeElectrical: return 'فئات الكهربائية';
      case AppConstants.storeClothing: return 'فئات الملابس';
      case AppConstants.storeMobiles: return 'فئات الموبايلات';
      case AppConstants.storeAccessories: return 'فئات الإكسسوارات';
      default:
        return 'فئات ${AppConstants.deptLabels[_storeType] ?? _storeType}';
    }
  }

  Color get _headerColor {
    switch (_storeType) {
      case AppConstants.storeInstallment: return const Color(AppColors.installmentInt);
      case AppConstants.storeElectrical: return const Color(AppColors.electricalInt);
      case AppConstants.storeClothing: return const Color(AppColors.clothingInt);
      case AppConstants.storeMobiles: return const Color(AppColors.mobilesInt);
      case AppConstants.storeAccessories: return const Color(AppColors.accessoriesInt);
      default: return const Color(AppColors.primaryInt);
    }
  }

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
        .eq('store_type', _storeType)
        .order('name', ascending: true);
    if (mounted) {
      setState(() {
        _categories = List<Map<String, dynamic>>.from(rows);
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
        content: const Text('هل تريد حذف هذه الفئة؟'),
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
      await Supabase.instance.client
          .from('item_groups')
          .delete()
          .eq('id', id);
      _load();
    }
  }

  void _showAddDialog([Map<String, dynamic>? existing]) {
    final nameCtrl = TextEditingController(text: existing?['name'] as String?);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(existing == null ? 'إضافة فئة' : 'تعديل الفئة'),
        content: TextFormField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم الفئة *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _headerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              if (existing == null) {
                await Supabase.instance.client.from('item_groups').insert({
                  'name': name,
                  'store_type': _storeType,
                  'created_at': DateTime.now().toIso8601String(),
                });
              } else {
                await Supabase.instance.client
                    .from('item_groups')
                    .update({'name': name})
                    .eq('id', existing['id'] as int);
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
        title: Text(_screenTitle),
        backgroundColor: _headerColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: _headerColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي الفئات',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        '${_categories.length} فئة',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _categories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.category,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text('لا توجد فئات بعد',
                                  style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _categories.length,
                          itemBuilder: (ctx, i) {
                            final g = _categories[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _headerColor,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(g['name'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined,
                                          color: _headerColor),
                                      onPressed: () => _showAddDialog(g),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Color(AppColors.dangerInt)),
                                      onPressed: () =>
                                          _delete(g['id'] as int),
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
        backgroundColor: _headerColor,
        foregroundColor: Colors.white,
        onPressed: () => _showAddDialog(),
        icon: const Icon(Icons.add),
        label: const Text('فئة جديدة'),
      ),
    );
  }
}
