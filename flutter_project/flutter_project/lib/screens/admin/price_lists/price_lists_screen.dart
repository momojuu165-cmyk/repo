import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/price_list.dart';
import '../../../utils/constants.dart';
import 'price_list_detail_screen.dart';

class PriceListsScreen extends StatefulWidget {
  const PriceListsScreen({super.key});
  @override
  State<PriceListsScreen> createState() => _PriceListsScreenState();
}

class _PriceListsScreenState extends State<PriceListsScreen> {
  List<Map<String, dynamic>> _lists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {

    final plRows = await Supabase.instance.client
        .from('price_lists')
        .select('*, price_list_items(id)')
        .order('name', ascending: true);
    final rows = List<Map<String, dynamic>>.from(plRows).map((r) {
      final m = Map<String, dynamic>.from(r);
      final items = m['price_list_items'] as List<dynamic>? ?? [];
      m['item_count'] = items.length;
      m.remove('price_list_items');
      return m;
    }).toList();
    if (mounted) setState(() { _lists = rows; _loading = false; });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('سيتم حذف الليسته وجميع منتجاتها. هل أنت متأكد؟'),
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
    if (ok == true) {
      await Supabase.instance.client
          .from('price_list_items')
          .delete()
          .eq('price_list_id', id);
      await Supabase.instance.client
          .from('price_lists')
          .delete()
          .eq('id', id);
      _load();
    }
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final companyCtrl = TextEditingController(text: existing?['company_name'] as String? ?? '');
    final discCtrl = TextEditingController(
        text: (existing?['discount_rate'] as num? ?? 0).toStringAsFixed(0));
    final markupCtrl = TextEditingController(
        text: (existing?['markup_rate'] as num? ?? 0).toStringAsFixed(0));
    bool isFree = (existing?['is_free'] as int? ?? 1) == 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20, right: 20, top: 20,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(existing == null ? 'إضافة ليسته جديدة' : 'تعديل الليسته',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم الليسته *', prefixIcon: Icon(Icons.list_alt)),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ليسته حرة (غير مرتبطة بشركة)'),
              value: isFree,
              onChanged: (v) => setS(() => isFree = v),
              activeColor: const Color(AppColors.primaryInt),
            ),
            if (!isFree) ...[
              TextFormField(
                controller: companyCtrl,
                decoration: const InputDecoration(
                    labelText: 'اسم الشركة', prefixIcon: Icon(Icons.business)),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: discCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'نسبة الخصم %',
                    hintText: '0',
                    prefixIcon: Icon(Icons.discount, color: Colors.orange),
                    suffixText: '%',
                    helperText: 'خصم على الأسعار',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: markupCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'نسبة الزيادة %',
                    hintText: '0',
                    prefixIcon: Icon(Icons.trending_up, color: Colors.green),
                    suffixText: '%',
                    helperText: 'زيادة على الأسعار',
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppColors.primaryInt),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'company_name': isFree
                        ? null
                        : (companyCtrl.text.trim().isEmpty ? null : companyCtrl.text.trim()),
                    'is_free': isFree ? 1 : 0,
                    'discount_rate': double.tryParse(discCtrl.text) ?? 0,
                    'markup_rate': double.tryParse(markupCtrl.text) ?? 0,
                  };
                  if (existing == null) {
                    await Supabase.instance.client.from('price_lists').insert(data);
                  } else {
                    await Supabase.instance.client
                        .from('price_lists')
                        .update(data)
                        .eq('id', existing['id'] as int);
                  }
                  _load();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'إنشاء الليسته' : 'حفظ التعديلات'),
              ),
            ),
          ]),
        );
      }),
    );
  }

  void _openDetail(Map<String, dynamic> row) {
    final pl = PriceList(
      id: row['id'] as int,
      name: row['name'] as String,
      companyName: row['company_name'] as String?,
      isFree: (row['is_free'] as int? ?? 1) == 1,
      discountRate: (row['discount_rate'] as num? ?? 0).toDouble(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PriceListDetailScreen(priceList: pl)),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الليستات الكهربائية'),
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
        label: const Text('ليسته جديدة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.price_change, size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('لا توجد ليستات بعد',
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('أنشئ ليسته وأضف لها منتجات كهربائية مع خصم مخصص',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AppColors.primaryInt),
                          foregroundColor: Colors.white),
                      onPressed: () => _showForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('إنشاء ليسته أسعار'),
                    ),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                  itemCount: _lists.length,
                  itemBuilder: (ctx, i) {
                    final row = _lists[i];
                    final isFree = (row['is_free'] as int? ?? 1) == 1;
                    final discount = (row['discount_rate'] as num? ?? 0).toDouble();
                    final markup = (row['markup_rate'] as num? ?? 0).toDouble();
                    final itemCount = row['item_count'] as int? ?? 0;
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openDetail(row),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: (isFree ? Colors.green : Colors.blue).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isFree ? Icons.price_check : Icons.business,
                                color: isFree ? Colors.green : Colors.blue,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(row['name'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                if (!isFree && row['company_name'] != null)
                                  Text(row['company_name'] as String,
                                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Row(children: [
                                  Icon(Icons.inventory_2, size: 13, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text('$itemCount منتج',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.chevron_left, size: 14, color: Colors.grey),
                                  const Text('اضغط لإدارة المنتجات',
                                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ]),
                              ]),
                            ),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              if (discount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${discount.toStringAsFixed(0)}% خصم',
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              if (markup > 0) ...[
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${markup.toStringAsFixed(0)}% زيادة',
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                              if (discount == 0 && markup == 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('بدون خصم',
                                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                                ),
                              const SizedBox(height: 4),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () => _showForm(existing: row),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () => _delete(row['id'] as int),
                                ),
                              ]),
                            ]),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
