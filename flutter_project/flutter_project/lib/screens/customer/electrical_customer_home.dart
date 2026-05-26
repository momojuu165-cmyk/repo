import 'dart:io';
import '../../utils/image_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/installment_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/customer.dart';
import '../../models/installment_product.dart';
import '../../database/daos/installment_product_dao.dart';
import '../../database/daos/customer_invoice_dao.dart';
import '../../models/customer_invoice.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../customer/product_request_screen.dart';
import '../customer/customer_installments_screen.dart';
import '../customer/customer_profile_screen.dart';
import '../customer/customer_invoices_list_screen.dart';
import '../shared/notification_history_screen.dart';
import '../../database/daos/electrical_bundle_dao.dart';
import '../../models/electrical_bundle.dart';
import '../../database/daos/request_dao.dart';
import '../../models/product_request.dart';
import '../../services/push_notification_service.dart';
import '../../utils/notification_messages.dart';
import '../../providers/notification_provider.dart';

class ElectricalCustomerHome extends StatefulWidget {
  const ElectricalCustomerHome({super.key});
  @override
  State<ElectricalCustomerHome> createState() => _ElectricalCustomerHomeState();
}

class _ElectricalCustomerHomeState extends State<ElectricalCustomerHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentCustomer?.id != null) {
        context.read<InstallmentProvider>().loadByCustomer(
              auth.currentCustomer!.id!,
              storeType: AppConstants.storeElectrical,
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
      _ElectricalHomeTab(
          customer: customer, onBrowseProducts: () => setState(() => _tab = 1)),
      _ElectricalProductsTab(customer: customer),
      _ElectricalBundlesTab(customer: customer),
      _CustomerInvoicesTab(customer: customer),
      CustomerInstallmentsScreen(customer: customer),
      CustomerProfileScreen(customer: customer),
    ];

    final currentIndex = _tab.clamp(0, pages.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.electrical_services, size: 20),
          const SizedBox(width: 8),
          Text(customer?.name ?? 'الأدوات الكهربائية'),
          if (customer?.customerType == 'technician') ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('فني',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ] else if (customer?.customerType == 'engineer') ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('مهندس',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          Consumer<NotificationProvider>(
            builder: (_, np, __) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'الإشعارات',
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationHistoryScreen())),
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
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
          ),
        ],
      ),
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(AppColors.primaryInt),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(
              icon: Icon(Icons.electrical_services), label: 'المنتجات'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_offer), label: 'الليستات'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'فواتيري'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'أقساطي'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────

class _ElectricalHomeTab extends StatelessWidget {
  final Customer? customer;
  final VoidCallback onBrowseProducts;
  const _ElectricalHomeTab({this.customer, required this.onBrowseProducts});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(AppColors.primaryInt),
                const Color(AppColors.primaryInt).withValues(alpha: 0.75)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أهلاً، ${customer?.name ?? ''}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('الأدوات الكهربائية',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              // Feature 13: customer type badge
              if (customer?.customerType == 'technician')
                _InfoBadge('فني', Colors.amber.shade700)
              else if (customer?.customerType == 'engineer')
                _InfoBadge('مهندس', Colors.blue.shade600),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('الخدمات السريعة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _QuickAction('تصفح المنتجات', Icons.shopping_bag,
                const Color(AppColors.primaryInt), onBrowseProducts),
            _QuickAction(
                'طلب منتج',
                Icons.add_shopping_cart,
                Colors.orange,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProductRequestScreen(
                            storeType: AppConstants.storeElectrical)))),
            _QuickAction(
                'تسعير كشف',
                Icons.price_check,
                Colors.teal,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            _PricingSheetScreen(customer: customer)))),
          ],
        ),
      ]),
    );
  }
}

// ─── Products Tab with Category Tabs ─────────────────────────────────────────

