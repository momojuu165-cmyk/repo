import 'package:flutter/material.dart';
import '../../database/daos/installment_product_dao.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/installment_product.dart';
import '../../models/item_group.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/image_helper.dart';
import '../admin/installment_products/product_detail_screen.dart';

// Feature 10: Browse products without login — guest mode
// Prompts login only when user tries to take action (order/request).
class GuestBrowseScreen extends StatefulWidget {
  const GuestBrowseScreen({super.key});

  @override
  State<GuestBrowseScreen> createState() => _GuestBrowseScreenState();
}

class _GuestBrowseScreenState extends State<GuestBrowseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _dao = InstallmentProductDao();
  List<InstallmentProduct> _products = [];
  List<ItemGroup> _groups = [];
  bool _loading = true;
  String _query = '';
  String? _selectedCategory;
  String _storeType = 'installment'; // Default browse view

  static const _storeLabels = {
    'installment': 'منتجات التقسيط',
    'electrical': 'الأدوات الكهربائية',
    'clothing': 'الملابس',
    'mobiles': 'الموبايلات',
    'accessories': 'الإكسسوارات',
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {

    final products = await _dao.getAll(availableOnly: true);
    final groupRows = await Supabase.instance.client
        .from('item_groups')
        .select()
        .order('name', ascending: true);
    if (mounted) {
      setState(() {
        _products = products;
        _groups = List<Map<String, dynamic>>.from(groupRows).map(ItemGroup.fromMap).toList();
        _loading = false;
      });
    }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  List<InstallmentProduct> get _filtered {
    return _products.where((p) {
      final matchStore = p.storeType == _storeType;
      final matchQuery = _query.isEmpty ||
          p.name.contains(_query) ||
          (p.description?.contains(_query) ?? false);
      final matchCat = _selectedCategory == null || p.category == _selectedCategory;
      return matchStore && matchQuery && matchCat;
    }).toList();
  }

  Set<String> get _categories {
    return _products
        .where((p) => p.storeType == _storeType && p.category != null)
        .map((p) => p.category!)
        .toSet();
  }

  void _promptLogin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(AppColors.primaryInt).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline,
                  color: Color(AppColors.primaryInt), size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'تسجيل الدخول مطلوب',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'يجب تسجيل الدخول أو إنشاء حساب لإرسال طلب شراء',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context); // back to login
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('تسجيل الدخول'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: const Color(AppColors.primaryInt),
                      side: const BorderSide(color: Color(AppColors.primaryInt)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context); // back to login → register
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('تسجيل حساب'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(AppColors.primaryInt),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.surfaceInt),
      appBar: AppBar(
        title: const Text('تصفح المنتجات'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'تسجيل الدخول',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Store-type selector
                Container(
                  color: const Color(AppColors.primaryInt),
                  padding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _storeLabels.entries.map((e) {
                        final selected = _storeType == e.key;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _storeType = e.key;
                              _selectedCategory = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  color: selected
                                      ? const Color(AppColors.primaryInt)
                                      : Colors.white,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Search
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ابحث عن منتج...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                // Category chips
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: FilterChip(
                            label: const Text('الكل'),
                            selected: _selectedCategory == null,
                            onSelected: (_) =>
                                setState(() => _selectedCategory = null),
                          ),
                        ),
                        ..._categories.map((c) => Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: FilterChip(
                                label: Text(c),
                                selected: _selectedCategory == c,
                                onSelected: (_) =>
                                    setState(() => _selectedCategory = c),
                              ),
                            )),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                // Products
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('لا توجد منتجات',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) => _GuestProductCard(
                            product: _filtered[i],
                            onOrderTap: () => _promptLogin(ctx),
                            onDetailTap: () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(
                                    product: _filtered[i]),
                              ),
                            ),
                          ),
                        ),
                ),
                // Bottom banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.primaryInt).withValues(alpha: 0.05),
                    border: Border(
                        top: BorderSide(
                            color: const Color(AppColors.primaryInt)
                                .withValues(alpha: 0.1))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Color(AppColors.primaryInt)),
                      const SizedBox(width: 6),
                      const Text(
                        'سجل دخولك لإرسال طلب شراء أو تقسيط',
                        style: TextStyle(
                            color: Color(AppColors.primaryInt),
                            fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(AppColors.primaryInt),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'دخول',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _GuestProductCard extends StatelessWidget {
  final InstallmentProduct product;
  final VoidCallback onOrderTap;
  final VoidCallback? onDetailTap;

  const _GuestProductCard({
    required this.product,
    required this.onOrderTap,
    this.onDetailTap,
  });

  @override
  Widget build(BuildContext context) {
    final imgPath = product.imagePaths.isNotEmpty
        ? product.imagePaths.first
        : product.imagePath;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDetailTap,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          Expanded(
            child: imgPath != null
                ? buildProductImage(
                    imgPath,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    fallback: _PlaceholderBox(name: product.name),
                  )
                : _PlaceholderBox(name: product.name),
          ),
          // Info section
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.category != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    product.category!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 6),
                if (product.showCashPrice && product.effectiveCashPrice > 0)
                  Text(
                    'نقداً: ${AppFormatters.formatCurrency(product.effectiveCashPrice)}',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                if (product.showInstallmentPrice)
                  Text(
                    'تقسيط: ${AppFormatters.formatCurrency(product.effectiveInstallmentPrice)}',
                    style: const TextStyle(
                        color: Color(AppColors.installmentInt),
                        fontSize: 12),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onOrderTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppColors.primaryInt),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('اطلب الآن',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

class _PlaceholderBox extends StatelessWidget {
  final String name;
  const _PlaceholderBox({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(AppColors.primaryInt).withValues(alpha: 0.06),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 36, color: Colors.grey),
            const SizedBox(height: 4),
            Text(
              name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(
                  fontSize: 26,
                  color: Color(AppColors.primaryInt),
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
