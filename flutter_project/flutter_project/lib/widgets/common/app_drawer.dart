import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/constants.dart';
import '../../database/daos/department_dao.dart';
import '../../models/department.dart';
import '../../screens/admin/installment_products/installment_products_screen.dart';
import '../../screens/admin/installment_products/installment_categories_screen.dart';
import '../../screens/admin/requests/requests_screen.dart';
import '../../screens/admin/customer_invoices/customer_invoices_admin_screen.dart';
import '../../screens/admin/installments/installments_screen.dart';

const _hardcodedDrawerDepts = {
  AppConstants.deptInstallment,
  AppConstants.deptElectrical,
  AppConstants.deptClothing,
};

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});
  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<Department> _customDepts = [];
  final Map<String, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    _loadDepts();
  }

  Future<void> _loadDepts() async {
    try {
      final all = await DepartmentDao().getAll(activeOnly: true);
      if (mounted) {
        setState(() {
          _customDepts = all
              .where((d) => !_hardcodedDrawerDepts.contains(d.storeType))
              .toList();
        });
      }
    } catch (_) {}
  }

  bool _hasSales(AuthProvider a) =>
      a.isAdmin || a.hasPermission(AppConstants.permViewSales) ||
      a.hasPermission(AppConstants.permManageSales);
  bool _hasPurchases(AuthProvider a) =>
      a.isAdmin || a.hasPermission(AppConstants.permManageSales);
  bool _hasTreasury(AuthProvider a) =>
      a.isAdmin || a.hasPermission(AppConstants.permViewTreasury) ||
      a.hasPermission(AppConstants.permManageTreasury);
  bool _hasInventory(AuthProvider a) =>
      a.isAdmin || a.hasPermission(AppConstants.permViewInventory) ||
      a.hasPermission(AppConstants.permManageInventory);
  bool _hasCustomers(AuthProvider a) =>
      a.isAdmin || a.hasPermission(AppConstants.permViewCustomers) ||
      a.hasPermission(AppConstants.permManageCustomers);
  bool _hasInstallments(AuthProvider a) =>
      a.isAdmin || a.hasPermission(AppConstants.permViewInstallments) ||
      a.hasPermission(AppConstants.permManageInstallments);
  bool _hasReports(AuthProvider a) =>
      a.isAdmin || a.hasPermission(AppConstants.permViewReports);
  bool _hasPartners(AuthProvider a) =>
      a.isAdmin || a.hasPermission(AppConstants.permViewPartners);
  bool _hasRequests(AuthProvider a) =>
      a.isAdmin || a.hasPermission(AppConstants.permManageRequests);

  bool _canAccessInstallment(AuthProvider a) =>
      a.isAdmin || a.canAccessDept(AppConstants.deptInstallment) ||
      a.canAccessDept(AppConstants.deptAll);
  bool _canAccessElectrical(AuthProvider a) =>
      a.isAdmin || a.canAccessDept(AppConstants.deptElectrical) ||
      a.canAccessDept(AppConstants.deptAll);
  bool _canAccessClothing(AuthProvider a) =>
      a.isAdmin || a.canAccessDept(AppConstants.deptClothing) ||
      a.canAccessDept(AppConstants.deptAll);
  bool _canAccessStore(AuthProvider a) =>
      a.isAdmin || a.canAccessDept(AppConstants.deptAll);

  void _toggle(String key) => setState(() => _expanded[key] = !(_expanded[key] ?? true));
  bool _isExpanded(String key) => _expanded[key] ?? true;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notif = context.watch<NotificationProvider>();

    if (auth.isViewingAsCustomer) return _customerViewDrawer(auth, context);

    return Drawer(
      width: 280,
      child: Container(
        color: const Color(0xFF4A1700),
        child: SafeArea(
          child: Column(children: [
            // ─── Header ─────────────────────────────────────────────────────
            _DrawerHeader(auth: auth, unreadCount: notif.unreadCount),

            // ─── Navigation ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 8),

                  if (auth.isManager || auth.isAdmin) ...[
                    _navTile(context, 'لوحة التحكم', Icons.dashboard_rounded, '/dashboard',
                        accent: const Color(AppColors.primaryInt)),

                    // ── المبيعات ──────────────────────────────────────────
                    if (_hasSales(auth) && _canAccessStore(auth))
                      _Section(
                        sectionId: 'sales',
                        label: 'المبيعات',
                        icon: Icons.point_of_sale_rounded,
                        color: const Color(0xFF00C896),
                        expanded: _isExpanded('sales'),
                        onToggle: () => _toggle('sales'),
                        children: [
                          _navTile(context, 'فاتورة مبيعات', Icons.receipt_rounded, '/sales/new'),
                          _navTile(context, 'سجل المبيعات', Icons.list_alt_rounded, '/sales'),
                          _navTile(context, 'مرتجع مبيعات', Icons.assignment_return_rounded, '/sales/returns'),
                          if (_hasCustomers(auth)) ...[
                              _navTile(context, 'كشف حساب عميل', Icons.account_balance_wallet_outlined, '/customer-statement'),
                            _navTile(context, 'العملاء', Icons.people_rounded, '/customers'),
                          ],
                        ],
                      ),

                    // ── المشتريات ─────────────────────────────────────────
                    if (_hasPurchases(auth) && _canAccessStore(auth))
                      _Section(
                        sectionId: 'purchases',
                        label: 'المشتريات',
                        icon: Icons.shopping_cart_rounded,
                        color: const Color(0xFFFF6B6B),
                        expanded: _isExpanded('purchases'),
                        onToggle: () => _toggle('purchases'),
                        children: [
                          _navTile(context, 'فاتورة مشتريات', Icons.shopping_cart_checkout_rounded, '/purchases/new'),
                          _navTile(context, 'سجل المشتريات', Icons.list_alt_rounded, '/purchases'),
                          _navTile(context, 'مرتجع مشتريات', Icons.keyboard_return_rounded, '/purchases/returns'),
                          _navTile(context, 'فاتورة مصروفات', Icons.money_off_rounded, '/expenses'),
                        ],
                      ),

                    // ── الخزينة ───────────────────────────────────────────
                    if (_hasTreasury(auth))
                      _Section(
                        sectionId: 'treasury',
                        label: 'الخزينة',
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFFFFBB33),
                        expanded: _isExpanded('treasury'),
                        onToggle: () => _toggle('treasury'),
                        children: [
                          _navTile(context, 'الخزنة', Icons.account_balance_rounded, '/treasury'),
                          _navTile(context, 'متابعة الدفعات', Icons.track_changes_rounded, '/payment-tracking'),
                        ],
                      ),

                    // ── المخزون ───────────────────────────────────────────
                    if (_hasInventory(auth) && _canAccessStore(auth))
                      _Section(
                        sectionId: 'inventory',
                        label: 'المخزون',
                        icon: Icons.inventory_2_rounded,
                        color: const Color(0xFF4FC3F7),
                        expanded: _isExpanded('inventory'),
                        onToggle: () => _toggle('inventory'),
                        children: [
                          _navTile(context, 'إدارة المخزن', Icons.warehouse_rounded, '/inventory'),
                        ],
                      ),

                    // ── الأقساط ───────────────────────────────────────────
                    if (_hasInstallments(auth) && _canAccessInstallment(auth) &&
                        !_canAccessClothing(auth))
                      _Section(
                        sectionId: 'installments',
                        label: 'الأقساط',
                        icon: Icons.payment_rounded,
                        color: const Color(AppColors.primary2Int),
                        expanded: _isExpanded('installments'),
                        onToggle: () => _toggle('installments'),
                        children: [
                          _navTile(context, 'الأقساط', Icons.payment_rounded, '/installments'),
                          _navTile(context, 'منتجات التقسيط', Icons.inventory_2_outlined, '/installment-products'),
                          _navTile(context, 'منتجات الملابس', Icons.checkroom_rounded, '/clothing-products'),
                          _navTile(context, 'فئات التقسيط', Icons.category_outlined, '/installment-categories'),
                          if (_hasRequests(auth)) ...[
                            _navTile(context, 'طلبات التقسيط', Icons.inbox_rounded, '/requests'),
                            _navTile(context, 'طلبات الملابس', Icons.checkroom_outlined, '/clothing-requests'),
                            _navTile(context, 'طلبات الكاش', Icons.receipt_long, '/customer-invoices'),
                          ],
                        ],
                      ),

                    // ── الكهربائية ────────────────────────────────────────
                    if (_canAccessElectrical(auth))
                      _Section(
                        sectionId: 'electrical',
                        label: 'الأدوات الكهربائية',
                        icon: Icons.electrical_services_rounded,
                        color: Colors.indigo,
                        expanded: _isExpanded('electrical'),
                        onToggle: () => _toggle('electrical'),
                        children: [
                          _navTile(context, 'المنتجات الكهربائية', Icons.inventory_2_outlined, '/electrical-products'),
                          _navTile(context, 'فئات الكهربائية', Icons.category_rounded, '/electrical-categories'),
                          _navTile(context, 'الليستات الكهربائية', Icons.local_offer_rounded, '/electrical-bundles'),
                          if (_hasRequests(auth))
                            _electricalInvoicesTile(context, 'فواتير العملاء', Icons.receipt_long),
                        ],
                      ),

                    // ── الملابس ───────────────────────────────────────────
                    if (_canAccessClothing(auth))
                      _Section(
                        sectionId: 'clothing',
                        label: 'قسم الملابس',
                        icon: Icons.checkroom_rounded,
                        color: const Color(AppColors.clothingInt),
                        expanded: _isExpanded('clothing'),
                        onToggle: () => _toggle('clothing'),
                        children: [
                          _navTile(context, 'منتجات الملابس', Icons.inventory_2_outlined, '/clothing-products'),
                          _navTile(context, 'فئات الملابس', Icons.category_outlined, '/installment-categories'),
                          _navTile(context, 'فواتير العملاء', Icons.inbox_rounded, '/clothing-requests'),
                        ],
                      ),

                    // ── Dynamic sections ──────────────────────────────────
                    for (final dept in _customDepts)
                      if (auth.isAdmin || auth.canAccessDept(dept.storeType))
                        _Section(
                          sectionId: dept.storeType,
                          label: dept.name,
                          icon: _deptIcon(dept.storeType),
                          color: _deptColor(dept.storeType),
                          expanded: _isExpanded(dept.storeType),
                          onToggle: () => _toggle(dept.storeType),
                          children: [
                            _customTile(context, 'المنتجات', Icons.inventory_2_outlined, dept),
                            _customCategoryTile(context, 'الفئات', Icons.category_outlined, dept),
                            _customRequestsTile(context, 'فواتير العملاء', Icons.inbox_rounded, dept),
                            _customInstallmentsTile(context, 'الأقساط', Icons.receipt_long, dept),
                          ],
                        ),

                    // ── الشركاء ─────────────────────────────────────────
                    if (_hasPartners(auth))
                      _Section(
                        sectionId: 'projects',
                        label: 'الشركاء',
                        icon: Icons.handshake_rounded,
                        color: Colors.purple.shade400,
                        expanded: _isExpanded('projects'),
                        onToggle: () => _toggle('projects'),
                        children: [
                          _navTile(context, 'إدارة الشركاء', Icons.group_rounded, '/partners'),
                          _navTile(context, 'مجموعات الشركاء', Icons.group_work_rounded, '/partner-groups'),
                          _navTile(context, 'الحركات المالية للمجموعات', Icons.swap_horiz_rounded, '/group-cash-flows'),
                        ],
                      ),

                    // ── التقارير ──────────────────────────────────────────
                    if (_hasReports(auth))
                      _Section(
                        sectionId: 'reports',
                        label: 'التقارير والإحصاء',
                        icon: Icons.bar_chart_rounded,
                        color: const Color(AppColors.primaryInt),
                        expanded: _isExpanded('reports'),
                        onToggle: () => _toggle('reports'),
                        children: [
                          _navTile(context, 'التقارير', Icons.bar_chart_rounded, '/reports'),
                        ],
                      ),

                    // ── التواصل ───────────────────────────────────────────
                    _Section(
                      sectionId: 'comm',
                      label: 'التواصل',
                      icon: Icons.chat_bubble_rounded,
                      color: Colors.teal,
                      expanded: _isExpanded('comm'),
                      onToggle: () => _toggle('comm'),
                      children: [
                        if (auth.isAdmin)
                          _navTile(context, 'المحادثات', Icons.chat_rounded, '/chat'),
                        _navTileWithBadge(context, 'الإشعارات', Icons.notifications_rounded,
                            '/notifications', notif.unreadCount),
                        if (auth.isAdmin)
                          _navTile(context, 'إرسال إشعار', Icons.send_rounded, '/send-notification'),
                      ],
                    ),

                    // ── الإعدادات ─────────────────────────────────────────
                    _Section(
                      sectionId: 'settings',
                      label: 'الإعدادات',
                      icon: Icons.settings_rounded,
                      color: Colors.blueGrey,
                      expanded: _isExpanded('settings'),
                      onToggle: () => _toggle('settings'),
                      children: [
                        if (auth.isAdmin || auth.isManager) ...[
                          _navTile(context, 'إدارة المستخدمين', Icons.manage_accounts_rounded, '/users'),
                          _navTile(context, 'إدارة الأقسام', Icons.category_rounded, '/departments'),
                        ],
                        _navTile(context, 'الإعدادات', Icons.settings_rounded, '/settings'),
                      ],
                    ),
                  ],

                  if (auth.isPartner) ...[
                    _navTile(context, 'المحادثات', Icons.chat_rounded, '/partner-chat',
                        accent: Colors.teal),
                    _navTileWithBadge(context, 'الإشعارات', Icons.notifications_rounded,
                        '/notifications', notif.unreadCount),
                  ],

                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),

                  // ── Logout ─────────────────────────────────────────────
                  ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                    ),
                    title: const Text('تسجيل الخروج',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                    onTap: () async {
                      Navigator.pop(context);
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Customer view drawer ────────────────────────────────────────────────────
  Widget _customerViewDrawer(AuthProvider auth, BuildContext context) {
    return Drawer(
      width: 280,
      child: Container(
        color: const Color(0xFF4A1700),
        child: SafeArea(
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade700, Colors.orange.shade400],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CircleAvatar(
                  backgroundColor: Colors.white24,
                  radius: 28,
                  child: Icon(Icons.visibility_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 10),
                const Text('وضع عرض العميل',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(auth.currentCustomer?.name ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.orange, size: 18),
              ),
              title: const Text('العودة للوحة التحكم',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                auth.exitCustomerView();
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Nav tile ────────────────────────────────────────────────────────────────
  Widget _navTile(BuildContext context, String title, IconData icon, String route,
      {Color? accent}) {
    final current = ModalRoute.of(context)?.settings.name;
    final isActive = current == route;
    final color = accent ?? const Color(0xFF8A9BB0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () { Navigator.pop(context); Navigator.pushNamed(context, route); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            // Active left indicator
            Container(
              width: 4,
              height: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isActive ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: isActive ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: isActive ? color : const Color(0xFF90A4AE), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                    color: isActive ? color : const Color(0xFFB0BEC5),
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _navTileWithBadge(BuildContext context, String title, IconData icon,
      String route, int badge) {
    return Stack(children: [
      _navTile(context, title, icon, route),
      if (badge > 0)
        Positioned(
          top: 5, left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
                color: Colors.red, borderRadius: BorderRadius.circular(8)),
            child: Text(badge > 99 ? '99+' : '$badge',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ),
    ]);
  }

  // ─── Dynamic tiles ───────────────────────────────────────────────────────────
  Widget _customTile(BuildContext ctx, String title, IconData icon, Department dept) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () { Navigator.pop(ctx); Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => InstallmentProductsScreen(initialStoreType: dept.storeType, departmentName: dept.name))); },
          child: _tilePadding(title, icon, _deptColor(dept.storeType)),
        ),
      );

  Widget _customCategoryTile(BuildContext ctx, String title, IconData icon, Department dept) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () { Navigator.pop(ctx); Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => InstallmentCategoriesScreen(initialStoreType: dept.storeType))); },
          child: _tilePadding(title, icon, _deptColor(dept.storeType)),
        ),
      );

  Widget _customRequestsTile(BuildContext ctx, String title, IconData icon, Department dept) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () { Navigator.pop(ctx); Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => RequestsScreen(storeType: dept.storeType))); },
          child: _tilePadding(title, icon, _deptColor(dept.storeType)),
        ),
      );

  Widget _electricalInvoicesTile(BuildContext ctx, String title, IconData icon) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(ctx);
            Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => CustomerInvoicesAdminScreen(
                storeType: AppConstants.storeElectrical,
              ),
            ));
          },
          child: _tilePadding(title, icon, const Color(AppColors.electricalInt)),
        ),
      );

  Widget _customInstallmentsTile(BuildContext ctx, String title, IconData icon, Department dept) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () { Navigator.pop(ctx); Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => InstallmentsScreen(initialStoreType: dept.storeType))); },
          child: _tilePadding(title, icon, _deptColor(dept.storeType)),
        ),
      );

  Widget _tilePadding(String title, IconData icon, Color color) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: const Color(0xFF6B7A8D), size: 16)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
        ]),
      );

  IconData _deptIcon(String storeType) {
    switch (storeType) {
      case AppConstants.storeMobiles: return Icons.phone_android_rounded;
      case AppConstants.storeAccessories: return Icons.watch_rounded;
      default: return Icons.storefront_rounded;
    }
  }

  Color _deptColor(String storeType) {
    switch (storeType) {
      case AppConstants.storeMobiles: return const Color(AppColors.mobilesInt);
      case AppConstants.storeAccessories: return const Color(AppColors.accessoriesInt);
      default:
        const palette = [
          Color(0xFF00796B), Color(0xFF5D4037), Color(0xFF1565C0),
          Color(0xFF6A1B9A), Color(0xFF558B2F), Color(0xFFE65100),
        ];
        final hash = storeType.codeUnits.fold(0, (a, b) => a + b);
        return palette[hash % palette.length];
    }
  }

}

