import 'package:flutter/material.dart';
  import 'package:provider/provider.dart';
  import '../../providers/auth_provider.dart';
  import '../../utils/constants.dart';

  class QuickAccessScreen extends StatelessWidget {
    const QuickAccessScreen({super.key});
    @override
    Widget build(BuildContext context) {
      final auth = context.watch<AuthProvider>();
      if (auth.isAdmin) return const _AdminQA();
      if (auth.isManager) return const _ManagerQA();
      if (auth.isPartner) return const _PartnerQA();
      if (auth.isCustomer) return const _CustomerQA();
      return const _AdminQA();
    }
  }

  void _nav(BuildContext context, String route) => context.read<AuthProvider>().markQuickAccessShown();
  void _navThen(BuildContext context, String sub) {
    context.read<AuthProvider>().markQuickAccessShown();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (context.mounted) Navigator.pushNamed(context, sub); });
  }

  // ─── Admin ────────────────────────────────────────────────────────────────────
  class _AdminQA extends StatelessWidget {
    const _AdminQA();
    @override
    Widget build(BuildContext ctx) {
      final name = ctx.read<AuthProvider>().currentUserName;
      return _Shell(
        name: name, role: 'مدير النظام', icon: Icons.admin_panel_settings,
        colors: const [Color(AppColors.primaryInt), Color(AppColors.primary2Int)],
        title: 'وصول سريع — مدير النظام',
        cards: [
          _C(Icons.dashboard,    'لوحة التحكم',     const Color(AppColors.primaryInt),    () => _nav(ctx, '/dashboard')),
          _C(Icons.people,       'العملاء',          Colors.teal,                           () => _navThen(ctx, '/customers')),
          _C(Icons.inventory_2,  'المنتجات',         const Color(AppColors.installmentInt), () => _navThen(ctx, '/installment-products')),
          _C(Icons.receipt_long, 'الأقساط',          Colors.orange,                         () => _navThen(ctx, '/installments')),
          _C(Icons.payments,     'متابعة الدفعات',   Colors.green,                          () => _navThen(ctx, '/payment-tracking')),
          _C(Icons.inbox,        'فواتير العملاء',    Colors.deepOrange,                     () => _navThen(ctx, '/requests')),
          _C(Icons.bar_chart,    'التقارير',          Colors.indigo,                         () => _navThen(ctx, '/reports')),
          _C(Icons.account_balance,'الخزنة',          Colors.purple,                         () => _navThen(ctx, '/treasury')),
          _C(Icons.point_of_sale,'فاتورة جديدة',     Colors.green.shade700,                 () => _navThen(ctx, '/sales/new')),
        ],
        mainLabel: 'الدخول إلى لوحة التحكم الكاملة',
        mainColor: const Color(AppColors.primaryInt),
        mainIcon: Icons.dashboard,
        onMain: () => _nav(ctx, '/dashboard'),
      );
    }
  }

  // ─── Manager ─────────────────────────────────────────────────────────────────
  class _ManagerQA extends StatelessWidget {
    const _ManagerQA();
    @override
    Widget build(BuildContext ctx) {
      final name = ctx.read<AuthProvider>().currentUserName;
      return _Shell(
        name: name, role: 'مدير', icon: Icons.manage_accounts,
        colors: const [Color(0xFF00695C), Color(0xFF004D40)],
        title: 'وصول سريع — المدير',
        cards: [
          _C(Icons.dashboard,    'لوحة التحكم',     const Color(0xFF00695C),              () => _nav(ctx, '/dashboard')),
          _C(Icons.inventory_2,  'المنتجات',         const Color(AppColors.installmentInt), () => _navThen(ctx, '/installment-products')),
          _C(Icons.people,       'العملاء',          Colors.teal,                           () => _navThen(ctx, '/customers')),
          _C(Icons.receipt_long, 'الأقساط',          Colors.orange,                         () => _navThen(ctx, '/installments')),
          _C(Icons.payments,     'متابعة الدفعات',   Colors.green,                          () => _navThen(ctx, '/payment-tracking')),
          _C(Icons.bar_chart,    'التقارير',          Colors.indigo,                         () => _navThen(ctx, '/reports')),
        ],
        mainLabel: 'الدخول إلى لوحة التحكم الكاملة',
        mainColor: const Color(0xFF00695C),
        mainIcon: Icons.dashboard,
        onMain: () => _nav(ctx, '/dashboard'),
      );
    }
  }

  // ─── Partner ─────────────────────────────────────────────────────────────────
  class _PartnerQA extends StatelessWidget {
    const _PartnerQA();
    @override
    Widget build(BuildContext ctx) {
      final name = ctx.read<AuthProvider>().currentUserName;
      return _Shell(
        name: name, role: 'شريك', icon: Icons.handshake,
        colors: const [Color(0xFF6200EE), Color(0xFF7C3AED)],
        title: 'وصول سريع — الشريك',
        cards: [
          _C(Icons.group,        'مجموعاتي',   const Color(0xFF6200EE), () => _nav(ctx, '/partner-dashboard')),
          _C(Icons.bar_chart,    'أرباحي',     Colors.green,             () => _nav(ctx, '/partner-dashboard')),
          _C(Icons.inventory_2,  'المنتجات',   Colors.teal,              () => _nav(ctx, '/partner-dashboard')),
          _C(Icons.people,       'العملاء',    Colors.orange,            () => _nav(ctx, '/partner-dashboard')),
          _C(Icons.receipt_long, 'الأقساط',    Colors.deepOrange,        () => _nav(ctx, '/partner-dashboard')),
          _C(Icons.chat,         'المحادثات',  Colors.blue,              () => _nav(ctx, '/partner-chat')),
        ],
        mainLabel: 'لوحة تحكم الشريك',
        mainColor: const Color(0xFF6200EE),
        mainIcon: Icons.dashboard,
        onMain: () => _nav(ctx, '/partner-dashboard'),
      );
    }
  }

  // ─── Customer ─────────────────────────────────────────────────────────────────
  class _CustomerQA extends StatelessWidget {
    const _CustomerQA();
    @override
    Widget build(BuildContext context) {
      final auth = context.read<AuthProvider>();
      final customer = auth.currentCustomer;
      final isInstallment = customer?.storeType == AppConstants.storeInstallment;
      final homeRoute = isInstallment ? '/installment-home' : '/electrical-home';
      final storeColor = isInstallment ? const Color(AppColors.installmentInt) : const Color(AppColors.electricalInt);

      void goToTab(int tab) {
        context.read<AuthProvider>().markQuickAccessShown();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(context, homeRoute, (_) => false,
                arguments: {'initialTab': tab});
          }
        });
      }

      return Scaffold(
        backgroundColor: const Color(AppColors.surfaceInt),
        body: SafeArea(
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [storeColor, storeColor.withValues(alpha: 0.7)]),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('مرحباً بك 👋', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text(customer?.name ?? 'العميل',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    if (customer?.isVip == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(AppColors.vipInt), borderRadius: BorderRadius.circular(8)),
                        child: const Text('⭐ عميل VIP', style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                      )
                    else
                      Text(isInstallment ? 'عميل تقسيط' : 'عميل كهربائيات',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                    child: Icon(isInstallment ? Icons.payment : Icons.electrical_services, color: Colors.white, size: 32),
                  ),
                ]),
                const SizedBox(height: 20),
                const Text('اختر ما تريد مباشرة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('المنتجات والأقساط', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.0,
                    children: [
                      _C(Icons.store,         'تصفح المنتجات', storeColor,         () => goToTab(1)).build(context),
                      _C(Icons.payment,       'أقساطي',        Colors.teal,        () => goToTab(2)).build(context),
                      _C(Icons.calculate,     'حاسبة التقسيط', Colors.deepPurple,  () => _nav(context, homeRoute)).build(context),
                      _C(Icons.receipt,       'طلباتي',        Colors.orange,      () => _nav(context, homeRoute)).build(context),
                      _C(Icons.person,        'حسابي',         Colors.indigo,      () => goToTab(3)).build(context),
                      _C(Icons.notifications, 'الإشعارات',     Colors.red,         () => _nav(context, homeRoute)).build(context),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: storeColor, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.store, size: 22),
                      label: const Text('الدخول إلى المتجر', style: TextStyle(fontSize: 15)),
                      onPressed: () => _nav(context, homeRoute),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      );
    }
  }

  // ─── Shared Shell ──────────────────────────────────────────────────────────────
  class _Shell extends StatelessWidget {
    final String name, role, title, mainLabel;
    final IconData icon, mainIcon;
    final List<Color> colors;
    final Color mainColor;
    final List<_C> cards;
    final VoidCallback onMain;
    const _Shell({required this.name, required this.role, required this.icon,
      required this.colors, required this.title, required this.cards,
      required this.mainLabel, required this.mainColor, required this.mainIcon, required this.onMain});
    @override
    Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(AppColors.surfaceInt),
      body: SafeArea(child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('مرحباً بك 👋', style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(role, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
            ]),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            GridView.count(
              crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.0,
              children: cards.map((c) => c.build(context)).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(mainIcon, size: 22), label: Text(mainLabel, style: const TextStyle(fontSize: 15)),
                onPressed: onMain,
              )),
          ]),
        )),
      ])),
    );
  }

  // ─── Card widget ──────────────────────────────────────────────────────────────
  class _C {
    final IconData icon; final String label; final Color color; final VoidCallback onTap;
    const _C(this.icon, this.label, this.color, this.onTap);
    Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey.shade800),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
  