import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/sales_provider.dart';
import '../../../models/item.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../widgets/barcode_scanner_screen.dart';
import 'electrical_bundles_screen.dart';
import 'electrical_pricing_screen.dart';
import '../price_sheet/price_sheet_screen.dart';

/// داشبورد الكهربائيات — يجمع: الإحصائيات + كشف الأسعار + الأصناف
class ElectricalDashboardScreen extends StatefulWidget {
  const ElectricalDashboardScreen({super.key});
  @override
  State<ElectricalDashboardScreen> createState() => _ElectricalDashboardScreenState();
}

class _ElectricalDashboardScreenState extends State<ElectricalDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قسم الكهربائيات'),
        backgroundColor: const Color(AppColors.electricalInt),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'الإحصائيات'),
            Tab(icon: Icon(Icons.receipt_long), text: 'كشف الأسعار'),
            Tab(icon: Icon(Icons.electrical_services), text: 'الأصناف'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.price_change),
            tooltip: 'قائمة الأسعار',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ElectricalPricingScreen())),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _ElectricalStatsTab(),
          _ElectricalPriceSheetTab(),
          ElectricalBundlesScreen(),
        ],
      ),
    );
  }
}

// ─── Tab 1: الإحصائيات ────────────────────────────────────────────────────────

class _ElectricalStatsTab extends StatelessWidget {
  const _ElectricalStatsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (ctx, inv, _) {
        final electrical = inv.items
            .where((i) => i.storeType == AppConstants.storeElectrical)
            .toList();
        final totalItems = electrical.length;
        final lowStock = electrical.where((i) => (i.quantity) < 5).length;
        final totalValue = electrical.fold<double>(
            0, (s, i) => s + (i.priceRetail * (i.quantity)));

        return RefreshIndicator(
          onRefresh: () => context.read<InventoryProvider>().loadAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Stats row
              Row(children: [
                _StatCard(
                  title: 'إجمالي الأصناف',
                  value: '$totalItems',
                  icon: Icons.inventory_2,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  title: 'مخزون منخفض',
                  value: '$lowStock',
                  icon: Icons.warning_amber,
                  color: lowStock > 0 ? Colors.red : Colors.green,
                ),
              ]),
              const SizedBox(height: 12),
              _StatCard(
                title: 'قيمة المخزون (قطاعي)',
                value: AppFormatters.formatCurrency(totalValue),
                icon: Icons.account_balance_wallet,
                color: Colors.green,
                fullWidth: true,
              ),
              const SizedBox(height: 20),
              const Text('أصناف المخزون المنخفض',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (lowStock == 0)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('المخزون كافٍ لجميع الأصناف ✅',
                        style: TextStyle(color: Colors.green)),
                  ),
                )
              else
                ...electrical
                    .where((i) => (i.quantity) < 5)
                    .map((i) => _LowStockCard(item: i))
                    .toList(),
            ]),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool fullWidth;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ]),
      ]),
    );

    if (fullWidth) return card;
    return Expanded(child: card);
  }
}

