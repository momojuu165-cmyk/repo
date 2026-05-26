import 'package:flutter/material.dart';
import '../../../database/daos/supplier_dao.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class SupplierComparisonScreen extends StatefulWidget {
  const SupplierComparisonScreen({super.key});
  @override
  State<SupplierComparisonScreen> createState() => _SupplierComparisonScreenState();
}

class _SupplierComparisonScreenState extends State<SupplierComparisonScreen> {
  final _dao = SupplierDao();
  List<Map<String, dynamic>> _comparison = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _dao.getProductComparison();
      if (mounted) setState(() { _comparison = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _comparison;
    final q = _search.toLowerCase();
    return _comparison.where((c) =>
        (c['product_name'] as String).toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مقارنة أسعار الموردين'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.compare, size: 72, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('لا توجد بيانات مقارنة بعد',
                              style: TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('أضف منتجات للموردين لتتمكن من مقارنة الأسعار',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                              textAlign: TextAlign.center),
                        ]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) => _ProductComparisonCard(data: _filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ProductComparisonCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProductComparisonCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final productName = data['product_name'] as String;
    final bestPrice = (data['best_price'] as num? ?? 0).toDouble();
    final bestSupplier = data['best_supplier'] as String? ?? '---';
    final lastDate = data['last_date'] as String? ?? '---';
    final prices = data['prices'] as List<Map<String, dynamic>>? ?? [];

    prices.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.inventory_2, color: Colors.green, size: 20),
        ),
        title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(children: [
          const Icon(Icons.star, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text('أفضل سعر: ${AppFormatters.formatCurrency(bestPrice)} — $bestSupplier',
              style: const TextStyle(fontSize: 12)),
        ]),
        trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(AppFormatters.formatCurrency(bestPrice),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
          Text('آخر توريد: $lastDate', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(children: [
              // Header row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Expanded(child: Text('المورد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  SizedBox(width: 8),
                  Text('السعر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  SizedBox(width: 16),
                  Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 6),
              ...prices.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                final price = (p['price'] as num? ?? 0).toDouble();
                final supplierName = p['supplier_name'] as String? ?? '---';
                final date = p['date'] as String? ?? '---';
                final isBest = idx == 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isBest ? Colors.green.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isBest
                        ? Border.all(color: Colors.green.withValues(alpha: 0.3))
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Row(children: [
                        if (isBest) ...[
                          const Icon(Icons.emoji_events, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                        ],
                        Text(supplierName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
                            )),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppFormatters.formatCurrency(price),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isBest ? Colors.green : Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                );
              }),
            ]),
          ),
        ],
      ),
    );
  }
}
