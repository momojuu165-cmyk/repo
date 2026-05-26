import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/daos/installment_product_dao.dart';
import '../../database/daos/customer_dao.dart';
import '../../models/installment_product.dart';
import '../../models/customer.dart';
import '../../models/item_group.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_drawer.dart';
import '../admin/installment_products/installment_products_screen.dart';
import '../admin/installment_products/product_detail_screen.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _deptColor(String storeType) {
  switch (storeType) {
    case AppConstants.storeClothing:
      return const Color(AppColors.clothingInt);
    case AppConstants.storeElectrical:
      return const Color(AppColors.electricalInt);
    case AppConstants.storeInstallment:
      return const Color(AppColors.installmentInt);
    default:
      return const Color(AppColors.primaryInt);
  }
}

IconData _deptIcon(String storeType) {
  switch (storeType) {
    case AppConstants.storeClothing:
      return Icons.checkroom;
    case AppConstants.storeElectrical:
      return Icons.electrical_services;
    case AppConstants.storeInstallment:
      return Icons.payment;
    default:
      return Icons.category;
  }
}

String _deptName(String storeType) {
  return AppConstants.deptLabels[storeType] ?? 'قسم $storeType';
}

// ─── Main Dashboard Widget ─────────────────────────────────────────────────────

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});
  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _tab = 0;
  String? _customDeptName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storeType = context.read<AuthProvider>().departmentType;
    if (storeType != null && !AppConstants.deptLabels.containsKey(storeType) && _customDeptName == null) {
      _fetchCustomDeptName(storeType);
    }
  }

  Future<void> _fetchCustomDeptName(String slug) async {
    try {
      final rows = await Supabase.instance.client
          .from('custom_store_types')
          .select('name')
          .eq('slug', slug)
          .limit(1);
      if (rows.isNotEmpty && mounted) {
        setState(() => _customDeptName = rows.first['name'] as String?);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final storeType = auth.departmentType ?? AppConstants.storeClothing;
    final color = _deptColor(storeType);
    final icon = _deptIcon(storeType);
    final deptName = _customDeptName ?? _deptName(storeType);

    final pages = [
      _HomeTab(storeType: storeType, color: color, icon: icon, deptName: deptName,
          onSwitchTab: (i) => setState(() => _tab = i)),
      _ProductsTab(storeType: storeType, color: color),
      _CustomersTab(storeType: storeType, color: color),
      _InstallmentsTab(storeType: storeType, color: color),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text('$deptName - ${auth.currentUserName}'),
          ]),
          backgroundColor: color,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                }
              },
            ),
          ],
        ),
        body: IndexedStack(index: _tab, children: pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: color,
          unselectedItemColor: Colors.grey,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(icon), label: 'المنتجات'),
            const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'العملاء'),
            const BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'الأقساط'),
          ],
        ),
      ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final String storeType;
  final Color color;
  final IconData icon;
  final String deptName;
  final void Function(int) onSwitchTab;
  const _HomeTab({required this.storeType, required this.color, required this.icon, required this.deptName, required this.onSwitchTab});
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  int _productsCount = 0;
  int _customersCount = 0;
  int _activeInstallments = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final st = widget.storeType;

    final prodsRows = await client
        .from('installment_products')
        .select('id')
        .eq('is_available', true)
        .or('store_type.eq.$st,category.ilike.%$st%');

    final custsRows = await client
        .from('customers')
        .select('id')
        .eq('store_type', st)
        .eq('is_active', true);

    final instsRows = await client
        .from('installments')
        .select('id, customers(store_type)')
        .eq('status', 'active');

    final filteredInsts = List<Map<String, dynamic>>.from(instsRows).where((r) {
      final c = r['customers'] as Map<String, dynamic>?;
      return c?['store_type'] == st;
    }).length;

    if (mounted) {
      setState(() {
        _productsCount = prodsRows.length;
        _customersCount = custsRows.length;
        _activeInstallments = filteredInsts;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Welcome Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.color, widget.color.withValues(alpha: 0.7)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Icon(widget.icon, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('أهلاً، ${auth.currentUserName}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('مدير ${widget.deptName}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Stats
        const Text('إحصائيات القسم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(
            title: 'منتجات ${widget.deptName}',
            value: '$_productsCount',
            icon: widget.icon,
            color: widget.color,
          )),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(
            title: 'عملاء ${widget.deptName}',
            value: '$_customersCount',
            icon: Icons.people,
            color: Colors.blue,
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(
            title: 'الأقساط النشطة',
            value: '$_activeInstallments',
            icon: Icons.payment,
            color: Colors.green,
          )),
          const Expanded(child: SizedBox()),
        ]),
        const SizedBox(height: 20),

        // Quick Actions
        const Text('العمليات المتاحة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _ActionCard(
              title: 'إدارة المنتجات',
              icon: widget.icon,
              color: widget.color,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => InstallmentProductsScreen(initialStoreType: widget.storeType))),
            ),
            _ActionCard(
              title: 'إضافة منتج',
              icon: Icons.add_shopping_cart,
              color: Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => InstallmentProductsScreen(initialStoreType: widget.storeType))),
            ),
            _ActionCard(
              title: 'عملاء ${widget.deptName}',
              icon: Icons.people,
              color: Colors.blue,
              onTap: () => widget.onSwitchTab(2),
            ),
            _ActionCard(
              title: 'أقساط ${widget.deptName}',
              icon: Icons.payment,
              color: Colors.green,
              onTap: () => widget.onSwitchTab(3),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'أنت مخصص لإدارة عمليات ${widget.deptName} فقط. للوصول إلى أقسام أخرى تواصل مع المدير.',
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Stat & Action Cards ───────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ])),
        ]),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ─── Products Tab ──────────────────────────────────────────────────────────────