class _LowStockCard extends StatelessWidget {
  final Item item;
  const _LowStockCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.warning, color: Colors.white, size: 18),
        ),
        title: Text(item.name),
        subtitle: Text('الكمية المتبقية: ${item.quantity}'),
        trailing: Text(
          AppFormatters.formatCurrency(item.priceRetail),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ─── Tab 2: كشف الأسعار المدمج ───────────────────────────────────────────────

class _ElectricalPriceSheetTab extends StatefulWidget {
  const _ElectricalPriceSheetTab();
  @override
  State<_ElectricalPriceSheetTab> createState() => _ElectricalPriceSheetTabState();
}

class _ElectricalPriceSheetTabState extends State<_ElectricalPriceSheetTab> {
  final _searchCtrl = TextEditingController();
  List<Item> _searchResults = [];
  String _priceType = AppConstants.priceRetail;
  final List<_SheetEntry> _entries = [];
  bool _converting = false;

  static const _priceLabels = {
    AppConstants.priceRetail: 'قطاعي',
    AppConstants.priceWholesale: 'جملة',
    AppConstants.priceSemiWholesale: 'نصف جملة',
    AppConstants.priceSpecial: 'خاص',
  };

  double get _total => _entries.fold(0.0, (s, e) => s + e.total(_priceType));

  Future<void> _search(String q) async {
    if (q.isEmpty) { setState(() => _searchResults = []); return; }
    final results = await context.read<InventoryProvider>().search(q);
    // فلترة كهربائيات فقط
    setState(() => _searchResults = results
        .where((i) => i.storeType == AppConstants.storeElectrical)
        .toList());
  }

  Future<void> _scan() async {
    final scanned = await Navigator.push<String>(
      context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
    if (scanned != null && mounted) {
      _searchCtrl.text = scanned;
      await _search(scanned);
    }
  }

  void _addItem(Item item) {
    final idx = _entries.indexWhere((e) => e.item.id == item.id);
    if (idx >= 0) {
      setState(() => _entries[idx] = _entries[idx].copyWith(qty: _entries[idx].qty + 1));
    } else {
      setState(() => _entries.add(_SheetEntry(item: item, qty: 1)));
    }
    _searchCtrl.clear();
    setState(() => _searchResults = []);
  }

  Future<void> _convertToInvoice() async {
    if (_entries.isEmpty) return;
    setState(() => _converting = true);
    final cart = context.read<SalesProvider>();
    cart.clearCart();
    for (final e in _entries) {
      for (int i = 0; i < e.qty; i++) {
        cart.addItem(e.item, priceType: _priceType);
      }
    }
    if (mounted) {
      setState(() { _converting = false; _entries.clear(); });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحويل كشف الأسعار إلى سلة مشتريات. اذهب لإنشاء فاتورة.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Price type selector + search
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          // Price type
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _priceLabels.entries.map((e) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _priceType == e.key,
                  selectedColor: const Color(AppColors.electricalInt),
                  labelStyle: TextStyle(
                    color: _priceType == e.key ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _priceType = e.key),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'ابحث عن صنف كهربائي...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                onChanged: _search,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              color: const Color(AppColors.electricalInt),
              onPressed: _scan,
            ),
          ]),
        ]),
      ),

      // Search results dropdown
      if (_searchResults.isNotEmpty)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _searchResults.take(5).length,
            itemBuilder: (_, i) {
              final item = _searchResults[i];
              final price = _SheetEntry(item: item, qty: 1).unitPrice(_priceType);
              return ListTile(
                dense: true,
                title: Text(item.name),
                subtitle: Text('المخزون: ${item.quantity}'),
                trailing: Text(AppFormatters.formatCurrency(price),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                onTap: () => _addItem(item),
              );
            },
          ),
        ),

      // Items list
      Expanded(
        child: _entries.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('ابحث عن أصناف وأضفها للكشف',
                      style: TextStyle(color: Colors.grey)),
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                itemCount: _entries.length,
                itemBuilder: (_, i) {
                  final e = _entries[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${AppFormatters.formatCurrency(e.unitPrice(_priceType))} × ${e.qty}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ])),
                        // Qty controls
                        Row(children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () {
                              if (e.qty > 1) {
                                setState(() => _entries[i] = e.copyWith(qty: e.qty - 1));
                              } else {
                                setState(() => _entries.removeAt(i));
                              }
                            },
                          ),
                          Text('${e.qty}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () => setState(() => _entries[i] = e.copyWith(qty: e.qty + 1)),
                          ),
                        ]),
                        Text(AppFormatters.formatCurrency(e.total(_priceType)),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ]),
                    ),
                  );
                },
              ),
      ),

      // Footer total + convert button
      if (_entries.isNotEmpty)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('الإجمالي', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(AppFormatters.formatCurrency(_total),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
            ]),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.electricalInt),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _converting ? null : _convertToInvoice,
              icon: _converting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.receipt),
              label: const Text('تحويل لفاتورة'),
            ),
          ]),
        ),
    ]);
  }
}

class _SheetEntry {
  final Item item;
  final int qty;
  const _SheetEntry({required this.item, required this.qty});

  double unitPrice(String priceType) {
    switch (priceType) {
      case AppConstants.priceWholesale: return item.priceWholesale;
      case AppConstants.priceSemiWholesale: return item.priceSemiWholesale;
      case AppConstants.priceSpecial: return item.priceSpecial;
      default: return item.priceRetail;
    }
  }

  double total(String priceType) => unitPrice(priceType) * qty;
  _SheetEntry copyWith({int? qty}) => _SheetEntry(item: item, qty: qty ?? this.qty);
}
