import 'dart:io';
import '../../utils/image_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/installment_provider.dart';
import '../../database/daos/installment_product_dao.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_settings.dart';
import '../../models/customer.dart';
import '../../models/installment_product.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../customer/customer_profile_screen.dart';
import '../customer/product_request_screen.dart';
import '../shared/notification_history_screen.dart';
import '../../providers/notification_provider.dart';

class InstallmentCustomerHome extends StatefulWidget {
  const InstallmentCustomerHome({super.key});
  @override
  State<InstallmentCustomerHome> createState() => _InstallmentCustomerHomeState();
}

class _InstallmentCustomerHomeState extends State<InstallmentCustomerHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentCustomer?.id != null) {
        context.read<InstallmentProvider>().loadByCustomer(
              auth.currentCustomer!.id!,
              storeType: AppConstants.storeInstallment,
            );
        context.read<NotificationProvider>().init(
              auth.currentCustomer!.id!,
              AppConstants.roleCustomer,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final customer = auth.currentCustomer;

    final pages = [
      _InstallmentHomeTab(customer: customer, onBrowseProducts: () => setState(() => _tab = 1)),
      _InstallmentProductsTab(customer: customer),
      _MyInstallmentsTab(customer: customer),
      CustomerProfileScreen(customer: customer),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.payments, size: 20),
          const SizedBox(width: 8),
          Text(customer?.name ?? 'فرصتك للتقسيط'),
        ]),
        backgroundColor: const Color(AppColors.accentInt),
        foregroundColor: Colors.white,
        actions: [
          Consumer<NotificationProvider>(
            builder: (_, np, __) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'الإشعارات',
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NotificationHistoryScreen())),
                ),
                if (np.unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${np.unreadCount > 99 ? '99+' : np.unreadCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل تريد تسجيل الخروج؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('خروج'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                }
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
        selectedItemColor: const Color(AppColors.accentInt),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'المنتجات'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'أقساطي'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────

class _InstallmentHomeTab extends StatelessWidget {
  final Customer? customer;
  final VoidCallback onBrowseProducts;
  const _InstallmentHomeTab({this.customer, required this.onBrowseProducts});

  @override
  Widget build(BuildContext context) {
    final installments = context.watch<InstallmentProvider>().installments;
    final active = installments.where((i) => (i['status'] as String?) == 'active').toList();
    final overdue = installments.where((i) {
      final total = (i['total_installment_price'] as num? ?? 0).toDouble();
      final down = (i['down_payment'] as num? ?? 0).toDouble();
      return (total - down) > 0 && (i['status'] as String?) == 'active';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Welcome
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(AppColors.accentInt), const Color(AppColors.accentInt).withValues(alpha: 0.7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أهلاً، ${customer?.name ?? ''}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('فرصتك للتقسيط', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),

        // Stats
        Row(children: [
          Expanded(
            child: _StatBox(
              title: 'أقساط نشطة', value: '${active.length}',
              icon: Icons.payment, color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatBox(
              title: 'مستحق السداد',
              value: AppFormatters.formatCurrency(overdue.fold(0.0, (s, i) {
                final total = (i['total_installment_price'] as num? ?? 0).toDouble();
                final down = (i['down_payment'] as num? ?? 0).toDouble();
                return s + (total - down);
              })),
              icon: Icons.account_balance_wallet, color: Colors.orange,
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Quick Actions
        const Text('الخدمات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: _QuickAction('تصفح المنتجات', Icons.shopping_bag, const Color(AppColors.accentInt), onBrowseProducts),
        ),
      ]),
    );
  }
}

// ─── Products Tab with Category Tabs ─────────────────────────────────────────

class _InstallmentProductsTab extends StatefulWidget {
  final Customer? customer;
  const _InstallmentProductsTab({this.customer});
  @override
  State<_InstallmentProductsTab> createState() => _InstallmentProductsTabState();
}

class _InstallmentProductsTabState extends State<_InstallmentProductsTab> with SingleTickerProviderStateMixin {
  final _dao = InstallmentProductDao();
  List<InstallmentProduct> _products = [];
  List<String> _categories = [];
  bool _loading = true;
  TabController? _tabCtrl;
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
    // Point 10: filter products by storeType='installment' only
    final products = await _dao.getAll(
        availableOnly: true, storeType: AppConstants.storeInstallment);
    final groupRows = await Supabase.instance.client
        .from('item_groups')
        .select()
        .eq('store_type', AppConstants.storeInstallment)
        .order('name', ascending: true);
    final cats = List<Map<String, dynamic>>.from(groupRows).map((r) => r['name'] as String).toList();
    _tabCtrl?.dispose();
    _tabCtrl = TabController(length: cats.length + 1, vsync: this);
    if (mounted) setState(() { _products = products; _categories = cats; _loading = false; });
  }

  List<InstallmentProduct> _filtered(String? category) {
    var list = category == null ? _products : _products.where((p) => p.category == category).toList();
    if (_search.isNotEmpty) {
      list = list.where((p) => p.name.contains(_search)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'بحث عن منتج...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
      ),
      if (_categories.isNotEmpty)
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: const Color(AppColors.accentInt),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(AppColors.accentInt),
          tabs: [
            const Tab(text: 'الكل'),
            ..._categories.map((c) => Tab(text: c)),
          ],
        ),
      Expanded(
        child: _categories.isEmpty
            ? _buildGrid(_filtered(null))
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildGrid(_filtered(null)),
                  ..._categories.map((c) => _buildGrid(_filtered(c))),
                ],
              ),
      ),
    ]);
  }

  Widget _buildGrid(List<InstallmentProduct> items) {
    if (items.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Text('لا توجد منتجات في هذه الفئة', style: TextStyle(color: Colors.grey)),
      ]));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
      itemCount: items.length,
      itemBuilder: (_, i) => _ProductCard(product: items[i]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final InstallmentProduct product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final imgPath = product.imagePaths.isNotEmpty ? product.imagePaths.first : product.imagePath;
    final hasImage = imgPath != null && (imgPath.startsWith('http') || File(imgPath).existsSync());

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 5,
            child: hasImage && imgPath != null
                ? buildProductImage(imgPath, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                : Container(
                    color: Colors.teal.withValues(alpha: 0.1),
                    child: const Icon(Icons.inventory_2, size: 48, color: Colors.teal)),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (product.category != null)
                  Text(product.category!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (product.showCashPrice)
                    Text('كاش: ${AppFormatters.formatCurrency(product.effectiveCashPrice)}',
                        style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                  if (product.showInstallmentPrice)
                    Text('تقسيط: ${AppFormatters.formatCurrency(product.effectiveInstallmentPrice)}',
                        style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                  if (!product.showCashPrice && !product.showInstallmentPrice)
                    const Text('اتصل للسعر', style: TextStyle(fontSize: 11, color: Colors.orange)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductDetailSheet(product: product),
    );
  }
}

// ─── Full-Screen Image Viewer ──────────────────────────────────────────────

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullScreenImageViewer({required this.images, required this.initialIndex});
  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late int _current;
  late PageController _ctrl;
  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: _current);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.5, maxScale: 4.0,
          child: Center(
            child: (widget.images[i].startsWith('http') || File(widget.images[i]).existsSync())
                ? buildProductImage(widget.images[i], fit: BoxFit.contain)
                : const Icon(Icons.image, size: 80, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class _ProductDetailSheet extends StatefulWidget {
  final InstallmentProduct product;
  const _ProductDetailSheet({required this.product});
  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  int _imgIndex = 0;
  int _selectedMonths = 1;
  AppSettings _settings = const AppSettings();

  List<String> get _allImages {
    final imgs = List<String>.from(widget.product.imagePaths);
    if (imgs.isEmpty && widget.product.imagePath != null) imgs.add(widget.product.imagePath!);
    return imgs;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadInstallmentSettings();
  }

  Future<void> _loadInstallmentSettings() async {
    try {
      final provider = context.read<InstallmentProvider>();
      if (provider.settings.monthlyInstallmentRate == 0) {
        await provider.loadSettings();
      }
      if (mounted) {
        setState(() => _settings = provider.settings);
      }
    } catch (_) {}
  }

  double get _detailRate {
    if (widget.product.profitRate > 0) {
      return widget.product.profitRate * 100 * _selectedMonths;
    }
    return _settings.rateForMonths(_selectedMonths);
  }

  double get _detailTotalPrice {
    if (widget.product.installmentPrice > 0) {
      return widget.product.installmentPrice;
    }
    return widget.product.salePrice * (1.0 + (_detailRate / 100.0));
  }

  double get _detailMonthlyPayment {
    return _selectedMonths > 0 ? _detailTotalPrice / _selectedMonths : 0;
  }

  @override
  Widget build(BuildContext context) {
    final imgs = _allImages;
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image Gallery
          if (imgs.isNotEmpty) ...[
            SizedBox(
              height: 240,
              child: Stack(children: [
                PageView.builder(
                  itemCount: imgs.length,
                  onPageChanged: (i) => setState(() => _imgIndex = i),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _FullScreenImageViewer(images: imgs, initialIndex: _imgIndex),
                    )),
                    child: (imgs[i].startsWith('http') || File(imgs[i]).existsSync())
                        ? buildProductImage(imgs[i], width: double.infinity, height: 240, fit: BoxFit.cover)
                        : Container(color: Colors.grey.shade200, child: const Icon(Icons.image, size: 64, color: Colors.grey)),
                  ),
                ),
                if (imgs.length > 1)
                  Positioned(
                    bottom: 8, left: 0, right: 0,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(
                      imgs.length, (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _imgIndex ? 12 : 8, height: 8,
                        decoration: BoxDecoration(
                          color: i == _imgIndex ? const Color(AppColors.accentInt) : Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )),
                  ),
              ]),
            ),
          ] else
            Container(
              height: 180, color: Colors.teal.withValues(alpha: 0.1),
              child: const Center(child: Icon(Icons.inventory_2, size: 80, color: Colors.teal))),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (widget.product.category != null)
                Chip(label: Text(widget.product.category!), backgroundColor: Colors.teal.withValues(alpha: 0.1)),
              if (widget.product.description != null && widget.product.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(widget.product.description!, style: const TextStyle(color: Colors.grey)),
              ],
              const Divider(height: 24),
              const Text('الأسعار', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (widget.product.showCashPrice)
                _PriceRow('سعر الكاش', AppFormatters.formatCurrency(widget.product.effectiveCashPrice), Colors.green, Icons.payments),
              if (widget.product.showInstallmentPrice)
                _PriceRow('سعر التقسيط الإجمالي', AppFormatters.formatCurrency(widget.product.effectiveInstallmentPrice), Colors.blue, Icons.payment),
              if (widget.product.showInstallmentPrice && widget.product.maxInstallmentMonths > 1) ...[
                const SizedBox(height: 8),
                Text('حد أقصى عدد أشهر التقسيط: ${widget.product.maxInstallmentMonths} شهر',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                Text('اختر عدد الأشهر', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(AppColors.installmentInt),
                    thumbColor: const Color(AppColors.installmentInt),
                    inactiveTrackColor: const Color(AppColors.installmentInt).withValues(alpha: 0.3),
                  ),
                  child: Slider(
                    value: _selectedMonths.toDouble(),
                    min: 1,
                    max: widget.product.maxInstallmentMonths.toDouble(),
                    divisions: widget.product.maxInstallmentMonths > 1
                        ? widget.product.maxInstallmentMonths - 1
                        : 1,
                    label: '$_selectedMonths',
                    onChanged: (value) {
                      setState(() => _selectedMonths = value.round().clamp(1, widget.product.maxInstallmentMonths));
                    },
                  ),
                ),
                _PriceRow('القسط الشهري',
                    AppFormatters.formatCurrency(_detailMonthlyPayment),
                    Colors.blue,
                    Icons.schedule),
              ],
              if (!widget.product.showCashPrice && !widget.product.showInstallmentPrice)
                const Text('السعر بالتواصل مع الإدارة', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              if (widget.product.companyPercentage > 0) ...[
                const SizedBox(height: 4),
                _PriceRow(
                  'نسبة الشركة من كل بيع/قسط',
                  '${widget.product.companyPercentage.toStringAsFixed(1)}%',
                  Colors.orange,
                  Icons.business_center,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppColors.accentInt), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProductRequestScreen(
                        installmentProduct: widget.product,
                        storeType: AppConstants.storeInstallment,
                        // Pass the customer-selected months from the detail sheet.
                        initialInstallmentMonths: _selectedMonths,
                      ),
                    ));
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('إنشاء طلب'),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _PriceRow(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }
}

// ─── My Installments Tab ──────────────────────────────────────────────────────

class _MyInstallmentsTab extends StatefulWidget {
  final Customer? customer;
  const _MyInstallmentsTab({this.customer});
  @override
  State<_MyInstallmentsTab> createState() => _MyInstallmentsTabState();
}

class _MyInstallmentsTabState extends State<_MyInstallmentsTab> {
  // installmentId -> {paidMonths, remainingMonths, paidAmount, remainingAmount}
  final Map<int, Map<String, dynamic>> _paymentSummaries = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPaymentSummaries();
  }

  Future<void> _loadPaymentSummaries() async {
    final installments = context.read<InstallmentProvider>().installments;
    final client = Supabase.instance.client;
    for (final inst in installments) {
      final id = inst['id'] as int? ?? 0;
      final numMonths = inst['num_installments'] as int? ?? 0;
      final downPayment = (inst['down_payment'] as num? ?? 0).toDouble();
      final totalPrice = (inst['total_price'] as num? ?? inst['total_installment_price'] as num? ?? 0).toDouble();
      final rows = await client
          .from('installment_payments')
          .select('amount')
          .eq('installment_id', id)
          .eq('status', 'paid');
      final paidList = List<Map<String, dynamic>>.from(rows);
      final paidCount = paidList.length;
      final paidSum = paidList.fold<double>(0.0, (s, r) => s + (r['amount'] as num? ?? 0).toDouble());
      final remainingMonths = numMonths - paidCount;
      final remainingAmount = totalPrice - downPayment - paidSum;
      if (mounted) setState(() {
        _paymentSummaries[id] = {
          'paidMonths': paidCount,
          'remainingMonths': remainingMonths,
          'paidAmount': paidSum,
          'remainingAmount': remainingAmount < 0 ? 0.0 : remainingAmount,
        };
      });
    }
  }

  Future<void> _showPaymentDialog(BuildContext ctx) async {
    final installments = context.read<InstallmentProvider>().installments
        .where((i) => (i['status'] as String?) == 'active').toList();
    if (installments.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('لا توجد أقساط نشطة للدفع')));
      return;
    }

    Map<String, dynamic>? selectedInst = installments.length == 1 ? installments.first : null;
    String? receiptPath;
    final notesCtrl = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (dlgCtx, setS) => AlertDialog(
        title: const Row(children: [Icon(Icons.payment, color: Colors.teal), SizedBox(width: 8), Text('رفع دفعة للموافقة')]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (installments.length > 1) ...[
            const Text('اختر القسط:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: selectedInst,
              decoration: const InputDecoration(labelText: 'القسط', border: OutlineInputBorder(), isDense: true),
              items: installments.map((i) => DropdownMenuItem(
                value: i,
                child: Text(i['product_name'] as String? ?? ''),
              )).toList(),
              onChanged: (v) => setS(() => selectedInst = v),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              final picker = ImagePicker();
              final xfile = await picker.pickImage(source: ImageSource.gallery);
              if (xfile != null) setS(() => receiptPath = xfile.path);
            },
            icon: const Icon(Icons.upload_file),
            label: Text(receiptPath != null ? 'تم رفع الإيصال ✓' : 'رفع صورة الإيصال'),
          ),
          if (receiptPath != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(receiptPath!), height: 100, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder(), isDense: true),
            maxLines: 2,
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: submitting ? null : () async {
              if (selectedInst == null) {
                ScaffoldMessenger.of(dlgCtx).showSnackBar(const SnackBar(content: Text('اختر القسط أولاً')));
                return;
              }
              setS(() => submitting = true);
              try {
                final now = DateTime.now();
                final monthlyAmount = (selectedInst!['monthly_amount'] as num? ?? 0).toDouble();
                await Supabase.instance.client.from('customer_payments').insert({
                  'customer_id': widget.customer?.id,
                  'installment_id': selectedInst!['id'],
                  'amount': monthlyAmount,
                  'payment_method': 'receipt',
                  'receipt_path': receiptPath,
                  'status': 'pending',
                  'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  'date': now.toIso8601String().substring(0, 10),
                  'created_at': now.toIso8601String(),
                });
                if (dlgCtx.mounted) {
                  Navigator.pop(dlgCtx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('تم إرسال الدفعة بنجاح، في انتظار موافقة الإدارة'), backgroundColor: Colors.green));
                }
              } catch (e) {
                setS(() => submitting = false);
                ScaffoldMessenger.of(dlgCtx).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
              }
            },
            child: submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('إرسال'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final installments = context.watch<InstallmentProvider>().installments;
    if (installments.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.payment, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Text('لا توجد أقساط بعد', style: TextStyle(color: Colors.grey)),
      ]));
    }
    return Stack(children: [
      ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: installments.length,
        itemBuilder: (_, i) {
          final inst = installments[i];
          final instId = inst['id'] as int? ?? 0;
          final instStatus = inst['status'] as String? ?? 'active';
          final instProductName = inst['item_name'] as String? ?? inst['product_name'] as String? ?? '';
          final instTotal = (inst['total_price'] as num? ?? inst['total_installment_price'] as num? ?? 0).toDouble();
          final numMonths = inst['num_installments'] as int? ?? 0;
          final summary = _paymentSummaries[instId];
          final paidMonths = summary?['paidMonths'] as int? ?? 0;
          final remainingMonths = summary?['remainingMonths'] as int? ?? numMonths;
          final remainingAmount = summary?['remainingAmount'] as double? ?? instTotal;
          final isCompleted = instStatus == 'completed';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                child: Icon(isCompleted ? Icons.check_circle : Icons.payment,
                    color: isCompleted ? Colors.green : Colors.orange),
              ),
              title: Text(instProductName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                isCompleted ? 'مكتمل ✓' : 'دفعت $paidMonths شهر • فضل $remainingMonths شهر',
                style: TextStyle(color: isCompleted ? Colors.green : Colors.orange, fontSize: 12),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCompleted ? 'مكتمل' : AppFormatters.formatCurrency(remainingAmount),
                  style: TextStyle(color: isCompleted ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _InfoRow('إجمالي القسط', AppFormatters.formatCurrency(instTotal)),
                    _InfoRow('الأشهر المدفوعة', '$paidMonths شهر'),
                    _InfoRow('الأشهر المتبقية', '$remainingMonths شهر'),
                    _InfoRow('المبلغ المتبقي', AppFormatters.formatCurrency(remainingAmount),
                        valueColor: remainingAmount > 0 ? Colors.red : Colors.green),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
      Positioned(
        bottom: 16, left: 16, right: 16,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _showPaymentDialog(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('ادفع دفعة — رفع إيصال', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(this.label, this.value, {this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valueColor)),
    ]),
  );
}

// ─── My Payments Tab ──────────────────────────────────────────────────────────

class _MyPaymentsTab extends StatefulWidget {
  final Customer? customer;
  const _MyPaymentsTab({this.customer});
  @override
  State<_MyPaymentsTab> createState() => _MyPaymentsTabState();
}

class _MyPaymentsTabState extends State<_MyPaymentsTab> {
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.customer?.id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('customer_payments')
          .select('*, installments(item_name)')
          .eq('customer_id', widget.customer!.id!)
          .order('created_at', ascending: false)
          .limit(50);
      final mapped = List<Map<String, dynamic>>.from(rows).map((r) {
        final m = Map<String, dynamic>.from(r);
        final inst = m['installments'] as Map<String, dynamic>?;
        m['product_name'] = inst?['item_name'];
        m.remove('installments');
        return m;
      }).toList();
      if (mounted) setState(() { _payments = mapped; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPaymentDialog(BuildContext ctx) async {
    final installments = context.read<InstallmentProvider>().installments
        .where((i) => (i['status'] as String?) == 'active').toList();
    if (installments.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('لا توجد أقساط نشطة للدفع')));
      return;
    }

    Map<String, dynamic>? selectedInst =
        installments.length == 1 ? installments.first : null;
    String? receiptPath;
    final notesCtrl = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (dlgCtx, setS) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.payment, color: Colors.teal),
            SizedBox(width: 8),
            Text('رفع دفعة للموافقة'),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (installments.length > 1) ...[
                const Text('اختر القسط:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: selectedInst,
                  decoration: const InputDecoration(
                      labelText: 'القسط', border: OutlineInputBorder(), isDense: true),
                  items: installments.map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(i['product_name'] as String? ?? ''),
                  )).toList(),
                  onChanged: (v) => setS(() => selectedInst = v),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () async {
                  final picker = ImagePicker();
                  final xfile = await picker.pickImage(source: ImageSource.gallery);
                  if (xfile != null) setS(() => receiptPath = xfile.path);
                },
                icon: const Icon(Icons.upload_file),
                label: Text(receiptPath != null ? 'تم رفع الإيصال ✓' : 'رفع صورة الإيصال'),
              ),
              if (receiptPath != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(receiptPath!),
                      height: 100, width: double.infinity, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                    isDense: true),
                maxLines: 2,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: submitting
                  ? null
                  : () async {
                      if (selectedInst == null) {
                        ScaffoldMessenger.of(dlgCtx).showSnackBar(
                            const SnackBar(content: Text('اختر القسط أولاً')));
                        return;
                      }
                      setS(() => submitting = true);
                      try {
                        final now = DateTime.now();
                        final monthlyAmount =
                            (selectedInst!['monthly_amount'] as num? ?? 0).toDouble();
                        await Supabase.instance.client.from('customer_payments').insert({
                          'customer_id': widget.customer?.id,
                          'installment_id': selectedInst!['id'],
                          'amount': monthlyAmount,
                          'payment_method': 'receipt',
                          'receipt_path': receiptPath,
                          'status': 'pending',
                          'notes': notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                          'date': now.toIso8601String().substring(0, 10),
                          'created_at': now.toIso8601String(),
                        });
                        if (dlgCtx.mounted) {
                          Navigator.pop(dlgCtx);
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text(
                                  'تم إرسال الدفعة بنجاح، في انتظار موافقة الإدارة'),
                              backgroundColor: Colors.green));
                          _load();
                        }
                      } catch (e) {
                        setS(() => submitting = false);
                        ScaffoldMessenger.of(dlgCtx).showSnackBar(
                            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: _payments.isEmpty
            ? ListView(children: const [
                SizedBox(height: 120),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('لا توجد دفعات بعد', style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 6),
                    Text('اضغط الزر أدناه لإرسال دفعة',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                ),
              ])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                itemCount: _payments.length,
                itemBuilder: (_, i) {
                  final p = _payments[i];
                  final status = p['status'] as String? ?? 'pending';
                  final Color statusColor;
                  final String statusLabel;
                  final IconData statusIcon;
                  switch (status) {
                    case 'approved':
                      statusColor = Colors.green;
                      statusLabel = 'تم القبول ✓';
                      statusIcon = Icons.check_circle;
                      break;
                    case 'rejected':
                      statusColor = Colors.red;
                      statusLabel = 'مرفوضة ✗';
                      statusIcon = Icons.cancel;
                      break;
                    default:
                      statusColor = Colors.orange;
                      statusLabel = 'قيد المراجعة';
                      statusIcon = Icons.hourglass_empty;
                  }
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        child: Icon(statusIcon, color: statusColor, size: 20),
                      ),
                      title: Text(
                        p['product_name']?.toString() ?? 'قسط',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['date']?.toString() ?? '',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(statusLabel,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      trailing: Text(
                        AppFormatters.formatCurrency(
                            (p['amount'] as num?)?.toDouble() ?? 0),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
      ),
      Positioned(
        bottom: 16, left: 16, right: 16,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _showPaymentDialog(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('ادفع دفعة — رفع إيصال',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatBox({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        ])),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.title, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