// ─── Point 10: Electrical Products Tab (uses InstallmentProductDao, storeType=electrical) ─────
class _ElectricalProductsTab extends StatefulWidget {
  final Customer? customer;
  const _ElectricalProductsTab({this.customer});
  @override
  State<_ElectricalProductsTab> createState() => _ElectricalProductsTabState();
}

class _ElectricalProductsTabState extends State<_ElectricalProductsTab>
    with SingleTickerProviderStateMixin {
  final _dao = InstallmentProductDao();
  List<InstallmentProduct> _products = [];
  List<String> _categories = [];
  bool _loading = true;
  String _search = '';
  TabController? _tabCtrl;

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
    final products = await _dao.getAll(
        availableOnly: true, storeType: AppConstants.storeElectrical);
    final groupRows = await Supabase.instance.client
        .from('item_groups')
        .select()
        .eq('store_type', AppConstants.storeElectrical)
        .order('name', ascending: true);
    final cats = List<Map<String, dynamic>>.from(groupRows)
        .map((r) => r['name'] as String)
        .toList();
    _tabCtrl?.dispose();
    _tabCtrl = TabController(length: cats.length + 1, vsync: this);
    if (mounted) {
      setState(() {
        _products = products;
        _categories = cats;
        _loading = false;
      });
    }
  }

  List<InstallmentProduct> _filtered(String? category) {
    // Filter by customer's assigned price tier
    final customerTier = widget.customer?.priceType;
    var list = _products.where((p) => p.isAvailable).toList();
    if (customerTier != null &&
        customerTier.isNotEmpty &&
        customerTier != 'retail') {
      // Customer only sees products with no tier set OR products matching their tier
      list = list
          .where((p) => p.priceTier == null || p.priceTier == customerTier)
          .toList();
    } else {
      // retail customers only see retail (null or retail) products
      list = list
          .where((p) => p.priceTier == null || p.priceTier == 'retail')
          .toList();
    }
    if (category != null) {
      list = list.where((p) => p.category == category).toList();
    }
    if (_search.isNotEmpty) {
      list = list.where((p) => p.name.contains(_search)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_products.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.electrical_services,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('لا توجد منتجات كهربائية متاحة حالياً',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('سيتم إضافة المنتجات قريباً',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      );
    }
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
          labelColor: const Color(AppColors.primaryInt),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(AppColors.primaryInt),
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
      return const Center(
          child: Text('لا توجد منتجات في هذه الفئة',
              style: TextStyle(color: Colors.grey)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72),
      itemCount: items.length,
      itemBuilder: (_, i) => _ElectricalProductCard(product: items[i]),
    );
  }
}

class _ElectricalProductCard extends StatefulWidget {
  final InstallmentProduct product;
  const _ElectricalProductCard({required this.product});
  @override
  State<_ElectricalProductCard> createState() => _ElectricalProductCardState();
}

class _ElectricalProductCardState extends State<_ElectricalProductCard> {
  List<String> get _allImages {
    final imgs = List<String>.from(widget.product.imagePaths);
    if (imgs.isEmpty && widget.product.imagePath != null) {
      imgs.add(widget.product.imagePath!);
    }
    return imgs;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final imgs = _allImages;
    final hasImage = imgs.isNotEmpty && File(imgs.first).existsSync();

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showDetails(context),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 5,
            child: hasImage
                ? buildProductImage(imgs.first,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity)
                : Container(
                    color: const Color(AppColors.primaryInt)
                        .withValues(alpha: 0.1),
                    child: const Icon(Icons.electrical_services,
                        size: 48, color: Color(AppColors.primaryInt))),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(product.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (product.category != null)
                      Text(product.category!,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.showCashPrice)
                            Text(
                                'كاش: ${AppFormatters.formatCurrency(product.effectiveCashPrice)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                          if (!product.showCashPrice)
                            const Text('اتصل بالسعر',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.orange)),
                          const Text('اتصل للسعر',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.orange)),
                        ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final imgs = _allImages;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ElectricalProductDetailSheet(product: widget.product),
    );
  }
}