// ─── Drawer Header ────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  final AuthProvider auth;
  final int unreadCount;
  const _DrawerHeader({required this.auth, required this.unreadCount});

  String get _roleLabel {
    switch (auth.currentRole) {
      case 'admin': return 'مدير النظام';
      case 'manager': return 'مدير';
      case 'partner': return 'شريك';
      case 'employee': return 'موظف';
      default: return 'عميل';
    }
  }

  String get _initial =>
      auth.currentUserName.isNotEmpty ? auth.currentUserName[0].toUpperCase() : 'U';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(AppColors.primaryInt), Color(0xFF1A237E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFE8EAF6)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
            ),
            alignment: Alignment.center,
            child: Text(_initial,
                style: const TextStyle(
                    color: Color(AppColors.primaryInt),
                    fontWeight: FontWeight.bold, fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(auth.currentUserName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(_roleLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
            ),
          ])),
          // Notification badge
          Stack(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 2, right: 2,
                child: Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: Text('$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8),
                      textAlign: TextAlign.center),
                ),
              ),
          ]),
        ]),
        const SizedBox(height: 14),
        // App name
        Row(children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.store_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 6),
          const Text('فرصتك للتقسيط',
              style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.5)),
        ]),
      ]),
    );
  }
}

// ─── Collapsible Section ──────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String sectionId;
  final String label;
  final IconData icon;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _Section({
    required this.sectionId,
    required this.label,
    required this.icon,
    required this.color,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section header
      InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
          child: Row(children: [
            Container(
              width: 3, height: 14,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5))),
            Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: color.withValues(alpha: 0.7), size: 16),
          ]),
        ),
      ),
      // Children
      AnimatedCrossFade(
        firstChild: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        secondChild: const SizedBox.shrink(),
        crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        duration: const Duration(milliseconds: 200),
      ),
    ]);
  }
}
