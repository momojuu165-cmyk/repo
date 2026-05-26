import 'package:flutter/material.dart';
import '../../../providers/partner_provider.dart';
import '../../../models/partner.dart';
import '../../../models/user.dart';
import '../../../database/daos/user_dao.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/whatsapp_helper.dart';
import 'package:provider/provider.dart';

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});
  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartnerProvider>().loadAll();
    });
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الشركاء'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.manage_accounts), text: 'حسابات الشركاء'),
            Tab(icon: Icon(Icons.group), text: 'المجموعات'),
            Tab(icon: Icon(Icons.bar_chart), text: 'الأرباح'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _PartnerUsersList(),
          _GroupsRedirectWidget(),
          _ProfitsTab(),
        ],
      ),
    );
  }
}

/// Shows users with role='partner' from the users table
class _PartnerUsersList extends StatefulWidget {
  const _PartnerUsersList();
  @override
  State<_PartnerUsersList> createState() => _PartnerUsersListState();
}

class _PartnerUsersListState extends State<_PartnerUsersList> {
  List<User> _partners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {

    final users = await UserDao().getByRole(AppConstants.rolePartner);
    if (mounted) setState(() { _partners = users; _loading = false; });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_partners.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.people_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('لا يوجد شركاء بعد', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('أضف مستخدماً بدور "شريك" من الإعدادات > المستخدمون',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryInt),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pushNamed(
                    context, '/users',
                    arguments: AppConstants.rolePartner)
                .then((_) => _load()),
            icon: const Icon(Icons.person_add),
            label: const Text('إدارة المستخدمين'),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _partners.length,
        itemBuilder: (ctx, i) {
          final p = _partners[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple.withValues(alpha: 0.1),
                child: const Icon(Icons.handshake, color: Colors.purple),
              ),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('اسم المستخدم: ${p.username}'),
                if (p.phone != null) Text('الهاتف: ${p.phone!}'),
                if (p.loginCode != null)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'كود الدخول: ${p.loginCode}',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ]),
              isThreeLine: true,
              trailing: p.phone != null
                  ? IconButton(
                      icon: const Icon(Icons.chat, color: Colors.green),
                      onPressed: () => WhatsAppHelper.sendMessage(
                          phone: p.phone!, message: 'مرحباً ${p.name}، كود دخولك: ${p.loginCode ?? ""}'),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _GroupsRedirectWidget extends StatelessWidget {
  const _GroupsRedirectWidget();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.group_work, size: 64, color: Colors.purple),
        const SizedBox(height: 12),
        const Text('مجموعات الشركاء', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('إدارة مجموعات الشركاء وتعيين الشركاء ونسب الأرباح',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(AppColors.primaryInt), foregroundColor: Colors.white),
          onPressed: () => Navigator.pushNamed(context, '/partner-groups'),
          icon: const Icon(Icons.open_in_new),
          label: const Text('إدارة المجموعات'),
        ),
      ]),
    );
  }
}

class _ProfitsTab extends StatelessWidget {
  const _ProfitsTab();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<User>>(
      future: UserDao().getByRole(AppConstants.rolePartner),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final partners = snap.data!;
        if (partners.isEmpty) {
          return const Center(child: Text('لا يوجد شركاء', style: TextStyle(color: Colors.grey)));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: Column(children: [
                    const Text('عدد الشركاء', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text('${partners.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.purple)),
                  ])),
                  const VerticalDivider(),
                  Expanded(child: Column(children: [
                    const Text('إدارة المجموعات', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/partner-groups'),
                      icon: const Icon(Icons.group, size: 14),
                      label: const Text('المجموعات', style: TextStyle(fontSize: 12)),
                    ),
                  ])),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            ...partners.map((p) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.withValues(alpha: 0.1),
                  child: const Icon(Icons.handshake, color: Colors.purple),
                ),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(p.loginCode != null ? 'كود: ${p.loginCode}' : 'لا يوجد كود دخول'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('شريك',
                      style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            )),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/partner-groups'),
              icon: const Icon(Icons.group),
              label: const Text('عرض مجموعات الشركاء ونسب الأرباح'),
            ),
          ],
        );
      },
    );
  }
}
