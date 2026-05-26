import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../database/daos/partner_group_dao.dart';
import '../../database/daos/installment_product_dao.dart';
import '../../models/partner_group.dart';
import '../../models/installment_product.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../providers/notification_provider.dart';
import '../../models/app_notification.dart';
import '../admin/chat/chat_detail_screen.dart';
import 'financial_movements_screen.dart';

class PartnerDashboard extends StatefulWidget {
  const PartnerDashboard({super.key});
  @override
  State<PartnerDashboard> createState() => _PartnerDashboardState();
}

class _PartnerDashboardState extends State<PartnerDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _groupDao = PartnerGroupDao();
  final _installmentProductDao = InstallmentProductDao();

  List<Map<String, dynamic>> _myGroups = [];
  List<Map<String, dynamic>> _myRevenues = [];
  List<Map<String, dynamic>> _myCashFlows = [];
  List<InstallmentProduct> _installmentProducts = [];
  Set<String> _assignedProductNames = {};
  List<Map<String, dynamic>> _groupProductAssignments = [];
  List<Map<String, dynamic>> _myInstallments = [];
  double _myProfitPercentage = 0;
  bool _loading = true;

  static const _monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  int? _cachedUserId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    // Cache userId at init to prevent null issues if auth state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        _cachedUserId = auth.currentUser?.id;
        if (_cachedUserId != null) {
          context.read<NotificationProvider>().init(
                _cachedUserId!,
                auth.currentUser?.role ?? AppConstants.rolePartner,
              );
        }
        _load();
      }
    });
    // Refresh data when switching back to groups or profits tab
    _tabCtrl.addListener(() {
      if (_tabCtrl.index <= 1 && !_loading && mounted) {
        _load();
      }
    });
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final userId = _cachedUserId ?? auth.currentUser?.id;

    List<Map<String, dynamic>> groups = [];
    List<Map<String, dynamic>> revenues = [];
    List<InstallmentProduct> allProducts = [];
    Set<String> assignedNames = {};
    List<Map<String, dynamic>> groupProductAssignments = [];
    double profitPct = 0;

    // ── 1. Load groups (critical — all other tabs depend on this) ──────────────
    if (userId != null) {
      try {
        final myGroupRows = await _groupDao.getGroupsForUser(userId);
        for (final row in myGroupRows) {
          final groupId = row['id'] as int;
          final group = PartnerGroup.fromMap(row);
          final members = await _groupDao.getGroupMembers(groupId);
          final myMembership = members.where((m) => m.userId == userId);
          final totalShares = members.fold<int>(0, (s, m) => s + m.numberOfShares);
          int myShares = 0;
          if (myMembership.isNotEmpty) {
            myShares = myMembership.first.numberOfShares;
            profitPct = myMembership.first.sharePercentage(totalShares);
          }
          final groupRevenues = await _groupDao.getRevenuesForGroup(groupId);
          double groupTotalRevenue = 0;
          for (final r in groupRevenues) {
            groupTotalRevenue += (r['revenue'] as num? ?? 0).toDouble();
          }
          final myEarnings = totalShares > 0
              ? groupTotalRevenue * myShares / totalShares
              : 0.0;
          // ── حركات نقدية للمجموعة (أقساط محصّلة + مصروفات) ─────────────────
          final cashFlowSummary = await _groupDao.getCashFlowSummary(groupId);
          final totalCashIn = cashFlowSummary['in'] ?? 0.0;
          final totalCashOut = cashFlowSummary['out'] ?? 0.0;
          final totalMemberCapital =
              members.fold(0.0, (s, m) => s + m.capitalAmount);
          final capitalRemaining = group.startingBalance +
              totalMemberCapital +
              totalCashIn -
              totalCashOut;
          final myCollectedShare =
              totalShares > 0 ? totalCashIn * myShares / totalShares : 0.0;
          groups.add({
            'group': group,
            'members': members,
            'total_revenue': groupTotalRevenue,
            'profit_percentage': profitPct,
            'my_shares': myShares,
            'total_shares': totalShares,
            'my_earnings': myEarnings,
            'cash_flow_in': totalCashIn,
            'cash_flow_out': totalCashOut,
            'capital_remaining': capitalRemaining,
            'my_collected_share': myCollectedShare,
          });
        }
      } catch (_) {
        // Keep groups empty — will show "لم يتم تعيينك لأي مجموعة"
      }

      // ── 2. Load revenues (independent — failure must not affect groups) ──────
      try {
        revenues = await _groupDao.getRevenuesForUser(userId);
      } catch (_) {
        revenues = [];
      }
    }

    // ── 3. Load products from the installment catalog ──────────────────────────
    try {
      allProducts = await _installmentProductDao.getAll(availableOnly: true);
    } catch (_) {}

    // ── 4. Load product assignments for every group the partner belongs to ─────
    List<Map<String, dynamic>> allCashFlows = [];
    List<Map<String, dynamic>> allInstallments = [];
    try {
      for (final g in groups) {
        final group = g['group'] as PartnerGroup;
        if (group.id != null) {
          final assignments = await _groupDao.getProductAssignments(group.id!);
          for (final a in assignments) {
            // Enrich each assignment with the group name for display
            groupProductAssignments.add({
              ...a,
              'group_name': group.name,
            });
            final name = a['item_name'] as String?;
            if (name != null) assignedNames.add(name);
          }
          // ── 5. Load cash flows for this group ───────────────────────────────
          final flows = await _groupDao.getCashFlowsForGroup(group.id!);
          for (final f in flows) {
            allCashFlows.add({...f, 'group_name': group.name});
          }
          // ── 6. Load installments for this group ─────────────────────────────
          try {
            final installments = await _groupDao.getInstallmentsForGroup(group.id!);
            for (final inst in installments) {
              allInstallments.add({...inst, 'group_name': group.name});
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _myGroups = groups;
        _myRevenues = revenues;
        _myCashFlows = allCashFlows;
        _installmentProducts = allProducts;
        _assignedProductNames = assignedNames;
        _groupProductAssignments = groupProductAssignments;
        _myInstallments = allInstallments;
        _myProfitPercentage = profitPct;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.currentUser?.name ?? '';
    final initials = name.isNotEmpty ? name.trim()[0] : 'ش';
    final groupCount = _myGroups.length;
    final activeInstallments = _myInstallments.where((i) => (i['status'] as String? ?? 'active') == 'active').length;
    final completedInstallments = _myInstallments.length - activeInstallments;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF4527A0),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _load,
                tooltip: 'تحديث',
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'تسجيل الخروج',
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF311B92), Color(0xFF6200EE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: Text(initials,
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              const Text('مرحباً،', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              Text(name.isNotEmpty ? name : 'شريك',
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.verified_user, color: Colors.amber, size: 13),
                                  SizedBox(width: 4),
                                  Text('شريك معتمد', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ]),
                              ),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 18),
                        Wrap(spacing: 10, runSpacing: 8, children: [
                          SizedBox(width: 150, child: _HeaderBadge(label: 'مجموعاتك', value: '$groupCount', color: Colors.purple)),
                          SizedBox(width: 150, child: _HeaderBadge(label: 'أقساط نشطة', value: '$activeInstallments', color: Colors.green)),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.amber,
                indicatorWeight: 3,
                isScrollable: true,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: [
                  const Tab(icon: Icon(Icons.group_outlined, size: 18), text: 'مجموعاتي'),
                  const Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'أرباحي'),
                  const Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'المنتجات'),
                  const Tab(icon: Icon(Icons.credit_card_outlined, size: 18), text: 'أقساطي'),
                  const Tab(icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'المحادثات'),
                  Tab(
                    icon: Consumer<NotificationProvider>(
                      builder: (_, np, __) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_outlined, size: 18),
                          if (np.unreadCount > 0)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                child: Text('${np.unreadCount}',
                                    style: const TextStyle(color: Colors.white, fontSize: 8),
                                    textAlign: TextAlign.center),
                              ),
                            ),
                        ],
                      ),
                    ),
                    text: 'الإشعارات',
                  ),
                ],
              ),
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6200EE)))
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _GroupsTab(groups: _myGroups, monthNames: _monthNames, cashFlows: _myCashFlows),
                  _ProfitsTab(revenues: _myRevenues, monthNames: _monthNames, myProfitPercentage: _myProfitPercentage, myGroups: _myGroups),
                  _ProductsTab(products: _installmentProducts, profitPercentage: _myProfitPercentage, myGroups: _myGroups, assignedProductNames: _assignedProductNames, groupProductAssignments: _groupProductAssignments),
                  _InstallmentsTab(
                    installments: _myInstallments,
                    partnerId: _cachedUserId ?? auth.currentUser?.id ?? 0,
                    myGroups: _myGroups,
                  ),
                  _PartnerChatTab(userId: auth.currentUser?.id ?? _cachedUserId ?? 0, userName: auth.currentUser?.name ?? ''),
                  const _PartnerNotifTab(),
                ],
              ),
      ),
    );
  }
}