class _ProductsTab extends StatefulWidget {
  final String storeType;
  final Color color;
  const _ProductsTab({required this.storeType, required this.color});
  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> with SingleTickerProviderStateMixin {
  final _dao = InstallmentProductDao();
  List<InstallmentProduct> _all = [];
  List<ItemGroup> _groups = [];
  List<String> _categories = [];
  TabController? _tabCtrl;
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final st = widget.storeType;

    final groupRows = await Supabase.instance.client
        .from('item_groups')
        .select()
        .eq('store_type', st)
        .order('name', ascending: true);
    final groups = List<Map<String, dynamic>>.from(groupRows)
        .map(ItemGroup.fromMap)
        .toList();
    final cats = groups.map((g) => g.name).toList();

    final all = await _dao.getAll();
    final filtered = all.where((p) {
      if (p.storeType == st) return true;
      if (cats.contains(p.category)) return true;
      return false;
    }).toList();

    _tabCtrl?.dispose();
    _tabCtrl = TabController(length: cats.isEmpty ? 1 : cats.length + 1, vsync: this);
    if (mounted) {
      setState(() {
        _all = filtered;
        _groups = groups;
        _categories = cats;
        _loading = false;
      });
    }
  }

  List<InstallmentProduct> _filtered(String? cat) {
    var list = cat == null ? _all : _all.where((p) => p.category == cat).toList();
    if (_search.isNotEmpty) list = list.where((p) => p.name.contains(_search)).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث في المنتجات...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.category, color: widget.color),
            tooltip: 'إدارة الفئات',
            onPressed: _showManageCategoriesDialog,
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => InstallmentProductsScreen(initialStoreType: widget.storeType)
            )).then((_) => _load()),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة'),
          ),
        ]),
      ),
      if (_categories.isNotEmpty)
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: widget.color,
          unselectedLabelColor: Colors.grey,
          indicatorColor: widget.color,
          tabs: [
            const Tab(text: 'الكل'),
            ..._categories.map((c) => Tab(text: c)),
          ],
        ),
      Expanded(
        child: _categories.isEmpty
            ? _buildList(_filtered(null))
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildList(_filtered(null)),
                  ..._categories.map((c) => _buildList(_filtered(c))),
                ],
              ),
      ),
    ]);
  }

  Widget _buildList(List<InstallmentProduct> items) {
    if (items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(_deptIcon(widget.storeType), size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('لا توجد منتجات بعد', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: widget.color, foregroundColor: Colors.white),
          onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => InstallmentProductsScreen(initialStoreType: widget.storeType)
          )).then((_) => _load()),
          icon: const Icon(Icons.add),
          label: const Text('إضافة منتج'),
        ),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final p = items[i];
        final imgPath = p.imagePaths.isNotEmpty ? p.imagePaths.first : p.imagePath;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: SizedBox(
              width: 52, height: 52,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imgPath != null && File(imgPath).existsSync()
                    ? Image.file(File(imgPath), fit: BoxFit.cover)
                    : Container(
                        color: widget.color.withValues(alpha: 0.1),
                        child: Icon(_deptIcon(widget.storeType), color: widget.color, size: 26)),
              ),
            ),
            title: Row(children: [
              Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              if (!p.isAvailable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('مخفي', style: TextStyle(fontSize: 10, color: Colors.red)),
                ),
            ]),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.category != null)
                Text(p.category!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Row(children: [
                if (p.showCashPrice)
                  Text('كاش: ${AppFormatters.formatCurrency(p.effectiveCashPrice)}',
                      style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                if (p.showCashPrice && p.showInstallmentPrice) const Text('  |  ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                if (p.showInstallmentPrice)
                  Text('تقسيط: ${AppFormatters.formatCurrency(p.effectiveInstallmentPrice)}',
                      style: TextStyle(fontSize: 11, color: widget.color, fontWeight: FontWeight.bold)),
              ]),
            ]),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: p))),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => InstallmentProductsScreen(initialStoreType: widget.storeType)));
                  _load();
                } else if (v == 'toggle') {
                  final updated = p.copyWith(isAvailable: !p.isAvailable);
                  await _dao.update(updated);
                  _load();
                } else if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('حذف المنتج'),
                      content: Text('هل تريد حذف "${p.name}"؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) { await _dao.delete(p.id!); _load(); }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('تعديل')])),
                PopupMenuItem(value: 'toggle', child: Row(children: [
                  Icon(p.isAvailable ? Icons.visibility_off : Icons.visibility, size: 18),
                  const SizedBox(width: 8),
                  Text(p.isAvailable ? 'إخفاء عن العملاء' : 'إظهار للعملاء'),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف', style: TextStyle(color: Colors.red)),
                ])),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManageCategoriesDialog() {
    final nameCtrl = TextEditingController();
    final st = widget.storeType;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final cats = List<String>.from(_categories);
          return AlertDialog(
            title: Row(children: [
              Icon(Icons.category, color: widget.color),
              const SizedBox(width: 8),
              const Text('إدارة الفئات'),
            ]),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(hintText: 'اسم الفئة الجديدة', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: widget.color, foregroundColor: Colors.white),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty || cats.contains(name)) return;
                      await Supabase.instance.client.from('item_groups').insert({
                        'name': name, 'store_type': st,
                        'created_at': DateTime.now().toIso8601String(),
                      });
                      nameCtrl.clear();
                      setS(() => cats.add(name));
                      _load();
                    },
                    child: const Text('إضافة'),
                  ),
                ]),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: cats.isEmpty
                      ? const Padding(padding: EdgeInsets.all(8), child: Text('لا توجد فئات بعد', style: TextStyle(color: Colors.grey)))
                      : ListView(
                          shrinkWrap: true,
                          children: cats.map((cat) => ListTile(
                            dense: true,
                            leading: Icon(Icons.label, color: widget.color, size: 18),
                            title: Text(cat),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                              onPressed: () async {
                                await Supabase.instance.client
                                    .from('item_groups')
                                    .delete()
                                    .eq('name', cat)
                                    .eq('store_type', st);
                                setS(() => cats.remove(cat));
                                _load();
                              },
                            ),
                          )).toList(),
                        ),
                ),
              ]),
            ),
            actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
          );
        },
      ),
    );
  }
}

