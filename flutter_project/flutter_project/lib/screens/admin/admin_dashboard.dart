import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/installment_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/stat_card.dart';
import '../../database/daos/customer_invoice_dao.dart';
import '../../database/daos/department_dao.dart';
import '../../models/department.dart';
import 'customer_invoices/customer_invoices_admin_screen.dart';
import 'installments/installments_by_section_screen.dart';
import 'installment_products/installment_products_screen.dart';
import 'installment_products/installment_categories_screen.dart';
import 'installments/installments_screen.dart';
import '../../services/push_notification_service.dart';
import '../../utils/notification_messages.dart';

// Departments that have their own hardcoded, specialised sections in the dashboard.
// Any department NOT in this set will get the generic dynamic section.
const _hardcodedDepts = {
  AppConstants.deptInstallment,
  AppConstants.deptElectrical,
};

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, double> _salesSummary = {};
  int _overdueCount = 0;
  int _pendingInvoices = 0;
  int _pendingElectricalInvoices = 0;
  bool _loaded = true;
  String? _loadError;
  List<Department> _allDepartments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _initNotifications();
  }

  void _initNotifications() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id ?? 0;
      final role = auth.currentUser?.role;
      if (userId > 0) {
        context.read<NotificationProvider>().init(userId, role);
      }
    });
  }

  Future<void> _loadData() async {
    setState(() { _loaded = false; _loadError = null; });
    try {
      final now = DateTime.now();
      final from =
          DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
      final to = now.toIso8601String().substring(0, 10);

      // Load departments alongside the other data.
      final deptFuture = DepartmentDao().getAll(activeOnly: true);

      await Future.wait([
        context.read<InventoryProvider>().loadAll(),
        context.read<CustomerProvider>().loadAll(),
        context.read<InstallmentProvider>().loadAll(),
      ]).timeout(
        const Duration(seconds: 20),
        onTimeout: () => [],
      );

      if (!mounted) return;

      Map<String, double> summary = {};
      List overdue = [];
      try {
        summary = await context.read<SalesProvider>().getSummary(from, to)
            .timeout(const Duration(seconds: 10), onTimeout: () => {});
      } catch (_) {}
      try {
        overdue = await context.read<InstallmentProvider>().getOverduePayments()
            .timeout(const Duration(seconds: 10), onTimeout: () => []);
      } catch (_) {}

      int pendingInvoices = 0;
      int pendingElectricalInvoices = 0;
      try {
        final invoiceDao = CustomerInvoiceDao();
        final allInvoices = await invoiceDao.getAll();
        pendingInvoices = allInvoices.where((inv) => inv.status == 'pending').length;
        final electricalInvoices = await invoiceDao.getAll(storeType: AppConstants.storeElectrical);
        pendingElectricalInvoices = electricalInvoices.where((inv) => inv.status == 'pending').length;
      } catch (_) {}

      List<Department> departments = [];
      try {
        departments = await deptFuture;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _salesSummary = summary;
          _overdueCount = overdue.length;
          _pendingInvoices = pendingInvoices;
          _pendingElectricalInvoices = pendingElectricalInvoices;
          _allDepartments = departments;
          _loaded = true;
        });
        // Push alert if there are overdue installments
        if (overdue.isNotEmpty) {
          await PushNotificationService.sendToRole(
            role: 'admin',
            title: NotifMsg.overdueInstallmentTitle,
            body: NotifMsg.overdueInstallmentBody,
            type: 'installment',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _loadError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final inv = context.watch<InventoryProvider>();
    final cust = context.watch<CustomerProvider>();

    // Departments that should render a dynamic section for this user.
    // Only departments NOT already handled by a hardcoded block, and that the
    // current user can actually access, will get the generic section.
    final dynamicDepts = _allDepartments.where((d) =>
        !_hardcodedDepts.contains(d.storeType) &&
        (auth.isAdmin || auth.canAccessDept(d.storeType))).toList();

    final notifProvider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(AppColors.primaryInt), Color(0xFF1A237E)],
            ),
          ),
        ),
        actions: [
          // Realtime notification badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
                tooltip: 'الإشعارات',
              ),
              if (notifProvider.unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      notifProvider.unreadCount > 99
                          ? '99+' : '${notifProvider.unreadCount}',
                      style: const TextStyle(fontSize: 9, color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: !_loaded
          ? const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تحميل البيانات...', style: TextStyle(color: Colors.grey)),
              ],
            ))
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      const Text('حدث خطأ أثناء تحميل البيانات',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_loadError!, style: const TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Welcome Header ───────────────────────────────────
                    _WelcomeHeader(
                      userName: auth.currentUserName,
                      deptLabel: _buildDeptLabel(auth),
                    ),
                    const SizedBox(height: 8),
                    _SystemHeader(
                      title: 'لمحة سريعة',
                      subtitle: 'مؤشرات الأداء الرئيسية على لوحة التحكم',
                      icon: Icons.insights,
                      color: Colors.teal,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.45,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          StatCard(
                            title: 'فواتير كهرباء',
                            value: _pendingElectricalInvoices > 0
                                ? '$_pendingElectricalInvoices انتظار'
                                : 'عرض',
                            icon: Icons.flash_on,
                            color: Colors.blueGrey,
                            subtitle: 'منتجات الكهربائيات',
                            highlight: _pendingElectricalInvoices > 0,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerInvoicesAdminScreen(
                                  storeType: AppConstants.storeElectrical,
                                ),
                              ),
                            ),
                          ),
                          StatCard(
                            title: 'أقساط متأخرة',
                            value: _overdueCount > 0
                                ? '$_overdueCount متأخرة'
                                : 'ممتاز',
                            icon: Icons.warning_amber,
                            color: _overdueCount > 0 ? Colors.red : Colors.green,
                            subtitle: 'أولوية للسداد',
                            highlight: _overdueCount > 0,
                            onTap: () => Navigator.pushNamed(context, '/installments'),
                          ),
                          StatCard(
                            title: 'العملاء النشطون',
                            value: cust.customers.length.toString(),
                            icon: Icons.people,
                            color: Colors.indigo,
                            subtitle: 'قاعدة العملاء',
                            onTap: () => Navigator.pushNamed(context, '/customers'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (auth.isAdmin || auth.isManager) _QuickNavRow(items: [
                      _QuickNavItem(
                        icon: Icons.description,
                        label: 'الفواتير',
                        route: '/customer-invoices',
                        color: Colors.blue,
                      ),
                      _QuickNavItem(
                        icon: Icons.receipt_long,
                        label: 'الأقساط',
                        route: '/installments',
                        color: Colors.orange,
                      ),
                      _QuickNavItem(
                        icon: Icons.notifications,
                        label: 'الإشعارات',
                        route: '/notifications',
                        color: Colors.purple,
                      ),
                      _QuickNavItem(
                        icon: Icons.manage_accounts,
                        label: 'المستخدمون',
                        route: '/users',
                        color: Colors.indigo,
                      ),
                    ]),

                    // ══ System 1: Store ERP — admin & all-dept managers only ══
                    if (auth.isAdmin || (auth.isManager && auth.canAccessDept(AppConstants.deptAll) && auth.departmentType == AppConstants.deptAll)) ...[
                      _SystemHeader(
                        title: 'النظام الأول — نظام المتجر',
                        subtitle: 'المبيعات • المخزن • الخزنة • التقارير',
                        icon: Icons.store,
                        color: const Color(AppColors.primaryInt),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.5,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            StatCard(
                              title: 'مبيعات الشهر',
                              value: AppFormatters.formatCurrency(
                                  _salesSummary['total_sales'] ?? _salesSummary['total'] ?? _salesSummary['total_amount'] ?? _salesSummary['revenue'] ?? 0),
                              icon: Icons.trending_up,
                              color: Colors.green,
                              onTap: () => Navigator.pushNamed(context, '/sales'),
                            ),
                            StatCard(
                              title: 'العملاء',
                              value: cust.customers.length.toString(),
                              icon: Icons.people,
                              color: Colors.blue,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/customers'),
                            ),
                            StatCard(
                              title: 'المخزون',
                              value: inv.items.length.toString(),
                              icon: Icons.inventory,
                              color: Colors.orange,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/inventory'),
                            ),
                            StatCard(
                              title: 'متأخرات الأقساط',
                              value: _overdueCount.toString(),
                              icon: Icons.warning_amber,
                              color: _overdueCount > 0 ? Colors.red : Colors.grey,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/installments'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _QuickNavRow(items: [
                        _QuickNavItem(
                            icon: Icons.point_of_sale,
                            label: 'فاتورة جديدة',
                            route: '/sales/new',
                            color: Colors.green),
                        _QuickNavItem(
                            icon: Icons.shopping_cart,
                            label: 'فاتورة شراء',
                            route: '/purchases',
                            color: Colors.orange),
                        _QuickNavItem(
                            icon: Icons.account_balance,
                            label: 'الخزنة',
                            route: '/treasury',
                            color: Colors.purple),
                        _QuickNavItem(
                            icon: Icons.bar_chart,
                            label: 'التقارير',
                            route: '/reports',
                            color: Colors.indigo),
                        _QuickNavItem(
                            icon: Icons.engineering,
                            label: 'نقاط الفنيين',
                            route: '/technician-points',
                            color: Colors.teal),
                        _QuickNavItem(
                            icon: Icons.store_mall_directory,
                            label: 'الموردون',
                            route: '/suppliers',
                            color: Colors.teal),
                      ]),
                    ],

                    // ══ System 2: Installment dept ══
                    if (auth.isAdmin || auth.canAccessDept(AppConstants.deptInstallment)) ...[
                      _SystemHeader(
                        title: 'النظام الثاني — التقسيط',
                        subtitle: 'منتجات التقسيط • الأقساط • الفواتير',
                        icon: Icons.payment,
                        color: const Color(AppColors.installmentInt),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.5,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            StatCard(
                              title: 'منتجات التقسيط',
                              value: 'عرض',
                              icon: Icons.inventory_2,
                              color: const Color(AppColors.installmentInt),
                              onTap: () {
                                if (!auth.isAdmin &&
                                    auth.departmentType != null &&
                                    auth.departmentType != AppConstants.deptAll) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InstallmentProductsScreen(
                                        initialStoreType: auth.departmentType!,
                                        departmentName: AppConstants.deptLabels[auth.departmentType] ?? auth.departmentType!,
                                      ),
                                    ),
                                  );
                                } else {
                                  Navigator.pushNamed(context, '/installment-products');
                                }
                              },
                            ),
                            StatCard(
                              title: 'عقود الأقساط',
                              value: 'عرض',
                              icon: Icons.receipt_long,
                              color: Colors.orange,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/installments/installment'),
                            ),
                            StatCard(
                              title: 'فواتير العملاء',
                              value: _pendingInvoices > 0
                                  ? '$_pendingInvoices انتظار'
                                  : 'عرض',
                              icon: Icons.description,
                              color: _pendingInvoices > 0 ? Colors.red : Colors.blue,
                              onTap: () => Navigator.pushNamed(
                                  context, '/customer-invoices'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ══ System 3: Electrical dept ══
                    if (auth.isAdmin || auth.canAccessDept(AppConstants.deptElectrical)) ...[
                      _SystemHeader(
                        title: 'النظام الثالث — الكهربائيات',
                        subtitle: 'منتجات كهربائية • ليستات • فئات',
                        icon: Icons.electrical_services,
                        color: const Color(AppColors.electricalInt),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.5,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            StatCard(
                              title: 'المنتجات الكهربائية',
                              value: 'عرض',
                              icon: Icons.electrical_services,
                              color: const Color(AppColors.electricalInt),
                              onTap: () => Navigator.pushNamed(
                                  context, '/electrical-products'),
                            ),
                            StatCard(
                              title: 'أقساط الكهربائيات',
                              value: 'عرض',
                              icon: Icons.receipt_long,
                              color: Colors.blueGrey,
                              onTap: () => Navigator.pushNamed(
                                  context, '/installments/electrical'),
                            ),
                            StatCard(
                              title: 'فواتير العملاء',
                              value: _pendingElectricalInvoices > 0
                                  ? '$_pendingElectricalInvoices انتظار'
                                  : 'عرض',
                              icon: Icons.receipt_long,
                              color: _pendingElectricalInvoices > 0 ? Colors.red : Colors.teal,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerInvoicesAdminScreen(
                                    storeType: AppConstants.storeElectrical,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ══ Installments by section ══
                    if (auth.isAdmin || (auth.isManager && (auth.canAccessDept(AppConstants.deptInstallment) || auth.canAccessDept(AppConstants.deptElectrical) || auth.canAccessDept(AppConstants.deptAll)))) ...[
                      _SystemHeader(
                        title: 'الأقساط حسب القسم',
                        subtitle: 'ملخص شامل • التقسيط والكهربائيات',
                        icon: Icons.account_tree,
                        color: Colors.deepPurple,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => const InstallmentsBySectionScreen(),
                            )),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
                              ),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.bar_chart, color: Colors.deepPurple, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('عرض الأقساط حسب القسم',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                                          color: Colors.deepPurple)),
                                  const SizedBox(height: 2),
                                  Text('إجماليات • محصّل • متبقي • منتهي الأجل لكل قسم',
                                      style: TextStyle(color: Colors.deepPurple.withValues(alpha: 0.7), fontSize: 11)),
                                ])),
                                const Icon(Icons.arrow_forward_ios, color: Colors.deepPurple, size: 16),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],



                    // ══ Dynamic sections for all other (custom / new) departments ══
                    for (final dept in dynamicDepts)
                      _DynamicDeptSection(dept: dept),

                    // ══ Partners / Chat — admin only ══
                    if (auth.isAdmin || auth.canViewPartners) ...[
                      _SystemHeader(
                        title: 'الشركاء والتواصل',
                        subtitle: 'مجموعات الشركاء • المحادثات • الإشعارات',
                        icon: Icons.handshake,
                        color: Colors.purple,
                      ),
                      _QuickNavRow(items: [
                        _QuickNavItem(
                            icon: Icons.handshake,
                            label: 'الشركاء',
                            route: '/partners',
                            color: Colors.purple),
                        _QuickNavItem(
                            icon: Icons.chat,
                            label: 'المحادثات',
                            route: '/chat',
                            color: Colors.blue),
                        _QuickNavItem(
                            icon: Icons.notifications,
                            label: 'الإشعارات',
                            route: '/notifications',
                            color: Colors.amber),
                        _QuickNavItem(
                            icon: Icons.manage_accounts,
                            label: 'المستخدمون',
                            route: '/users',
                            color: Colors.indigo),
                        _QuickNavItem(
                            icon: Icons.category,
                            label: 'الأقسام',
                            route: '/departments',
                            color: Colors.teal),
                      ]),
                    ],

                    // ══ Sales/Purchases/Inventory for non-all dept managers ══
                    if (auth.isManager && auth.departmentType != AppConstants.deptAll && auth.departmentType != null) ...[
                      _SystemHeader(
                        title: 'المبيعات والمخزون',
                        subtitle: 'المبيعات • المشتريات • المخزن',
                        icon: Icons.storefront,
                        color: Colors.teal,
                      ),
                      _QuickNavRow(items: [
                        _QuickNavItem(
                            icon: Icons.point_of_sale,
                            label: 'المبيعات',
                            route: '/sales',
                            color: Colors.teal),
                        _QuickNavItem(
                            icon: Icons.shopping_cart,
                            label: 'المشتريات',
                            route: '/purchases',
                            color: Colors.orange),
                        _QuickNavItem(
                            icon: Icons.inventory,
                            label: 'المخزن',
                            route: '/inventory',
                            color: Colors.indigo),
                      ]),
                    ],

                    // ══ Admin/Manager management section ══
                    if (auth.isAdmin || auth.isManager) ...[
                      _SystemHeader(
                        title: 'إعدادات النظام',
                        subtitle: auth.isAdmin ? 'المستخدمون • الأقسام • الإعدادات' : 'المستخدمون • الإعدادات',
                        icon: Icons.admin_panel_settings,
                        color: Colors.grey.shade700,
                      ),
                      _QuickNavRow(items: [
                        _QuickNavItem(
                            icon: Icons.manage_accounts,
                            label: 'المستخدمون',
                            route: '/users',
                            color: Colors.indigo),
                        _QuickNavItem(
                            icon: Icons.settings,
                            label: 'الإعدادات',
                            route: '/settings',
                            color: Colors.grey),
                        if (auth.isAdmin || auth.departmentType == AppConstants.deptAll) ...[
                          _QuickNavItem(
                              icon: Icons.category,
                              label: 'الأقسام',
                              route: '/departments',
                              color: Colors.teal),
                          _QuickNavItem(
                              icon: Icons.bar_chart,
                              label: 'التقارير',
                              route: '/reports',
                              color: Colors.indigo),
                          _QuickNavItem(
                              icon: Icons.store_mall_directory,
                              label: 'الموردون',
                              route: '/suppliers',
                              color: Colors.teal),
                          _QuickNavItem(
                              icon: Icons.group_work,
                              label: 'مجموعات الشركاء',
                              route: '/partner-groups',
                              color: Colors.purple),
                        ],
                      ]),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  String _buildDeptLabel(AuthProvider auth) {
    if (auth.isAdmin) return 'مدير النظام';
    if (auth.departmentType == null || auth.departmentType == AppConstants.deptAll) {
      return 'مدير عام';
    }
    // Check the loaded departments list first for a human-friendly name.
    final match = _allDepartments
        .where((d) => d.storeType == auth.departmentType)
        .toList();
    if (match.isNotEmpty) return match.first.name;
    // Fall back to the static labels map.
    return AppConstants.deptLabels[auth.departmentType] ?? auth.departmentType!;
  }
}

// ─── Dynamic department section for any non-hardcoded department ──────────────

class _DynamicDeptSection extends StatelessWidget {
  final Department dept;
  const _DynamicDeptSection({required this.dept});

  /// Pick a colour from a small palette based on the store-type string so
  /// each department gets a consistent, distinct colour.
  Color _deptColor() {
    const palette = [
      Color(AppColors.mobilesInt),
      Color(AppColors.accessoriesInt),
      Color(0xFF00796B),
      Color(0xFF5D4037),
      Color(0xFF1565C0),
      Color(0xFF6A1B9A),
      Color(0xFF558B2F),
      Color(0xFFE65100),
    ];
    final hash = dept.storeType.codeUnits.fold(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }

  IconData _deptIcon() {
    switch (dept.storeType) {
      case AppConstants.storeMobiles: return Icons.phone_android;
      case AppConstants.storeAccessories: return Icons.watch;
      default: return Icons.storefront;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _deptColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SystemHeader(
          title: dept.name,
          subtitle: 'المنتجات • الأقساط • الفئات',
          icon: _deptIcon(),
          color: color,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              StatCard(
                title: 'المنتجات',
                value: 'عرض',
                icon: Icons.inventory_2_outlined,
                color: color,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InstallmentProductsScreen(
                      initialStoreType: dept.storeType,
                      departmentName: dept.name,
                    ),
                  ),
                ),
              ),
              StatCard(
                title: 'الفئات',
                value: 'عرض',
                icon: Icons.category_outlined,
                color: color,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InstallmentCategoriesScreen(
                      initialStoreType: dept.storeType,
                    ),
                  ),
                ),
              ),
              StatCard(
                title: 'الأقساط',
                value: 'عرض',
                icon: Icons.receipt_long,
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InstallmentsScreen(
                      initialStoreType: dept.storeType,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  final String userName;
  final String deptLabel;
  const _WelcomeHeader({required this.userName, required this.deptLabel});

  String get _initial => userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير';
    if (h < 17) return 'مساء الخير';
    return 'مساء النور';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(AppColors.primaryInt), Color(0xFF1A237E)],
        ),
      ),
      child: Stack(children: [
        // Decorative circle
        Positioned(
          top: -20, left: -20,
          child: Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -30, right: 40,
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Row(children: [
          // Avatar
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(_initial,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 2),
            Text(userName,
                style: const TextStyle(color: Colors.white,
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified_rounded, color: Colors.white70, size: 12),
                const SizedBox(width: 4),
                Text(deptLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ])),
        ]),
      ]),
    );
  }
}

class _SystemHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _SystemHeader(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.10), color.withValues(alpha: 0.03)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.12)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: color)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5)),
          ]),
        ),
        Container(
          width: 3, height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ]),
    );
  }
}

class _QuickNavRow extends StatelessWidget {
  final List<_QuickNavItem> items;
  const _QuickNavRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) => SizedBox(
          width: (MediaQuery.of(context).size.width - 24 - (items.length - 1) * 8) /
              items.length.clamp(3, 5),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, item.route),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: item.color.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [item.color.withValues(alpha: 0.18), item.color.withValues(alpha: 0.08)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 18),
                ),
                const SizedBox(height: 6),
                Text(item.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: item.color,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _QuickNavItem {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _QuickNavItem(
      {required this.icon,
      required this.label,
      required this.route,
      required this.color});
}