// ─── Groups Tab ───────────────────────────────────────────────────────────────

class _GroupsTab extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final List<String> monthNames;
  final List<Map<String, dynamic>> cashFlows;
  const _GroupsTab({required this.groups, required this.monthNames, required this.cashFlows});

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.group_outlined, size: 64, color: Colors.purple),
        ),
        const SizedBox(height: 16),
        const Text('لم يتم تعيينك لأي مجموعة بعد',
            style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('تواصل مع مدير النظام لإضافتك لمجموعة',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      ]));
    }

    double totalMyEarnings = 0;
    for (final g in groups) {
      totalMyEarnings += (g['my_earnings'] as num? ?? 0).toDouble();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      children: [
        // ── Summary banner ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6200EE), Color(0xFF9C27B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: const Color(0xFF6200EE).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(children: [
            Expanded(child: _GradientStat(
              label: 'مجموعاتي',
              value: '${groups.length}',
              icon: Icons.group_rounded,
            )),
            Container(width: 1, height: 50, color: Colors.white24),
            Expanded(child: _GradientStat(
              label: 'إجمالي أرباحي',
              value: AppFormatters.formatCurrency(totalMyEarnings),
              icon: Icons.account_balance_wallet_rounded,
            )),
          ]),
        ),
        const SizedBox(height: 12),
        // ── زر الحركات المالية ────────────────────────────────────────────────
        if (groups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton.icon(
              onPressed: () {
                final groupIds = groups
                    .map((g) => (g['group'] as PartnerGroup).id)
                    .whereType<int>()
                    .toList();
                final groupNames = groups
                    .map((g) => (g['group'] as PartnerGroup).name)
                    .toList();
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FinancialMovementsScreen(
                    groupIds: groupIds,
                    groupNames: groupNames,
                  ),
                ));
              },
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('عرض الحركات المالية'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade50,
                foregroundColor: Colors.indigo,
                elevation: 0,
                side: const BorderSide(color: Colors.indigo, width: 1.2),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ...groups.map((data) {
          final group = data['group'] as PartnerGroup;
          final members = data['members'] as List<PartnerGroupMember>;
          final totalRevenue = (data['total_revenue'] as num? ?? 0).toDouble();
          final myShares = (data['my_shares'] as num? ?? 0).toInt();
          final totalShares = (data['total_shares'] as num? ?? 0).toInt();
          final myEarnings = (data['my_earnings'] as num? ?? 0).toDouble();
          final totalCashIn = (data['cash_flow_in'] as num? ?? 0).toDouble();
          final capitalRemaining = (data['capital_remaining'] as num? ?? 0).toDouble();
          final myCollectedShare = (data['my_collected_share'] as num? ?? 0).toDouble();

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            shadowColor: Colors.purple.withValues(alpha: 0.15),
            child: ExpansionTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6200EE), Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group_rounded, color: Colors.white, size: 22),
              ),
              title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Row(children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${members.length} عضو', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
                const SizedBox(width: 6),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text('أسهمك: $myShares / $totalShares',
                      style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    // ── نسبة رسوم الإدارة (إذا كانت مخصصة للمجموعة) ──────────
                    if (group.managementFeeRate != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(children: [
                          const Icon(Icons.percent, color: Colors.orange, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'نسبة رسوم إدارة هذه المجموعة: ${group.managementFeeRate!.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ]),
                      ),
                    // ── رأس المال per member ──────────────────────────────
                    if (members.any((m) => m.capitalAmount > 0)) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.people, color: Colors.blue, size: 14),
                              SizedBox(width: 4),
                              Text('مساهمات الأعضاء (قيمة السهم):',
                                  style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 6),
                            ...members.where((m) => m.capitalAmount > 0).map((m) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(m.customerName ?? 'شريك ${m.userId}',
                                      style: const TextStyle(fontSize: 12)),
                                  Text(AppFormatters.formatCurrency(m.capitalAmount),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                            )),
                            const Divider(height: 8),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('الإجمالي:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(
                                AppFormatters.formatCurrency(members.fold(0.0, (s, m) => s + m.capitalAmount)),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ] else if (group.startingBalance > 0)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(children: [
                          const Icon(Icons.account_balance_wallet_outlined, color: Colors.teal, size: 16),
                          const SizedBox(width: 6),
                          const Text('رصيد البداية: ', style: TextStyle(fontSize: 12, color: Colors.teal)),
                          Text(AppFormatters.formatCurrency(group.startingBalance),
                              style: const TextStyle(fontSize: 13, color: Colors.teal, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    Row(children: [
                      Expanded(child: _StatCard(
                          label: 'إجمالي الإيرادات',
                          value: AppFormatters.formatCurrency(totalRevenue),
                          color: Colors.green, icon: Icons.attach_money)),
                      const SizedBox(width: 8),
                      Expanded(child: _StatCard(
                          label: 'حصتي (إيرادات)',
                          value: AppFormatters.formatCurrency(myEarnings),
                          color: Colors.purple, icon: Icons.account_balance_wallet)),
                    ]),
                    // ── أقساط محصّلة تلقائياً ─────────────────────────────
                    if (totalCashIn > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Row(children: [
                            Icon(Icons.payment, color: Colors.green, size: 14),
                            SizedBox(width: 4),
                            Text('أقساط محصّلة للمجموعة:',
                                style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 6),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('إجمالي المحصّل:', style: TextStyle(fontSize: 12)),
                            Text(AppFormatters.formatCurrency(totalCashIn),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                          ]),
                          if (myCollectedShare > 0) ...[
                            const Divider(height: 10),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('حصتك من المحصّل:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(AppFormatters.formatCurrency(myCollectedShare),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                            ]),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(children: [
                          const Icon(Icons.account_balance, color: Colors.teal, size: 16),
                          const SizedBox(width: 6),
                          const Text('رصيد المجموعة المتبقي: ', style: TextStyle(fontSize: 12, color: Colors.teal)),
                          Text(AppFormatters.formatCurrency(capitalRemaining),
                              style: const TextStyle(fontSize: 13, color: Colors.teal, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ],
                  ]),
                ),
                if (group.description != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(group.description!, style: const TextStyle(color: Colors.grey)),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Profits Tab ──────────────────────────────────────────────────────────────

class _ProfitsTab extends StatefulWidget {
  final List<Map<String, dynamic>> revenues;
  final List<String> monthNames;
  /// نسبة الشريك المحسوبة من الأسهم (myShares / totalShares * 100)
  final double myProfitPercentage;
  /// بيانات المجموعات (تحتوي my_collected_share للأرباح الفعلية من الأقساط)
  final List<Map<String, dynamic>> myGroups;
  const _ProfitsTab({required this.revenues, required this.monthNames, required this.myProfitPercentage, this.myGroups = const []});

  @override
  State<_ProfitsTab> createState() => _ProfitsTabState();
}

class _ProfitsTabState extends State<_ProfitsTab> {
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.revenues.where((r) => (r['year'] as int? ?? 0) == _selectedYear).toList();
    final sharePct = widget.myProfitPercentage; // e.g. 33.33 for 1/3 shares

    // Group by product name
    final Map<String, List<Map<String, dynamic>>> byProduct = {};
    for (final r in filtered) {
      final name = r['item_name'] as String;
      byProduct.putIfAbsent(name, () => []).add(r);
    }

    // Annual totals — use shares-based percentage from revenue records
    double annualRevenue = 0;
    double annualMyEarnings = 0;
    for (final r in filtered) {
      final rev = (r['revenue'] as num? ?? 0).toDouble();
      annualRevenue += rev;
      annualMyEarnings += rev * sharePct / 100;
    }

    // Fallback: if no revenue records entered by admin, compute from cash flows
    final double totalCollectedShare = widget.myGroups.fold(0.0,
        (s, g) => s + (g['my_collected_share'] as num? ?? 0).toDouble());
    final double totalGroupCashIn = widget.myGroups.fold(0.0,
        (s, g) => s + (g['cash_flow_in'] as num? ?? 0).toDouble());
    final bool usesCashFlowFallback = filtered.isEmpty && totalCollectedShare > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      children: [
        // ── Year selector pill ──────────────────────────────────────────────
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6200EE)),
                onPressed: () => setState(() => _selectedYear--),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6200EE), Color(0xFF9C27B0)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_selectedYear',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF6200EE)),
                onPressed: () => setState(() => _selectedYear++),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // ── Cash-flow fallback banner (when no manual revenues exist) ───────
        if (usesCashFlowFallback) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'الإيرادات المفصّلة تُدخل يدوياً من قِبَل المدير.\nالأرقام أدناه مستنبطة من الأقساط المحصلة فعلياً.',
                  style: TextStyle(color: Colors.amber, fontSize: 11),
                ),
              ),
            ]),
          ),
          // Show per-group collected earnings
          ...widget.myGroups.map((g) {
            final groupObj = g['group'];
            final groupName = groupObj is PartnerGroup
                ? groupObj.name
                : (g['group_name'] as String? ?? g['name'] as String? ?? '');
            final myShare = (g['my_collected_share'] as num? ?? 0).toDouble();
            final cashIn = (g['cash_flow_in'] as num? ?? 0).toDouble();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  child: const Icon(Icons.group, color: Colors.green, size: 20),
                ),
                title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('إجمالي محصل: ${AppFormatters.formatCurrency(cashIn)}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('حصتك', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(AppFormatters.formatCurrency(myShare),
                        style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
        ],

        // ── Annual summary banner ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Column(children: [
            Row(children: [
              Expanded(child: _GradientStat(
                label: usesCashFlowFallback ? 'إجمالي الأقساط المحصلة' : 'إيرادات $_selectedYear',
                value: AppFormatters.formatCurrency(usesCashFlowFallback ? totalGroupCashIn : annualRevenue),
                icon: Icons.trending_up_rounded,
              )),
              Container(width: 1, height: 50, color: Colors.white24),
              Expanded(child: _GradientStat(
                label: usesCashFlowFallback ? 'حصتي المحصلة' : 'أرباحي (بحسب الأسهم)',
                value: AppFormatters.formatCurrency(usesCashFlowFallback ? totalCollectedShare : annualMyEarnings),
                icon: Icons.account_balance_wallet_rounded,
              )),
            ]),
            if (sharePct > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'نسبتك من الأسهم: ${sharePct.toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bar_chart_rounded, size: 56, color: Colors.grey),
              SizedBox(height: 10),
              Text('لا توجد إيرادات مسجلة لهذا العام',
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('يقوم المدير بإدخال الإيرادات الشهرية',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          )
        else
          ...byProduct.entries.map((entry) {
            final productName = entry.key;
            final productRevenues = entry.value;
            double productTotal = 0;
            double productMyEarnings = 0;
            for (final r in productRevenues) {
              final rev = (r['revenue'] as num? ?? 0).toDouble();
              productTotal += rev;
              productMyEarnings += rev * sharePct / 100;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.withValues(alpha: 0.1),
                  child: const Icon(Icons.inventory_2_outlined, color: Colors.teal, size: 20),
                ),
                title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('إيرادات: ${AppFormatters.formatCurrency(productTotal)}'),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('حصتي (أسهم)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(AppFormatters.formatCurrency(productMyEarnings),
                      style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
                children: productRevenues.map((r) {
                  final month = r['month'] as int;
                  final rev = (r['revenue'] as num? ?? 0).toDouble();
                  final myShare = rev * sharePct / 100;
                  final groupName = r['group_name'] as String? ?? '';
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      child: Text('$month', style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(widget.monthNames[month - 1], style: const TextStyle(fontSize: 13)),
                    subtitle: Text('$groupName | إيراد: ${AppFormatters.formatCurrency(rev)}', style: const TextStyle(fontSize: 11)),
                    trailing: Text(AppFormatters.formatCurrency(myShare),
                        style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                  );
                }).toList(),
              ),
            );
          }),
      ],
    );
  }
}


// ─── Products Tab ─────────────────────────────────────────────────────────────

class _ProductsTab extends StatelessWidget {
  final List<InstallmentProduct> products;
  final double profitPercentage;
  final List<Map<String, dynamic>> myGroups;
  final Set<String> assignedProductNames;
  final List<Map<String, dynamic>> groupProductAssignments;

  const _ProductsTab({
    required this.products,
    required this.profitPercentage,
    this.myGroups = const [],
    this.assignedProductNames = const {},
    this.groupProductAssignments = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Prefer showing the direct group product assignments (from product_group_assignments table).
    // These are the exact products the admin assigned to the group, with their correct sale prices.
    // Fall back to filtering the installment catalog by name if no assignments exist.
    final bool hasAssignments = groupProductAssignments.isNotEmpty;

    if (!hasAssignments && assignedProductNames.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.green),
        ),
        const SizedBox(height: 16),
        const Text('لا توجد منتجات في مجموعتك',
            style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('يقوم المدير بتعيين المنتجات للمجموعة',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      ]));
    }

    return Column(
      children: [
        if (profitPercentage > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 14, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6200EE), Color(0xFF9C27B0)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'حصتك من الأسهم: ${profitPercentage.toStringAsFixed(1)}% من كل منتج',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              )),
            ]),
          ),
        Expanded(
          child: hasAssignments
              // ── Show directly-assigned group products ──────────────────────
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: groupProductAssignments.length,
                  itemBuilder: (ctx, i) {
                    final a = groupProductAssignments[i];
                    final name = a['item_name'] as String? ?? '';
                    final salePrice = (a['sale_price'] as num? ?? 0).toDouble();
                    final myEarnings = salePrice * profitPercentage / 100;
                    final groupName = a['group_name'] as String? ?? '';
                    // Look up company percentage from installment products catalog
                    final catalogProduct = products.where((p) => p.name == name).firstOrNull;
                    final companyPct = catalogProduct?.companyPercentage ?? 0;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          child: const Icon(Icons.payment, color: Colors.green),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (groupName.isNotEmpty)
                              Text('المجموعة: $groupName', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (companyPct > 0)
                              Row(children: [
                                const Icon(Icons.business_center, size: 11, color: Colors.orange),
                                const SizedBox(width: 3),
                                Text('نسبة الشركة: ${companyPct.toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                              ]),
                          ],
                        ),
                        isThreeLine: companyPct > 0 && groupName.isNotEmpty,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(AppFormatters.formatCurrency(salePrice),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                            if (profitPercentage > 0)
                              Text('حصتك: ${AppFormatters.formatCurrency(myEarnings)}',
                                  style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                )
              // ── Fallback: filter installment catalog by name ────────────────
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: products.where((p) => assignedProductNames.contains(p.name)).length,
                  itemBuilder: (ctx, i) {
                    final filtered = products.where((p) => assignedProductNames.contains(p.name)).toList();
                    final p = filtered[i];
                    final myProfit = p.profit * (profitPercentage / 100);
                    return Card(
                      child: ListTile(
                        leading: p.imagePath != null && File(p.imagePath!).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(p.imagePath!), width: 48, height: 48, fit: BoxFit.cover),
                              )
                            : CircleAvatar(
                                backgroundColor: Colors.green.withValues(alpha: 0.1),
                                child: const Icon(Icons.payment, color: Colors.green),
                              ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (p.category != null) Text(p.category!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          if (p.companyPercentage > 0)
                            Row(children: [
                              const Icon(Icons.business_center, size: 11, color: Colors.orange),
                              const SizedBox(width: 3),
                              Text('نسبة الشركة: ${p.companyPercentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                            ]),
                        ]),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(AppFormatters.formatCurrency(p.salePrice),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                          if (profitPercentage > 0)
                            Text('حصتك: ${AppFormatters.formatCurrency(myProfit)}',
                                style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Partner Chat Tab ─────────────────────────────────────────────────────────

class _PartnerChatTab extends StatelessWidget {
  final int userId;
  final String userName;
  const _PartnerChatTab({required this.userId, required this.userName});

  @override
  Widget build(BuildContext context) {
    if (userId == 0) {
      return const Center(child: Text('يجب تسجيل الدخول أولاً'));
    }
    return ChatDetailScreen(
      myId: userId,
      myName: userName,
      otherId: 1, // Admin
      otherName: 'الإدارة',
    );
  }
}

// ─── Partner Notifications Tab (uses shared NotificationHistoryScreen body) ────

class _PartnerNotifTab extends StatelessWidget {
  const _PartnerNotifTab();

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NotificationProvider>();
    final all = np.notifications;
    final unread = all.where((n) => !n.isRead).toList();
    final read = all.where((n) => n.isRead).toList();

    if (np.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 3,
      child: Column(children: [
        // Header row
        Container(
          color: const Color(AppColors.primaryInt),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(children: [
                const Icon(Icons.notifications_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text('الإشعارات',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                if (np.unreadCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    child: Text('${np.unreadCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
                const Spacer(),
                if (np.unreadCount > 0)
                  TextButton(
                    onPressed: () => np.markAllRead(),
                    child: const Text('تحديد الكل', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                  onPressed: () => np.load(),
                ),
              ]),
            ),
            const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: [
                Tab(text: 'الكل'),
                Tab(text: 'غير مقروء'),
                Tab(text: 'مقروء'),
              ],
            ),
          ]),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            children: [
              _PartnerNotifList(items: all, np: np),
              _PartnerNotifList(items: unread, np: np),
              _PartnerNotifList(items: read, np: np),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PartnerNotifList extends StatelessWidget {
  final List<AppNotification> items;
  final NotificationProvider np;
  const _PartnerNotifList({required this.items, required this.np});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('لا توجد إشعارات', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (ctx, i) {
        final n = items[i];
        final isUnread = !n.isRead;
        return InkWell(
          onTap: () {
            if (isUnread && n.id != null) np.markRead(n.id!);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isUnread
                ? const Color(AppColors.primaryInt).withValues(alpha: 0.04)
                : null,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isUnread
                      ? const Color(AppColors.primaryInt).withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconForType(n.type),
                  size: 20,
                  color: isUnread
                      ? const Color(AppColors.primaryInt)
                      : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(n.title,
                        style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14)),
                  ),
                  if (isUnread)
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(
                            color: const Color(AppColors.primaryInt),
                            shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 3),
                Text(n.body, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  n.createdAt.length >= 16
                      ? n.createdAt.substring(0, 16).replaceAll('T', ' ')
                      : n.createdAt,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ])),
            ]),
          ),
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'request': return Icons.request_page;
      case 'invoice': return Icons.description_outlined;
      case 'installment': return Icons.receipt_long;
      case 'payment': return Icons.payments_outlined;
      case 'chat': return Icons.chat_bubble_outline;
      default: return Icons.notifications_outlined;
    }
  }
}

// ─── Installments Tab ─────────────────────────────────────────────────────────

class _InstallmentsTab extends StatefulWidget {
  final List<Map<String, dynamic>> installments;
  final int partnerId;
  final List<Map<String, dynamic>> myGroups;
  const _InstallmentsTab({
    required this.installments,
    required this.partnerId,
    required this.myGroups,
  });

  @override
  State<_InstallmentsTab> createState() => _InstallmentsTabState();
}

class _InstallmentsTabState extends State<_InstallmentsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _active =>
      widget.installments.where((i) => (i['status'] as String? ?? 'active') == 'active').toList();

  List<Map<String, dynamic>> get _completed =>
      widget.installments.where((i) {
        final s = i['status'] as String? ?? 'active';
        return s == 'completed' || s == 'cancelled';
      }).toList();

  @override
  Widget build(BuildContext context) {
    if (widget.installments.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.credit_card_outlined, size: 64, color: Colors.indigo),
          ),
          const SizedBox(height: 16),
          const Text('لا توجد أقساط مرتبطة بمجموعاتك',
              style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('سيظهر هنا كل قسط يضيفه المدير لمجموعتك',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      );
    }

    // Summary totals (all)
    double totalPrice = 0;
    double totalRemaining = 0;
    for (final inst in widget.installments) {
      final price = ((inst['total_price'] ?? inst['total_installment_price']) as num? ?? 0).toDouble();
      final dp = (inst['down_payment'] as num? ?? 0).toDouble();
      final rem = (inst['remaining_amount'] as num? ?? (price - dp)).toDouble();
      totalPrice += price;
      totalRemaining += rem;
    }

    return Column(
      children: [
        // ── Summary Banner ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.indigo.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(children: [
              Expanded(child: _GradientStat(label: 'إجمالي العقود', value: '${widget.installments.length}', icon: Icons.description_rounded)),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(child: _GradientStat(label: 'نشط', value: '${_active.length}', icon: Icons.play_circle_outline_rounded)),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(child: _GradientStat(label: 'المتبقي الكلي', value: _fmt(totalRemaining), icon: Icons.account_balance_wallet_rounded)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        // ── Tab Bar ────────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.indigo,
            indicator: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(10),
            ),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'نشطة (${_active.length})'),
              Tab(text: 'منتهية (${_completed.length})'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // ── Tab Views ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildInstallmentList(_active, showClaimButton: false),
              _buildInstallmentList(_completed, showClaimButton: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstallmentList(List<Map<String, dynamic>> list, {required bool showClaimButton}) {
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(showClaimButton ? Icons.check_circle_outline : Icons.credit_card_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(showClaimButton ? 'لا توجد عقود منتهية' : 'لا توجد أقساط نشطة',
              style: const TextStyle(color: Colors.grey, fontSize: 15)),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        if (showClaimButton) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _showClaimDialog(context),
            icon: const Icon(Icons.request_page_rounded),
            label: const Text('طلب استلام المستحقات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 12),
        ],
        ...list.map((inst) => _buildInstallmentCard(inst)),
      ],
    );
  }

  Widget _buildInstallmentCard(Map<String, dynamic> inst) {
    final customerName = _extractCustomerName(inst);
    final productName = (inst['item_name'] ?? inst['product_name'] ?? '') as String;
    final groupName = inst['group_name'] as String? ?? '';
    final status = inst['status'] as String? ?? 'active';
    final monthly = (inst['monthly_amount'] as num? ?? 0).toDouble();
    final numInst = inst['num_installments'] as int? ?? 0;
    final startDate = inst['start_date'] as String? ?? '';
    final price = ((inst['total_price'] ?? inst['total_installment_price']) as num? ?? 0).toDouble();
    final dp = (inst['down_payment'] as num? ?? 0).toDouble();
    final remaining = (inst['remaining_amount'] as num? ?? (price - dp)).toDouble();

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'مكتمل';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusLabel = 'ملغي';
        break;
      default:
        statusColor = Colors.indigo;
        statusLabel = 'نشط';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: statusColor.withValues(alpha: 0.1),
              child: Icon(Icons.person, color: statusColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(productName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          if (groupName.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.group, color: Colors.purple, size: 12),
                const SizedBox(width: 4),
                Text(groupName, style: const TextStyle(color: Colors.purple, fontSize: 11)),
              ]),
            ),
          const Divider(height: 8),
          Row(children: [
            Expanded(child: _MiniInfo(label: 'الإجمالي', value: _fmt(price))),
            Expanded(child: _MiniInfo(label: 'المتبقي', value: _fmt(remaining), color: remaining > 0 ? Colors.red : Colors.green)),
            Expanded(child: _MiniInfo(label: 'القسط الشهري', value: _fmt(monthly))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _MiniInfo(label: 'عدد الأقساط', value: '$numInst شهر')),
            Expanded(child: _MiniInfo(label: 'تاريخ البدء', value: startDate.length >= 10 ? startDate.substring(0, 10) : startDate)),
            const Expanded(child: SizedBox()),
          ]),
        ]),
      ),
    );
  }

  void _showClaimDialog(BuildContext context) {
    final notesCtrl = TextEditingController();
    bool sending = false;

    // Calculate total remaining across all completed installments
    double totalClaimable = 0;
    for (final inst in _completed) {
      final price = ((inst['total_price'] ?? inst['total_installment_price']) as num? ?? 0).toDouble();
      final dp = (inst['down_payment'] as num? ?? 0).toDouble();
      final remaining = (inst['remaining_amount'] as num? ?? (price - dp)).toDouble();
      totalClaimable += (price - remaining); // collected portion
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.request_page_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('طلب استلام المستحقات'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.info_outline, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'طلب استلام مستحقات عن ${_completed.length} عقد مكتمل',
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  'إجمالي المستحقات: ${_fmt(totalClaimable)}',
                  style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                prefixIcon: Icon(Icons.note_alt_outlined),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ]),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: sending ? null : () async {
                setS(() => sending = true);
                try {
                  final supabase = Supabase.instance.client;
                  final now = DateTime.now().toIso8601String();
                  // Get first group id if available
                  final groupId = widget.myGroups.isNotEmpty
                      ? (widget.myGroups.first['group'] as dynamic)?.id
                      : null;

                  // Insert one request per completed installment
                  for (final inst in _completed) {
                    final instId = inst['id'] as int?;
                    final price = ((inst['total_price'] ?? inst['total_installment_price']) as num? ?? 0).toDouble();
                    final dp = (inst['down_payment'] as num? ?? 0).toDouble();
                    final remaining = (inst['remaining_amount'] as num? ?? (price - dp)).toDouble();
                    final collected = price - remaining;
                    final instGroupId = inst['partner_group_id'] as int? ?? groupId;

                    await supabase.from('partner_payment_requests').insert({
                      'partner_id': widget.partnerId,
                      if (instGroupId != null) 'partner_group_id': instGroupId,
                      if (instId != null) 'installment_id': instId,
                      'amount': collected,
                      'status': 'pending',
                      'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      'created_at': now,
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم إرسال طلب استلام ${_completed.length} عقد إلى الإدارة ✓\nالمبلغ: ${_fmt(totalClaimable)}',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  setS(() => sending = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ أثناء إرسال الطلب: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(sending ? 'جاري الإرسال...' : 'إرسال الطلب'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => '${v.toStringAsFixed(0)} ج.م';

  String _extractCustomerName(Map<String, dynamic> inst) {
    final customers = inst['customers'];
    if (customers is Map) return customers['name'] as String? ?? 'غير محدد';
    return inst['customer_name'] as String? ?? 'غير محدد';
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniInfo({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      Text(value,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.black87)),
    ]);
  }
}

// ─── Gradient Stat (white text, used inside dark gradient banners) ────────────

class _GradientStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _GradientStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white70, size: 20),
      const SizedBox(height: 6),
      Text(value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
          textAlign: TextAlign.center),
    ]);
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
        ),
      ]),
    );
  }
}