// ─── Customers Tab ─────────────────────────────────────────────────────────────

class _CustomersTab extends StatefulWidget {
  final String storeType;
  final Color color;
  const _CustomersTab({required this.storeType, required this.color});
  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  final _dao = CustomerDao();
  List<Customer> _customers = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await Supabase.instance.client
        .from('customers')
        .select()
        .eq('store_type', widget.storeType)
        .eq('is_active', true)
        .order('name', ascending: true);
    if (mounted) {
      setState(() {
        _customers = List<Map<String, dynamic>>.from(rows).map(Customer.fromMap).toList();
        _loading = false;
      });
    }
  }

  List<Customer> get _filtered {
    if (_search.isEmpty) return _customers;
    return _customers.where((c) => c.name.contains(_search) || (c.phone?.contains(_search) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final deptName = _deptName(widget.storeType);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث عن عميل...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            onPressed: _showAddCustomerDialog,
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('إضافة'),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('لا يوجد عملاء لـ$deptName', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: widget.color, foregroundColor: Colors.white),
                      onPressed: _showAddCustomerDialog,
                      icon: const Icon(Icons.person_add),
                      label: const Text('إضافة عميل'),
                    ),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: widget.color.withValues(alpha: 0.12),
                            child: Icon(Icons.person, color: widget.color),
                          ),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (c.phone != null) Text('هاتف: ${c.phone}'),
                            if (c.loginCode != null)
                              Row(children: [
                                const Icon(Icons.vpn_key, size: 12, color: Colors.teal),
                                const SizedBox(width: 4),
                                Text('كود: ${c.loginCode}',
                                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
                              ]),
                          ]),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _showEditCustomerDialog(c);
                              if (v == 'deactivate') _deactivateCustomer(c);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('تعديل')])),
                              const PopupMenuItem(value: 'deactivate', child: Row(children: [Icon(Icons.person_off, size: 18, color: Colors.red), SizedBox(width: 8), Text('تعطيل', style: TextStyle(color: Colors.red))])),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }

  void _showAddCustomerDialog() {
    final deptName = _deptName(widget.storeType);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool saving = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            Icon(Icons.person_add, color: widget.color),
            const SizedBox(width: 8),
            Text('إضافة عميل $deptName'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العميل *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: widget.color, foregroundColor: Colors.white),
              onPressed: saving ? null : () async {
                if (nameCtrl.text.trim().isEmpty) return;
                setS(() => saving = true);
                try {
                  final code = AppFormatters.generateAccessCode();
                  final customer = Customer(
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    storeType: widget.storeType,
                    loginCode: code,
                    isApproved: true,
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  await _dao.insert(customer);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم إضافة العميل ✓ | كود: $code'), backgroundColor: Colors.green, duration: const Duration(seconds: 6)),
                    );
                  }
                } catch (e) {
                  setS(() => saving = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                }
              },
              child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCustomerDialog(Customer c) {
    final nameCtrl = TextEditingController(text: c.name);
    final phoneCtrl = TextEditingController(text: c.phone ?? '');
    final whatsappCtrl = TextEditingController(text: c.whatsapp ?? '');
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          bool saving = false;
          return AlertDialog(
            title: Row(children: [
              Icon(Icons.edit, color: widget.color),
              const SizedBox(width: 8),
              const Text('تعديل بيانات العميل'),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
              const SizedBox(height: 10),
              TextField(controller: whatsappCtrl, decoration: const InputDecoration(labelText: 'واتساب', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: widget.color, foregroundColor: Colors.white),
                onPressed: saving ? null : () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setS(() => saving = true);
                  try {
                    await Supabase.instance.client.from('customers').update({
                      'name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      'whatsapp': whatsappCtrl.text.trim().isEmpty ? null : whatsappCtrl.text.trim(),
                    }).eq('id', c.id!);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحديث ✓'), backgroundColor: Colors.green));
                  } catch (e) {
                    setS(() => saving = false);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                  }
                },
                child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deactivateCustomer(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعطيل العميل'),
        content: Text('هل تريد تعطيل حساب "${c.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تعطيل'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client.from('customers').update({'is_active': false}).eq('id', c.id!);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعطيل العميل'), backgroundColor: Colors.orange));
    }
  }
}

// ─── Installments Tab ──────────────────────────────────────────────────────────

class _InstallmentsTab extends StatefulWidget {
  final String storeType;
  final Color color;
  const _InstallmentsTab({required this.storeType, required this.color});
  @override
  State<_InstallmentsTab> createState() => _InstallmentsTabState();
}

class _InstallmentsTabState extends State<_InstallmentsTab> {
  List<Map<String, dynamic>> _installments = [];
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;
  String _filter = 'all'; // 'all' | 'active' | 'completed'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await Supabase.instance.client
        .from('installments')
        .select('*, customers(name, phone, store_type)')
        .order('created_at', ascending: false);

    final custRows = await Supabase.instance.client
        .from('customers')
        .select('id, name')
        .eq('store_type', widget.storeType)
        .eq('is_active', true)
        .order('name', ascending: true);

    final mapped = List<Map<String, dynamic>>.from(rows).where((r) {
      final c = r['customers'] as Map<String, dynamic>?;
      return c?['store_type'] == widget.storeType;
    }).map((r) {
      final m = Map<String, dynamic>.from(r);
      final c = m['customers'] as Map<String, dynamic>?;
      m['customer_name'] = c?['name'];
      m['customer_phone'] = c?['phone'];
      m.remove('customers');
      return m;
    }).toList();

    if (mounted) {
      setState(() {
        _installments = mapped;
        _customers = List<Map<String, dynamic>>.from(custRows);
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'active') return _installments.where((i) => (i['status'] as String? ?? 'active') == 'active').toList();
    if (_filter == 'completed') return _installments.where((i) => (i['status'] as String? ?? '') == 'completed').toList();
    return _installments;
  }

  @override
  Widget build(BuildContext context) {
    final deptName = _deptName(widget.storeType);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        // ── Filter chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(children: [
            _chip('الكل', 'all'),
            const SizedBox(width: 8),
            _chip('نشط', 'active'),
            const SizedBox(width: 8),
            _chip('مكتمل', 'completed'),
            const Spacer(),
            Text('${_filtered.length} قسط', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 8),
        // ── List ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.payment, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('لا توجد أقساط لـ$deptName', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: widget.color, foregroundColor: Colors.white),
                        onPressed: _showAddInstallmentDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة قسط'),
                      ),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildCard(_filtered[i]),
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        onPressed: _showAddInstallmentDialog,
        icon: const Icon(Icons.add),
        label: const Text('قسط جديد'),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? widget.color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? widget.color : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : Colors.grey.shade700,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        )),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> inst) {
    final status = inst['status'] as String? ?? 'active';
    final isCompleted = status == 'completed';
    final total = (inst['total_price'] as num? ?? 0).toDouble();
    final remaining = (inst['remaining_amount'] as num? ?? 0).toDouble();
    final monthly = (inst['monthly_amount'] as num? ?? 0).toDouble();
    final months = inst['num_installments'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isCompleted ? Colors.green.withValues(alpha: 0.15) : widget.color.withValues(alpha: 0.12),
              child: Icon(isCompleted ? Icons.check_circle : Icons.payment,
                  size: 18, color: isCompleted ? Colors.green : widget.color),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inst['item_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('العميل: ${inst['customer_name'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(isCompleted ? 'مكتمل' : 'نشط',
                  style: TextStyle(color: isCompleted ? Colors.green : Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const Divider(height: 16),
          Row(children: [
            Expanded(child: _infoItem('الإجمالي', AppFormatters.formatCurrency(total))),
            Expanded(child: _infoItem('المتبقي', AppFormatters.formatCurrency(remaining),
                color: remaining > 0 ? Colors.red : Colors.green)),
            Expanded(child: _infoItem('القسط الشهري', AppFormatters.formatCurrency(monthly))),
            Expanded(child: _infoItem('الأشهر', '$months شهر')),
          ]),
          if (!isCompleted) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.color,
                    side: BorderSide(color: widget.color),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  onPressed: () => _showRecordPaymentDialog(inst),
                  icon: const Icon(Icons.payments, size: 16),
                  label: const Text('تسجيل دفعة', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  onPressed: () => _markCompleted(inst),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('إتمام', style: TextStyle(fontSize: 12)),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _infoItem(String label, String value, {Color? color}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  void _showRecordPaymentDialog(Map<String, dynamic> inst) {
    final amountCtrl = TextEditingController();
    final remaining = (inst['remaining_amount'] as num? ?? 0).toDouble();
    bool saving = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            Icon(Icons.payments, color: widget.color),
            const SizedBox(width: 8),
            const Text('تسجيل دفعة'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('المتبقي: ${AppFormatters.formatCurrency(remaining)}',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'مبلغ الدفعة *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => amountCtrl.text = remaining.toStringAsFixed(0),
              child: const Text('تسديد كامل المتبقي'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: widget.color, foregroundColor: Colors.white),
              onPressed: saving ? null : () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                setS(() => saving = true);
                try {
                  final instId = inst['id'] as int;
                  final newRemaining = (remaining - amount).clamp(0.0, remaining);
                  final newStatus = newRemaining <= 0 ? 'completed' : 'active';
                  await Supabase.instance.client
                      .from('installments')
                      .update({'remaining_amount': newRemaining, 'status': newStatus})
                      .eq('id', instId);
                  await Supabase.instance.client.from('installment_payments').insert({
                    'installment_id': instId,
                    'due_date': DateTime.now().toIso8601String().substring(0, 10),
                    'amount': amount,
                    'paid_date': DateTime.now().toIso8601String().substring(0, 10),
                    'status': 'paid',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(newStatus == 'completed'
                          ? 'تم تسجيل الدفعة وإتمام القسط ✓'
                          : 'تم تسجيل الدفعة ✓ | المتبقي: ${AppFormatters.formatCurrency(newRemaining)}'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ));
                  }
                } catch (e) {
                  setS(() => saving = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                }
              },
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تسجيل'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markCompleted(Map<String, dynamic> inst) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إتمام القسط'),
        content: Text('هل تريد تسجيل قسط "${inst['item_name']}" كمكتمل؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إتمام'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client
          .from('installments')
          .update({'status': 'completed', 'remaining_amount': 0})
          .eq('id', inst['id'] as int);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إتمام القسط ✓'), backgroundColor: Colors.green));
    }
  }

  void _showAddInstallmentDialog() {
    if (_customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف عملاء أولاً من تبويب العملاء'), backgroundColor: Colors.orange));
      return;
    }
    int? selectedCustomerId;
    final itemCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final downCtrl = TextEditingController();
    final monthsCtrl = TextEditingController(text: '12');
    bool saving = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final total = double.tryParse(totalCtrl.text) ?? 0;
          final down = double.tryParse(downCtrl.text) ?? 0;
          final months = int.tryParse(monthsCtrl.text) ?? 1;
          final monthly = months > 0 ? ((total - down) / months) : 0.0;

          return AlertDialog(
            title: Row(children: [
              Icon(Icons.add_card, color: widget.color),
              const SizedBox(width: 8),
              const Text('إضافة قسط جديد'),
            ]),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<int>(
                  value: selectedCustomerId,
                  decoration: const InputDecoration(labelText: 'العميل *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                  items: _customers.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['name'] as String))).toList(),
                  onChanged: (v) => setS(() => selectedCustomerId = v),
                ),
                const SizedBox(height: 10),
                TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.inventory_2))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(
                    controller: totalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'السعر الكلي *', border: OutlineInputBorder()),
                    onChanged: (_) => setS(() {}),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: downCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'المقدم', border: OutlineInputBorder()),
                    onChanged: (_) => setS(() {}),
                  )),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(
                    controller: monthsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عدد الأشهر', border: OutlineInputBorder()),
                    onChanged: (_) => setS(() {}),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: Column(children: [
                      const Text('القسط الشهري', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(AppFormatters.formatCurrency(monthly), style: TextStyle(fontWeight: FontWeight.bold, color: widget.color)),
                    ]),
                  )),
                ]),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: widget.color, foregroundColor: Colors.white),
                onPressed: saving ? null : () async {
                  if (selectedCustomerId == null || itemCtrl.text.trim().isEmpty || total <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تعبئة الحقول المطلوبة *'), backgroundColor: Colors.red));
                    return;
                  }
                  setS(() => saving = true);
                  try {
                    final now = DateTime.now();
                    await Supabase.instance.client.from('installments').insert({
                      'customer_id': selectedCustomerId,
                      'item_name': itemCtrl.text.trim(),
                      'total_price': total,
                      'down_payment': down,
                      'remaining_amount': total - down,
                      'num_installments': months,
                      'monthly_amount': monthly,
                      'start_date': now.toIso8601String().substring(0, 10),
                      'status': 'active',
                      'created_at': now.toIso8601String(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة القسط ✓'), backgroundColor: Colors.green));
                  } catch (e) {
                    setS(() => saving = false);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                  }
                },
                child: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );
  }
}
