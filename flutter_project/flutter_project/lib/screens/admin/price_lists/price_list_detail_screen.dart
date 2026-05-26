import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/price_list.dart';
import '../../../utils/formatters.dart';
import '../../../utils/constants.dart';

class PriceListDetailScreen extends StatefulWidget {
  final PriceList priceList;
  const PriceListDetailScreen({super.key, required this.priceList});

  @override
  State<PriceListDetailScreen> createState() => _PriceListDetailScreenState();
}

class _PriceListDetailScreenState extends State<PriceListDetailScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await Supabase.instance.client
        .from('price_list_items')
        .select('id, item_id, custom_price, items(name, barcode, price_retail, quantity, unit)')
        .eq('price_list_id', widget.priceList.id!)
        .order('items(name)', ascending: true);
    final mapped = List<Map<String, dynamic>>.from(rows).map((r) {
      final m = Map<String, dynamic>.from(r);
      final item = m['items'] as Map<String, dynamic>?;
      m['item_name'] = item?['name'];
      m['barcode'] = item?['barcode'];
      m['price_retail'] = item?['price_retail'];
      m['quantity'] = item?['quantity'];
      m['unit'] = item?['unit'];
      m.remove('items');
      return m;
    }).toList();
    if (mounted) setState(() { _items = mapped; _loading = false; });
  }

  double _discountedPrice(double customPrice) {
    final disc = widget.priceList.discountRate / 100;
    return customPrice * (1 - disc);
  }

  Future<void> _removeItem(int pliId) async {
    await Supabase.instance.client.from('price_list_items').delete().eq('id', pliId);
    _load();
  }

  Future<void> _editPrice(Map<String, dynamic> row) async {
    final ctrl = TextEditingController(text: row['custom_price'].toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تعديل سعر: ${row['item_name']}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'السعر المخصص', suffixText: 'ج.م'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) {
      final newPrice = double.tryParse(ctrl.text) ?? 0;
      await Supabase.instance.client
          .from('price_list_items')
          .update({'custom_price': newPrice})
          .eq('id', row['id'] as int);
      _load();
    }
  }

  Future<void> _showAddItemsDialog() async {
    final existingIds = _items.map((r) => r['item_id'] as int).toSet();
    final allItemsRows = await Supabase.instance.client
        .from('items')
        .select()
        .eq('store_type', AppConstants.storeElectrical)
        .eq('is_blocked', false)
        .order('name', ascending: true);
    final allItems = List<Map<String, dynamic>>.from(allItemsRows);
    final available = allItems.where((i) => !existingIds.contains(i['id'] as int)).toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddItemsSheet(
        items: available,
        priceListId: widget.priceList.id!,
        discountRate: widget.priceList.discountRate,
        onAdded: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = widget.priceList.discountRate > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.priceList.name),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: _showAddItemsDialog,
        icon: const Icon(Icons.add),
        label: const Text('إضافة منتجات'),
      ),
      body: Column(
        children: [
          // Header info
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(AppColors.primaryInt).withValues(alpha: 0.85),
                  const Color(AppColors.primary2Int).withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.priceList.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (widget.priceList.companyName != null)
                    Text(widget.priceList.companyName!,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('${_items.length} منتج في القائمة',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
              ),
              if (hasDiscount)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    const Text('خصم', style: TextStyle(color: Colors.white, fontSize: 11)),
                    Text('${widget.priceList.discountRate.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                  ]),
                ),
            ]),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_items.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('لا توجد منتجات في هذه القائمة', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddItemsDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة منتجات من المخزن'),
                  ),
                ]),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final row = _items[i];
                  final customPrice = (row['custom_price'] as num).toDouble();
                  final finalPrice = _discountedPrice(customPrice);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(AppColors.primaryInt).withValues(alpha: 0.1),
                        child: const Icon(Icons.electrical_services,
                            color: Color(AppColors.primaryInt), size: 22),
                      ),
                      title: Text(row['item_name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          if (hasDiscount) ...[
                            Text(AppFormatters.formatCurrency(customPrice),
                                style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough)),
                            const SizedBox(width: 6),
                          ],
                          Text(AppFormatters.formatCurrency(finalPrice),
                              style: TextStyle(
                                  color: hasDiscount ? Colors.green : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ]),
                        if (row['unit'] != null)
                          Text('الوحدة: ${row['unit']}',
                              style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ]),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                          onPressed: () => _editPrice(row),
                          tooltip: 'تعديل السعر',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _removeItem(row['id'] as int),
                          tooltip: 'حذف',
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AddItemsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int priceListId;
  final double discountRate;
  final VoidCallback onAdded;

  const _AddItemsSheet({
    required this.items,
    required this.priceListId,
    required this.discountRate,
    required this.onAdded,
  });

  @override
  State<_AddItemsSheet> createState() => _AddItemsSheetState();
}

class _AddItemsSheetState extends State<_AddItemsSheet> {
  String _query = '';
  final Map<int, TextEditingController> _priceCtrl = {};
  final Set<int> _selected = {};

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return widget.items;
    return widget.items
        .where((i) =>
            (i['name'] as String).contains(_query) ||
            ((i['barcode'] as String?) ?? '').contains(_query))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _priceCtrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    try {
      for (final itemId in _selected) {
        final ctrl = _priceCtrl[itemId];
        final price = double.tryParse(ctrl?.text ?? '') ?? 0;
        await Supabase.instance.client.from('price_list_items').insert({
          'price_list_id': widget.priceListId,
          'item_id': itemId,
          'custom_price': price > 0 ? price : 0,
        });
      }
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [
        // Handle
        Container(width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Expanded(
              child: Text('إضافة منتجات من المخزن',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white),
              onPressed: _selected.isEmpty ? null : _save,
              child: Text('إضافة (${_selected.length})'),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'ابحث عن منتج...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('لا توجد منتجات متاحة', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    final id = item['id'] as int;
                    _priceCtrl.putIfAbsent(
                      id,
                      () => TextEditingController(
                          text: (item['price_retail'] as num? ?? 0).toStringAsFixed(0)),
                    );
                    final isSelected = _selected.contains(id);
                    return Card(
                      color: isSelected ? const Color(AppColors.primaryInt).withValues(alpha: 0.06) : null,
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (v) => setState(() {
                          if (v == true) _selected.add(id);
                          else _selected.remove(id);
                        }),
                        title: Text(item['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: isSelected
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: TextFormField(
                                  controller: _priceCtrl[id],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'السعر المخصص',
                                    suffixText: 'ج.م',
                                    helperText: widget.discountRate > 0
                                        ? 'سيطبق عليه خصم ${widget.discountRate.toStringAsFixed(0)}%'
                                        : null,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              )
                            : Text(
                                'سعر التجزئة: ${AppFormatters.formatCurrency((item['price_retail'] as num? ?? 0).toDouble())}',
                                style: const TextStyle(fontSize: 12)),
                        activeColor: const Color(AppColors.primaryInt),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