// ─── Full-Screen Image Viewer ──────────────────────────────────────────────

class _FullScreenImageViewerE extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullScreenImageViewerE(
      {required this.images, required this.initialIndex});
  @override
  State<_FullScreenImageViewerE> createState() =>
      _FullScreenImageViewerEState();
}

class _FullScreenImageViewerEState extends State<_FullScreenImageViewerE> {
  late int _current;
  late PageController _ctrl;
  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: (widget.images[i].startsWith('http') ||
                    File(widget.images[i]).existsSync())
                ? buildProductImage(widget.images[i], fit: BoxFit.contain)
                : const Icon(Icons.image, size: 80, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class _ElectricalProductDetailSheet extends StatefulWidget {
  final InstallmentProduct product;
  const _ElectricalProductDetailSheet({required this.product});
  @override
  State<_ElectricalProductDetailSheet> createState() =>
      _ElectricalProductDetailSheetState();
}

class _ElectricalProductDetailSheetState
    extends State<_ElectricalProductDetailSheet> {
  int _qty = 1;
  bool _saving = false;
  int _imgIndex = 0;
  final _invoiceDao = CustomerInvoiceDao();

  Future<void> _submitOrder() async {
    final auth = context.read<AuthProvider>();
    final customer = auth.currentCustomer;
    if (customer == null) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final invoiceNo = await _invoiceDao.generateInvoiceNo();
      final totalPrice = widget.product.effectiveCashPrice * _qty;
      final invoiceId = await _invoiceDao.insertInvoice(CustomerInvoice(
        customerId: customer.id!,
        invoiceNo: invoiceNo,
        total: totalPrice,
        paymentMethod: AppConstants.paymentMethodStore,
        status: 'pending',
        notes: 'طلب منتج كهربائي: ${widget.product.name}',
        date: now.substring(0, 10),
        createdAt: now,
        customerStoreType: AppConstants.storeElectrical,
        items: [
          CustomerInvoiceItem(
            itemId: widget.product.id,
            itemName: widget.product.name,
            qty: _qty.toDouble(),
            unitPrice: widget.product.effectiveCashPrice,
            total: totalPrice,
          ),
        ],
      ));
      if (mounted) {
        await PushNotificationService.sendToRole(
          role: 'admin',
          title: NotifMsg.newInvoiceAdminTitle,
          body: '${NotifMsg.newInvoiceAdminBody} $invoiceNo',
          type: 'invoice',
          referenceId: invoiceId,
          referenceType: 'invoice',
        );
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تم إرسال الطلب كفاتورة رقم $invoiceNo'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<String> get _allImages {
    final imgs = List<String>.from(widget.product.imagePaths);
    if (imgs.isEmpty && widget.product.imagePath != null) {
      imgs.add(widget.product.imagePath!);
    }
    return imgs;
  }

  @override
  Widget build(BuildContext context) {
    final imgs = _allImages;
    final product = widget.product;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (imgs.isNotEmpty) ...[
            SizedBox(
              height: 240,
              child: Stack(children: [
                PageView.builder(
                  itemCount: imgs.length,
                  onPageChanged: (i) => setState(() => _imgIndex = i),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _FullScreenImageViewerE(
                              images: imgs, initialIndex: _imgIndex),
                        )),
                    child: (imgs[i].startsWith('http') ||
                            File(imgs[i]).existsSync())
                        ? buildProductImage(imgs[i],
                            width: double.infinity,
                            height: 240,
                            fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image,
                                size: 64, color: Colors.grey)),
                  ),
                ),
                if (imgs.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          imgs.length,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _imgIndex ? 12 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _imgIndex
                                  ? const Color(AppColors.primaryInt)
                                  : Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        )),
                  ),
              ]),
            ),
          ] else
            Container(
                height: 180,
                color: const Color(AppColors.primaryInt).withValues(alpha: 0.1),
                child: const Center(
                    child: Icon(Icons.electrical_services,
                        size: 80, color: Color(AppColors.primaryInt)))),
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              if (product.category != null)
                Chip(
                    label: Text(product.category!),
                    backgroundColor: const Color(AppColors.primaryInt)
                        .withValues(alpha: 0.1)),
              if (product.description != null &&
                  product.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(product.description!,
                    style: const TextStyle(color: Colors.grey)),
              ],
              const Divider(height: 24),
              const Text('الأسعار',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (product.showCashPrice)
                _PriceRow(
                    'سعر الكاش',
                    AppFormatters.formatCurrency(product.effectiveCashPrice),
                    Colors.green,
                    Icons.payments),
              if (!product.showCashPrice)
                const Text('السعر بالتواصل مع الإدارة',
                    style: TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold)),
              // Qty
              Row(children: [
                const Text('الكمية: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Text('$_qty',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _qty++),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppColors.primaryInt),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _submitOrder,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('إرسال الطلب'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _PriceRow(this.label, this.value, this.color, this.icon);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }
}

// ─── My Requests Tab ─────────────────────────────────────────────────────────

class _MyElectricalRequestsTab extends StatefulWidget {
  final Customer? customer;
  const _MyElectricalRequestsTab({this.customer});
  @override
  State<_MyElectricalRequestsTab> createState() =>
      _MyElectricalRequestsTabState();
}

class _MyElectricalRequestsTabState extends State<_MyElectricalRequestsTab> {
  final _dao = RequestDao();
  List<ProductRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.customer?.id;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final list = await _dao.getByCustomer(id);
    if (mounted)
      setState(() {
        _requests = list;
        _loading = false;
      });
  }

  Color _statusColor(String s) {
    switch (s) {
      case AppConstants.requestStatusApproved:
        return Colors.green;
      case AppConstants.requestStatusRejected:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case AppConstants.requestStatusApproved:
        return 'مقبول';
      case AppConstants.requestStatusRejected:
        return 'مرفوض';
      default:
        return 'انتظار';
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case AppConstants.requestStatusApproved:
        return Icons.check_circle;
      case AppConstants.requestStatusRejected:
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_requests.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.list_alt, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('لا توجد طلبات حتى الآن',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('اطلب منتجاً أو تسعير كشف من الصفحة الرئيسية',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _requests.length,
        itemBuilder: (_, i) {
          final r = _requests[i];
          final color = _statusColor(r.status);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side:
                  BorderSide(color: color.withValues(alpha: 0.35), width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon(r.status), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.productName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                            r.createdAt.length >= 10
                                ? r.createdAt.substring(0, 10)
                                : r.createdAt,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                        if (r.notes != null && r.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(r.notes!,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(r.status),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ─── Bundles Tab ─────────────────────────────────────────────────────────────

class _ElectricalBundlesTab extends StatefulWidget {
  final Customer? customer;
  const _ElectricalBundlesTab({this.customer});
  @override
  State<_ElectricalBundlesTab> createState() => _ElectricalBundlesTabState();
}

class _ElectricalBundlesTabState extends State<_ElectricalBundlesTab> {
  final _dao = ElectricalBundleDao();
  List<ElectricalBundle> _bundles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bundles = await _dao.getAllBundles(activeOnly: true);
      if (mounted)
        setState(() {
          _bundles = bundles;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_bundles.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_offer, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('لا توجد ليستات متاحة حالياً',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('سيتم إضافة الليستات قريباً',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _bundles.length,
        itemBuilder: (_, i) => _BundleCard(bundle: _bundles[i]),
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  final ElectricalBundle bundle;
  const _BundleCard({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final color = const Color(AppColors.primaryInt);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Icon(Icons.local_offer, color: color),
            const SizedBox(width: 8),
            Expanded(
                child: Text(bundle.name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color))),
            if ((bundle.discountRate ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.red, borderRadius: BorderRadius.circular(8)),
                child: Text('خصم ${bundle.discountRate?.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
        if (bundle.description != null && bundle.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(bundle.description!,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        if (bundle.items.isNotEmpty) ...[
          const Divider(height: 20, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: const Text('محتويات الليسته',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ...bundle.items.map((item) {
            final discount = bundle.discountRate ?? 0;
            final discountedPrice = item.originalPrice > 0 && discount > 0
                ? item.originalPrice * (1 - discount / 100)
                : item.originalPrice;
            return ListTile(
              dense: true,
              leading: Icon(Icons.check_circle_outline, color: color, size: 18),
              title: Text(item.itemName, style: const TextStyle(fontSize: 13)),
              trailing: item.originalPrice > 0
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (discount > 0)
                          Text(
                            AppFormatters.formatCurrency(item.originalPrice),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          AppFormatters.formatCurrency(discountedPrice),
                          style: TextStyle(
                            color: discount > 0 ? Colors.green : color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : null,
            );
          }),
          // Total row
          if (bundle.items.any((i) => i.originalPrice > 0)) ...[
            const Divider(height: 12, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Builder(builder: (context) {
                final discount = bundle.discountRate ?? 0;
                final originalTotal =
                    bundle.items.fold<double>(0, (s, i) => s + i.originalPrice);
                final discountedTotal = discount > 0
                    ? originalTotal * (1 - discount / 100)
                    : originalTotal;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (discount > 0)
                            Text(
                              AppFormatters.formatCurrency(originalTotal),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            AppFormatters.formatCurrency(discountedTotal),
                            style: TextStyle(
                              color: discount > 0 ? Colors.green : color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ]),
                  ],
                );
              }),
            ),
          ],
        ],
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ─── Invoices Tab ─────────────────────────────────────────────────────────────

class _CustomerInvoicesTab extends StatelessWidget {
  final Customer? customer;
  const _CustomerInvoicesTab({this.customer});

  @override
  Widget build(BuildContext context) {
    return CustomerInvoicesListScreen(
      customerId: customer?.id ?? 0,
      storeType: AppConstants.storeElectrical,
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

// ─── Pricing Sheet Screen ──────────────────────────────────────────────────────

class _PricingSheetScreen extends StatefulWidget {
  final Customer? customer;
  const _PricingSheetScreen({this.customer});
  @override
  State<_PricingSheetScreen> createState() => _PricingSheetScreenState();
}

class _PricingSheetScreenState extends State<_PricingSheetScreen> {
  final _dao = InstallmentProductDao();
  final _invoiceDao = CustomerInvoiceDao();
  List<InstallmentProduct> _products = [];
  final Map<int, double> _qty = {};
  bool _loading = true;
  bool _submitting = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prods = await _dao.getAll(
        availableOnly: true, storeType: AppConstants.storeElectrical);
    if (mounted)
      setState(() {
        _products = prods;
        _loading = false;
      });
  }

  List<InstallmentProduct> get _filteredProducts {
    if (_search.isEmpty) return _products;
    final q = _search.toLowerCase();
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.category?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<InstallmentProduct> get _selected =>
      _filteredProducts.where((p) => (_qty[p.id!] ?? 0) > 0).toList();

  double get _total => _selected.fold(0, (s, p) {
        final price = p.effectiveCashPrice > 0
            ? p.effectiveCashPrice
            : p.effectiveInstallmentPrice;
        return s + price * (_qty[p.id!] ?? 1);
      });

  Future<void> _submitOrder() async {
    final sel = _selected;
    if (sel.isEmpty) return;
    final customer = widget.customer;
    if (customer == null) return;
    setState(() => _submitting = true);
    try {
      int? firstInsertedId;
      for (final p in sel) {
        final inserted = await RequestDao().insert(ProductRequest(
          customerId: customer.id!,
          itemId: null,
          productName: p.name,
          qty: _qty[p.id!] ?? 1,
          paymentMethod: AppConstants.paymentMethodStore,
          depositAmount: 0,
          numInstallments: null,
          date: DateTime.now().toIso8601String().substring(0, 10),
          createdAt: DateTime.now().toIso8601String(),
          storeType: AppConstants.storeElectrical,
        ));
        if (firstInsertedId == null && inserted is int && inserted > 0)
          firstInsertedId = inserted;
      }

      final invoiceNo = await _invoiceDao.generateInvoiceNo();
      final invoice = CustomerInvoice(
        customerId: customer.id!,
        invoiceNo: invoiceNo,
        total: _total,
        paymentMethod: AppConstants.paymentMethodStore,
        status: 'pending',
        notes: 'طلب تسعير كشف',
        date: DateTime.now().toIso8601String().substring(0, 10),
        createdAt: DateTime.now().toIso8601String(),
        customerStoreType: AppConstants.storeElectrical,
        items: sel.map((p) {
          final qty = _qty[p.id!] ?? 1;
          final price = p.effectiveCashPrice > 0
              ? p.effectiveCashPrice
              : p.effectiveInstallmentPrice;
          return CustomerInvoiceItem(
            itemId: p.id,
            itemName: p.name,
            qty: qty,
            unitPrice: price,
            total: price * qty,
          );
        }).toList(),
      );
      final invoiceId = await _invoiceDao.insertInvoice(invoice);

      if (mounted) {
        if (invoiceId > 0) {
          await PushNotificationService.sendToRole(
            role: 'admin',
            title: NotifMsg.newInvoiceAdminTitle,
            body: '${NotifMsg.newInvoiceAdminBody} $invoiceNo',
            type: 'invoice',
            referenceId: invoiceId,
            referenceType: 'invoice',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('تم إرسال طلب التسعير كفاتورة رقم $invoiceNo'),
                backgroundColor: Colors.green),
          );
        } else {
          await PushNotificationService.sendToRole(
            role: 'admin',
            title: NotifMsg.newRequestAdminTitle,
            body: NotifMsg.newRequestAdminBody,
            type: 'request',
            referenceId: firstInsertedId,
            referenceType: 'request',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم إرسال طلب التسعير بنجاح ✓'),
                backgroundColor: Colors.green),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسعير كشف'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Feature 15: Search in pricing sheet
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'بحث في المنتجات...',
                    prefixIcon: const Icon(Icons.search, color: Colors.teal),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              if (_selected.isNotEmpty)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_selected.length} منتج مختار',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal)),
                        Text(AppFormatters.formatCurrency(_total),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.teal)),
                      ]),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (ctx, i) {
                    final p = _filteredProducts[i];
                    final qty = _qty[p.id!] ?? 0;
                    final price = p.effectiveCashPrice > 0
                        ? p.effectiveCashPrice
                        : p.effectiveInstallmentPrice;
                    final imgPath = p.imagePaths.isNotEmpty
                        ? p.imagePaths.first
                        : p.imagePath;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: imgPath != null
                                ? buildProductImage(imgPath,
                                    width: 60, height: 60, fit: BoxFit.cover)
                                : Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.image,
                                        color: Colors.grey),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(p.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                if (price > 0)
                                  Text(AppFormatters.formatCurrency(price),
                                      style: const TextStyle(
                                          color: Colors.green, fontSize: 13)),
                                if (qty > 0)
                                  Text(
                                      'الإجمالي: ${AppFormatters.formatCurrency(price * qty)}',
                                      style: const TextStyle(
                                          color: Colors.teal, fontSize: 12)),
                              ])),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red),
                              onPressed: qty > 0
                                  ? () => setState(() {
                                        _qty[p.id!] = qty - 1;
                                        if (_qty[p.id!]! <= 0)
                                          _qty.remove(p.id!);
                                      })
                                  : null,
                            ),
                            Text(qty.toStringAsFixed(0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.teal),
                              onPressed: () =>
                                  setState(() => _qty[p.id!] = qty + 1),
                            ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]),
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              onPressed: _submitting ? null : _submitOrder,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(
                  'إرسال الطلب  (${AppFormatters.formatCurrency(_total)})'),
            ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
