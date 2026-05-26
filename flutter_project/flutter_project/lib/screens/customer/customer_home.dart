import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/customer.dart';
import '../../models/item.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'product_browse_screen.dart';
import 'my_orders_screen.dart';
import 'customer_installments_screen.dart';
import 'product_request_screen.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _tab = 0;
  bool _browseAuthorized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadAll();
      final auth = context.read<AuthProvider>();
      if (auth.currentCustomer?.id != null) {
        context.read<NotificationProvider>().init(
              auth.currentCustomer!.id!,
              AppConstants.roleCustomer,
            );
      }
    });
  }

  Future<bool> _validateTemporaryAccessCode(String code) async {
    final expiration = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    try {
      final result = await Supabase.instance.client
          .from('temporary_access_codes')
          .select()
          .eq('code', code)
          .eq('active', true)
          .gte('created_at', expiration.toIso8601String())
          .limit(1)
          .maybeSingle();
      return result != null;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('column') && message.contains('active')) {
        try {
          final result = await Supabase.instance.client
              .from('temporary_access_codes')
              .select()
              .eq('code', code)
              .gte('created_at', expiration.toIso8601String())
              .limit(1)
              .maybeSingle();
          return result != null;
        } catch (_) {
          return false;
        }
      }
      return false;
    }
  }

  Future<void> _requestBrowseCode() async {
    final controller = TextEditingController();
    var errorText = '';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('كود تصفح مؤقت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ادخل كود التصفح المؤقت للوصول إلى المنتجات.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'الكود',
                errorText: errorText.isEmpty ? null : errorText,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) {
                setState(() {
                  errorText = 'الرجاء إدخال الكود';
                });
                return;
              }
              final valid = await _validateTemporaryAccessCode(code);
              if (!valid) {
                setState(() {
                  errorText = 'الكود غير صحيح أو منتهي الصلاحية';
                });
                return;
              }
              if (!mounted) return;
              setState(() {
                _browseAuthorized = true;
                _tab = 1;
              });
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final customer = auth.currentCustomer;

    final tabs = [
      _HomeTab(customer: customer),
      const ProductBrowseScreen(),
      const MyOrdersScreen(),
      const CustomerInstallmentsScreen(),
      _ProfileTab(customer: customer),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('متجرنا'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
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
              }
            },
          ),
        ],
      ),
      body: tabs[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) async {
          if (i == 1 && !_browseAuthorized) {
            await _requestBrowseCode();
            return;
          }
          setState(() => _tab = i);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(AppColors.primaryInt),
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'المنتجات',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'طلباتي',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'أقساطي',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.person),
                if (customer != null && customer.points > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${customer.points}',
                        style: const TextStyle(
                            fontSize: 8, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final Customer? customer;

  const _HomeTab({this.customer});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final priceType = customer?.priceType ?? AppConstants.priceRetail;

    final featuredItems = inv.items
        .where((i) => !i.isBlocked && i.quantity > 0)
        .take(6)
        .toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _WelcomeBanner(customer: customer),
        const SizedBox(height: 16),
        _LoyaltyCard(customer: customer),
        if (customer != null && customer!.points > 0)
          const SizedBox(height: 16),
        const _SectionTitle(title: 'تصفح حسب الفئة', icon: Icons.category),
        const SizedBox(height: 8),
        const _CategoryGrid(),
        const SizedBox(height: 16),
        const _SectionTitle(
            title: 'منتجات مميزة', icon: Icons.stars_rounded),
        const SizedBox(height: 8),
        if (featuredItems.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: Text('لا توجد منتجات متاحة حالياً',
                    style: TextStyle(color: Colors.grey))),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: featuredItems.length,
              itemBuilder: (ctx, i) => _FeaturedProductCard(
                item: featuredItems[i],
                priceType: priceType,
              ),
            ),
          ),
        const SizedBox(height: 16),
        const _PromoCard(),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final Customer? customer;

  const _WelcomeBanner({this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(AppColors.primaryInt),
            Color(0xFF283593),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً، ${customer?.name ?? 'عميلنا العزيز'} 👋',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ماذا تحتاج اليوم؟',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.accentInt),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'تصفح المنتجات',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.electrical_services,
                color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyCard extends StatelessWidget {
  final Customer? customer;

  const _LoyaltyCard({this.customer});

  @override
  Widget build(BuildContext context) {
    if (customer == null || customer!.points == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        color: Colors.amber.shade50,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.amber.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, color: Colors.amber, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('نقاط الولاء',
                        style: TextStyle(
                            color: Colors.brown,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(
                      '${customer!.points} نقطة',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 22),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('رصيدك',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(
                    AppFormatters.formatCurrency(customer!.balance),
                    style: TextStyle(
                      color:
                          customer!.balance > 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(AppColors.primaryInt), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(AppColors.primaryInt)),
          ),
        ],
      ),
    );
  }
}

class _Category {
  final String name;
  final IconData icon;
  final Color color;

  const _Category(this.name, this.icon, this.color);
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  static const List<_Category> _categories = [
    _Category('كهرباء', Icons.bolt, Colors.amber),
    _Category('كابلات', Icons.cable, Colors.blue),
    _Category('إضاءة', Icons.lightbulb, Colors.orange),
    _Category('أدوات', Icons.build, Colors.grey),
    _Category('سباكة', Icons.water_drop, Colors.cyan),
    _Category('حماية', Icons.security, Colors.red),
    _Category('محولات', Icons.transform, Colors.purple),
    _Category('لوحات', Icons.dashboard, Colors.teal),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          return Container(
            width: 80,
            margin: const EdgeInsets.only(left: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: cat.color.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  cat.name,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeaturedProductCard extends StatelessWidget {
  final Item item;
  final String priceType;

  const _FeaturedProductCard({
    required this.item,
    required this.priceType,
  });

  Widget _buildImage() {
    final path = item.imagePath;
    if (path != null && path.isNotEmpty) {
      final isUrl = path.startsWith('http');
      if (isUrl) {
        return Image.network(path, width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder());
      }
      if (path.startsWith('/') && File(path).existsSync()) {
        return Image.file(File(path), width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder());
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(AppColors.primaryInt).withValues(alpha: 0.05),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2, size: 30, color: Colors.grey),
            Text(
              item.name[0],
              style: const TextStyle(
                  fontSize: 22,
                  color: Color(AppColors.primaryInt),
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => ProductRequestScreen(item: item),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(left: 10),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  child: _buildImage(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.formatCurrency(
                          item.priceForType(priceType)),
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(AppColors.accentInt), Color(0xFFF57F17)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.payment, color: Colors.white, size: 36),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نظام التقسيط المريح',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'اشتر الآن وادفع على دفعات مريحة',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ─── Profile Tab ──────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  final Customer? customer;

  const _ProfileTab({this.customer});

  @override
  Widget build(BuildContext context) {
    if (customer == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor:
                      const Color(AppColors.primaryInt).withValues(alpha: 0.1),
                  child: Text(
                    customer!.name[0],
                    style: const TextStyle(
                        fontSize: 32,
                        color: Color(AppColors.primaryInt),
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(customer!.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text(customer!.phone ?? '',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet,
                    color: Colors.red),
                title: const Text('رصيدي المدين'),
                trailing: Text(
                  AppFormatters.formatCurrency(customer!.balance),
                  style: TextStyle(
                    color:
                        customer!.balance > 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('نقاط الولاء'),
                trailing: Text(
                  '${customer!.points} نقطة',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.price_change, color: Colors.blue),
                title: const Text('نوع السعر'),
                trailing: Text(
                  _priceLabel(customer!.priceType),
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _priceLabel(String t) {
    switch (t) {
      case 'wholesale':
        return 'جملة';
      case 'semi_wholesale':
        return 'نصف جملة';
      default:
        return 'قطاعي';
    }
  }
}
