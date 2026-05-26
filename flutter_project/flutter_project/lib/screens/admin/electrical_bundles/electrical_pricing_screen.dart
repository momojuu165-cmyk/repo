import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../models/item.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

/// Dedicated electrical pricing screen — shows all electrical products with
/// retail / wholesale / semi-wholesale / special prices side by side.
/// Admin can adjust any price tier inline.
class ElectricalPricingScreen extends StatefulWidget {
  const ElectricalPricingScreen({super.key});
  @override
  State<ElectricalPricingScreen> createState() => _ElectricalPricingScreenState();
}

class _ElectricalPricingScreenState extends State<ElectricalPricingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Item> _items = [];
  List<Item> _filtered = [];
  bool _loading = true;
  String _search = '';

  // Price tiers the user wants to show
  final Map<String, bool> _showTier = {
    AppConstants.priceRetail: true,
    AppConstants.priceWholesale: true,
    AppConstants.priceSemiWholesale: true,
  };

  static const _tierLabels = {
    AppConstants.priceRetail: 'قطاعي',
    AppConstants.priceWholesale: 'جملة',
    AppConstants.priceSemiWholesale: 'نصف جملة',
  };

  static const _tierColors = {
    AppConstants.priceRetail: Colors.blue,
    AppConstants.priceWholesale: Colors.green,
    AppConstants.priceSemiWholesale: Colors.orange,
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await context.read<InventoryProvider>().loadAll();
      if (mounted) {
        // Filter to electrical items only
        final all = context.read<InventoryProvider>().items;
        _items = all.where((i) {
          final cat = (i.category ?? '').toLowerCase();
          final name = (i.name ?? '').toLowerCase();
          return cat.contains('كهرب') || cat.contains('electrical') ||
              name.contains('كهرب') || i.storeType == 'electrical';
        }).toList();
        _applySearch();
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySearch() {
    final q = _search.toLowerCase();
    // Find tiers that are exclusively selected (only one tier ON → filter by it)
    final activeTiers = _showTier.entries.where((e) => e.value).map((e) => e.key).toList();
    final singleTier = activeTiers.length == 1 ? activeTiers.first : null;

    setState(() {
      var base = q.isEmpty
          ? List<dynamic>.from(_items)
          : _items.where((i) =>
              (i.name ?? '').toLowerCase().contains(q) ||
              (i.category ?? '').toLowerCase().contains(q)).toList();

      // When a single tier is selected, only keep products that actually have
      // a price > 0 for that tier (admin-assigned products for this customer type)
      if (singleTier != null) {
        base = base.where((i) => i.priceForType(singleTier) > 0).toList();
      }

      _filtered = base.cast();
    });
  }

  List<String> get _visibleTiers =>
      _showTier.entries.where((e) => e.value).map((e) => e.key).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أسعار الكهربائيات'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.tune), onPressed: _showFilterSheet,
              tooltip: 'إعدادات العرض'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (v) { _search = v; _applySearch(); },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'بحث في المنتجات...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white60),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.electrical_services, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('لا توجد منتجات كهربائية', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    const Text('أضف منتجات بفئة "كهربائيات" من شاشة المخزون',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                )
              : Column(children: [
                  // ── Quick role filter ──────────────────────────────────────
                  Container(
                    color: Colors.grey.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(children: [
                      const Text('عرض سعر:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            _QuickRoleButton(
                              label: 'كل الأسعار',
                              icon: Icons.grid_view,
                              active: _showTier.values.every((v) => v),
                              onTap: () => setState(() {
                                _showTier[AppConstants.priceRetail] = true;
                                _showTier[AppConstants.priceWholesale] = true;
                                _showTier[AppConstants.priceSemiWholesale] = true;
                              }),
                            ),
                            const SizedBox(width: 6),
                            _QuickRoleButton(
                              label: 'جملة',
                              icon: Icons.store,
                              color: Colors.green,
                              active: _showTier[AppConstants.priceWholesale] == true &&
                                  _showTier[AppConstants.priceRetail] == false &&
                                  _showTier[AppConstants.priceSemiWholesale] == false,
                              onTap: () => setState(() {
                                _showTier[AppConstants.priceRetail] = false;
                                _showTier[AppConstants.priceWholesale] = true;
                                _showTier[AppConstants.priceSemiWholesale] = false;
                              }),
                            ),
                            const SizedBox(width: 6),
                            _QuickRoleButton(
                              label: 'نصف جملة',
                              icon: Icons.storefront,
                              color: Colors.orange,
                              active: _showTier[AppConstants.priceSemiWholesale] == true &&
                                  _showTier[AppConstants.priceRetail] == false &&
                                  _showTier[AppConstants.priceWholesale] == false,
                              onTap: () => setState(() {
                                _showTier[AppConstants.priceRetail] = false;
                                _showTier[AppConstants.priceWholesale] = false;
                                _showTier[AppConstants.priceSemiWholesale] = true;
                              }),
                            ),
                            const SizedBox(width: 6),
                            _QuickRoleButton(
                              label: 'قطاعي',
                              icon: Icons.person,
                              color: Colors.blue,
                              active: _showTier[AppConstants.priceRetail] == true &&
                                  _showTier[AppConstants.priceWholesale] == false &&
                                  _showTier[AppConstants.priceSemiWholesale] == false,
                              onTap: () => setState(() {
                                _showTier[AppConstants.priceRetail] = true;
                                _showTier[AppConstants.priceWholesale] = false;
                                _showTier[AppConstants.priceSemiWholesale] = false;
                              }),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                  // Tier chips
                  _TierChips(showTier: _showTier, onToggle: (tier) {
                    setState(() => _showTier[tier] = !(_showTier[tier] ?? false));
                  }),
                  const Divider(height: 1),
                  // Price table header
                  _PriceTableHeader(visibleTiers: _visibleTiers),
                  const Divider(height: 1),
                  // Items
                  Expanded(
                    child: ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) => _PriceRow(
                        item: _filtered[i],
                        visibleTiers: _visibleTiers,
                        onEdit: () => _showEditPriceSheet(_filtered[i]),
                      ),
                    ),
                  ),
                  // Summary bar
                  _SummaryBar(items: _filtered, visibleTiers: _visibleTiers),
                ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: _showBatchMarkupSheet,
        icon: const Icon(Icons.percent),
        label: const Text('زيادة سعرية دفعة واحدة'),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('إعدادات العرض', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          ...(_showTier.keys.map((tier) => SwitchListTile(
            title: Text(_tierLabels[tier] ?? tier),
            value: _showTier[tier] ?? false,
            onChanged: (v) {
              setS(() => _showTier[tier] = v);
              setState(() {});
            },
          ))),
        ]),
      )),
    );
  }

  void _showEditPriceSheet(Item item) {
    final retailCtrl = TextEditingController(
        text: item.priceForType(AppConstants.priceRetail).toStringAsFixed(2));
    final wholesaleCtrl = TextEditingController(
        text: item.priceForType(AppConstants.priceWholesale).toStringAsFixed(2));
    final semiCtrl = TextEditingController(
        text: item.priceForType(AppConstants.priceSemiWholesale).toStringAsFixed(2));
    final costCtrl = TextEditingController(
        text: item.purchasePrice.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('تعديل أسعار: ${item.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            _PriceField(controller: costCtrl, label: 'سعر التكلفة', color: Colors.grey),
            const Divider(height: 20),
            _PriceField(controller: retailCtrl, label: 'قطاعي', color: Colors.blue),
            const SizedBox(height: 10),
            _PriceField(controller: wholesaleCtrl, label: 'جملة', color: Colors.green),
            const SizedBox(height: 10),
            _PriceField(controller: semiCtrl, label: 'نصف جملة', color: Colors.orange),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppColors.primaryInt),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () async {
                  // Build updated item with new prices
                  final updatedItem = Item(
                    id: item.id, name: item.name, category: item.category,
                    quantity: item.quantity, unit: item.unit,
                    priceRetail: double.tryParse(retailCtrl.text) ?? item.priceRetail,
                    priceWholesale: double.tryParse(wholesaleCtrl.text) ?? item.priceWholesale,
                    priceSemiWholesale: double.tryParse(semiCtrl.text) ?? item.priceSemiWholesale,
                    priceSpecial: item.priceSpecial,
                    purchasePrice: double.tryParse(costCtrl.text) ?? item.purchasePrice,
                    barcode: item.barcode, storeType: item.storeType,
                    notes: item.notes, imagePath: item.imagePath,
                    createdAt: item.createdAt,
                  );
                  await context.read<InventoryProvider>().updateItem(updatedItem);
                  _load();
                  if (ctx.mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تحديث أسعار ${item.name} ✓'),
                        backgroundColor: Colors.green),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('حفظ الأسعار'),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _showBatchMarkupSheet() {
    final pctCtrl = TextEditingController(text: '10');
    String targetTier = AppConstants.priceRetail;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('زيادة سعرية جماعية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text('ستطبق على ${_filtered.length} منتج',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: targetTier,
            decoration: const InputDecoration(labelText: 'نوع السعر المستهدف'),
            items: _tierLabels.entries.map((e) =>
                DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setS(() => targetTier = v ?? AppConstants.priceRetail),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: pctCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'نسبة الزيادة %',
              helperText: 'مثال: 10 يزيد كل سعر بـ 10%',
              suffixText: '%',
              prefixIcon: Icon(Icons.percent),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                final pct = double.tryParse(pctCtrl.text) ?? 0;
                if (pct <= 0) return;
                final inv = context.read<InventoryProvider>();
                for (final item in _filtered) {
                  final current = item.priceForType(targetTier);
                  final newPrice = current * (1 + pct / 100);
                  double? retail, wholesale, semi;
                  if (targetTier == AppConstants.priceRetail) retail = newPrice;
                  if (targetTier == AppConstants.priceWholesale) wholesale = newPrice;
                  if (targetTier == AppConstants.priceSemiWholesale) semi = newPrice;
                  await inv.updateItem(Item(
                    id: item.id, name: item.name, category: item.category,
                    quantity: item.quantity, unit: item.unit,
                    priceRetail: retail ?? item.priceRetail,
                    priceWholesale: wholesale ?? item.priceWholesale,
                    priceSemiWholesale: semi ?? item.priceSemiWholesale,
                    priceSpecial: item.priceSpecial,
                    purchasePrice: item.purchasePrice, barcode: item.barcode,
                    storeType: item.storeType, notes: item.notes,
                    imagePath: item.imagePath, createdAt: item.createdAt,
                  ));
                }
                _load();
                if (ctx.mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم تحديث ${_filtered.length} منتج بزيادة $pct% ✓'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              icon: const Icon(Icons.update),
              label: Text('تطبيق +${pctCtrl.text}% على ${_tierLabels[targetTier]}'),
            ),
          ),
        ]),
      )),
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _TierChips extends StatelessWidget {
  final Map<String, bool> showTier;
  final void Function(String) onToggle;
  const _TierChips({required this.showTier, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    const labels = {
      AppConstants.priceRetail: 'قطاعي',
      AppConstants.priceWholesale: 'جملة',
      AppConstants.priceSemiWholesale: 'نصف جملة',
    };
    const colors = {
      AppConstants.priceRetail: Colors.blue,
      AppConstants.priceWholesale: Colors.green,
      AppConstants.priceSemiWholesale: Colors.orange,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: showTier.keys.map((tier) {
          final active = showTier[tier] ?? false;
          final color = colors[tier] ?? Colors.grey;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: FilterChip(
              label: Text(labels[tier] ?? tier,
                  style: TextStyle(color: active ? Colors.white : color,
                      fontSize: 12, fontWeight: FontWeight.bold)),
              selected: active,
              onSelected: (_) => onToggle(tier),
              backgroundColor: color.withValues(alpha: 0.08),
              selectedColor: color,
              checkmarkColor: Colors.white,
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PriceTableHeader extends StatelessWidget {
  final List<String> visibleTiers;
  const _PriceTableHeader({required this.visibleTiers});

  @override
  Widget build(BuildContext context) {
    const labels = {
      AppConstants.priceRetail: 'قطاعي',
      AppConstants.priceWholesale: 'جملة',
      AppConstants.priceSemiWholesale: 'نصف جملة',
    };
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        const Expanded(flex: 3, child: Text('المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ...visibleTiers.map((t) => Expanded(
          flex: 2,
          child: Text(labels[t] ?? t,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              textAlign: TextAlign.center),
        )),
        const SizedBox(width: 32),
      ]),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final Item item;
  final List<String> visibleTiers;
  final VoidCallback onEdit;
  const _PriceRow({required this.item, required this.visibleTiers, required this.onEdit});

  static const _colors = {
    AppConstants.priceRetail: Colors.blue,
    AppConstants.priceWholesale: Colors.green,
    AppConstants.priceSemiWholesale: Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (item.category != null)
                Text(item.category!, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              Text('الكمية: ${item.quantity}',
                  style: TextStyle(fontSize: 10,
                      color: item.quantity <= 0 ? Colors.red : Colors.grey)),
            ]),
          ),
          ...visibleTiers.map((tier) {
            final price = item.priceForType(tier);
            final color = _colors[tier] ?? Colors.grey;
            return Expanded(
              flex: 2,
              child: Column(children: [
                Text(
                  AppFormatters.formatCurrency(price),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                  textAlign: TextAlign.center,
                ),
                if (item.purchasePrice > 0)
                  Text(
                    '+${((price - item.purchasePrice) / item.purchasePrice * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7)),
                  ),
              ]),
            );
          }),
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
            onPressed: onEdit,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        ]),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final List<Item> items;
  final List<String> visibleTiers;
  const _SummaryBar({required this.items, required this.visibleTiers});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Text('${items.length} منتج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Spacer(),
        Text(
          'متوسط قطاعي: ${AppFormatters.formatCurrency(items.isEmpty ? 0 : items.fold(0.0, (s, i) => s + i.priceForType(AppConstants.priceRetail)) / items.length)}',
          style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

class _QuickRoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color color;
  const _QuickRoleButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.color = const Color(AppColors.primaryInt),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : Colors.grey.shade300,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: active ? color : Colors.grey),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: active ? color : Colors.grey,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color;
  const _PriceField({required this.controller, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: color),
      suffixText: 'ج.م',
      prefixIcon: Icon(Icons.attach_money, color: color),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: 2),
      ),
    ),
  );
}
