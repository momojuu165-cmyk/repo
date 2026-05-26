import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../database/daos/customer_dao.dart';
import '../../../database/daos/department_dao.dart';
import '../../../database/daos/user_dao.dart';
import '../../../models/customer.dart';
import '../../../models/department.dart';
import '../../../models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/hash_helper.dart';
import '../../../utils/whatsapp_helper.dart';
import '../../../services/login_code_service.dart';
import '../../customer/electrical_customer_home.dart';
import '../../customer/installment_customer_home.dart';
import '../../../services/push_notification_service.dart';
import '../../../widgets/common/section_header.dart';
import '../../../widgets/common/large_stat_card.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, this.initialRole});

  final String? initialRole;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
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
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.manage_accounts), text: 'المستخدمون'),
            Tab(icon: Icon(Icons.people), text: 'العملاء'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _StaffTab(initialRole: widget.initialRole),
        const _CustomersTab(),
      ]),
    );
  }
}

// ─── Staff Tab ────────────────────────────────────────────────────────────────

class _StaffTab extends StatefulWidget {
  const _StaffTab({this.initialRole});

  final String? initialRole;

  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab> {
  final _dao = UserDao();
  final _deptDao = DepartmentDao();
  List<User> _users = [];
  List<Department> _departments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await _dao.getAll();
    final depts = await _deptDao.getAll(activeOnly: true);
    if (mounted)
      setState(() {
        _users = users;
        _departments = depts;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SectionHeader(
          title: 'إدارة المستخدمين',
          subtitle: 'أضف، عدّل أو احذف المستخدمين والعملاء',
          icon: Icons.manage_accounts,
          color: const Color(AppColors.primaryInt),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: LargeStatCard(
          title: 'أضف مدير أو شريك',
          value: 'انقر للإضافة',
          icon: Icons.person_add,
          color: const Color(AppColors.primaryInt),
          onTap: () => _showAddUserDialog(widget.initialRole),
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
                ? const Center(child: Text('لا يوجد مستخدمون بعد'))
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (ctx, i) {
                      final u = _users[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                _roleColor(u.role).withValues(alpha: 0.12),
                            child: Icon(_roleIcon(u.role),
                                color: _roleColor(u.role), size: 22),
                          ),
                          title: Text(u.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(u.username,
                                    style:
                                        TextStyle(color: Colors.grey.shade700)),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: _roleColor(u.role)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Text(_roleLabel(u.role),
                                          style: TextStyle(
                                              color: _roleColor(u.role),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600))),
                                  const SizedBox(width: 6),
                                  if (u.departmentType != null &&
                                      u.departmentType != AppConstants.deptAll)
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: Colors.purple
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Text(
                                            AppConstants.deptLabels[
                                                    u.departmentType] ??
                                                u.departmentType!,
                                            style: const TextStyle(
                                                color: Colors.purple,
                                                fontSize: 11))),
                                  if (!u.isActive) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.block,
                                        color: Colors.red, size: 14),
                                    const SizedBox(width: 4),
                                    const Text('موقوف',
                                        style: TextStyle(
                                            color: Colors.red, fontSize: 11)),
                                  ],
                                ])
                              ]),
                          isThreeLine: true,
                          trailing: PopupMenuButton(
                            itemBuilder: (ctx) {
                              final isAdmin = ctx.read<AuthProvider>().isAdmin;
                              return [
                                const PopupMenuItem(
                                    value: 'editcreds',
                                    child: Row(children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('تعديل البيانات')
                                    ])),
                                const PopupMenuItem(
                                    value: 'gencode',
                                    child: Row(children: [
                                      Icon(Icons.qr_code, size: 18),
                                      SizedBox(width: 8),
                                      Text('توليد كود دخول')
                                    ])),
                                if (isAdmin)
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete_outline,
                                            size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('حذف',
                                            style: TextStyle(color: Colors.red))
                                      ])),
                              ];
                            },
                            onSelected: (v) => _handleAction(v as String, u),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }

  void _handleAction(String action, User u) async {
    switch (action) {
      case 'delete':
        final ok = await _showConfirm('حذف ${u.name}؟');
        if (ok && u.id != null) {
          await _dao.hardDelete(u.id!);
          _load();
        }
        break;
      case 'toggle':
        if (u.id != null) {
          final updated = await _dao.setActive(u.id!, !u.isActive);
          if (!updated) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل تحديث حالة ${u.name}${_dao.lastError != null ? ': ${_dao.lastError}' : ''}'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          await _load();
        }
        break;
      case 'gencode':
        if (mounted) _showGenerateCodeDialog(u);
        break;
      case 'editcreds':
        if (mounted) _showEditCredentialsDialog(u);
        break;
    }
  }

  Future<bool> _showConfirm(String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (dlgCtx) => AlertDialog(
            title: const Text('تأكيد'),
            content: Text(msg),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dlgCtx, false),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(dlgCtx, true),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Feature 3: generate code with type selection (temporary vs permanent)
  void _showGenerateCodeDialog(User u) async {
    String codeType = u.codeType;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('كود دخول: ${u.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('نوع الكود:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _TypeOption(
                  label: 'دائم',
                  subtitle: 'لا ينتهي',
                  icon: Icons.all_inclusive,
                  color: Colors.blue,
                  selected: codeType == AppConstants.codeTypePermanent,
                  onTap: () =>
                      setS(() => codeType = AppConstants.codeTypePermanent),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TypeOption(
                  label: 'مؤقت',
                  subtitle: '${AppConstants.temporaryCodeHours} ساعة',
                  icon: Icons.timer,
                  color: Colors.orange,
                  selected: codeType == AppConstants.codeTypeTemporary,
                  onTap: () =>
                      setS(() => codeType = AppConstants.codeTypeTemporary),
                ),
              ),
            ]),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                if (u.id == null) return;
                try {
                  final svc = LoginCodeService();
                  final code = await svc.generateAndAssign(
                    u.id!,
                    temporary: codeType == AppConstants.codeTypeTemporary,
                    hours: AppConstants.temporaryCodeHours,
                  );
                  await _load();
                  if (!mounted) return;
                  _showCodeResult(
                      u,
                      code,
                      codeType,
                      codeType == AppConstants.codeTypeTemporary
                          ? DateTime.now()
                              .add(Duration(
                                  hours: AppConstants.temporaryCodeHours))
                              .toIso8601String()
                          : null);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('فشل توليد الكود: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              child: const Text('توليد كود'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCodeResult(User u, String code, String codeType, String? expiry) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text('كود دخول: ${u.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(AppColors.primaryInt).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      const Color(AppColors.primaryInt).withValues(alpha: 0.3)),
            ),
            child: Text(code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                    color: Color(AppColors.primaryInt))),
          ),
          const SizedBox(height: 12),
          if (codeType == AppConstants.codeTypeTemporary && expiry != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(children: [
                const Icon(Icons.timer, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text('ينتهي في ${AppConstants.temporaryCodeHours} ساعة',
                    style: const TextStyle(color: Colors.orange, fontSize: 12)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.all_inclusive, color: Colors.blue, size: 16),
                SizedBox(width: 6),
                Text('كود دائم لا ينتهي',
                    style: TextStyle(color: Colors.blue, fontSize: 12)),
              ]),
            ),
          const SizedBox(height: 8),
          const Text('أرسل هذا الكود للمستخدم عبر واتساب',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('إغلاق')),
          if (u.phone != null && u.phone!.isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(dlgCtx);
                WhatsAppHelper.sendLoginCode(
                    phone: u.phone!, name: u.name, code: code, role: u.role);
              },
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('إرسال عبر واتساب'),
            ),
        ],
      ),
    );
  }

  Future<String> _generateUniqueCode(User u) async {
    String code;
    int attempts = 0;
    do {
      code = _generateCode(u);
      final exists = await _dao.loginCodeExists(code);
      if (!exists) {
        return code;
      }
      attempts++;
    } while (attempts < 10);

    final random = Random();
    do {
      code = random.nextInt(1000000).toString().padLeft(6, '0');
    } while (await _dao.loginCodeExists(code));
    return code;
  }

  String _generateCode(User u) {
    final ts = DateTime.now().millisecondsSinceEpoch % 1000000;
    final seed = ((u.id ?? 1) * 7919 + ts) % 1000000;
    return seed.toString().padLeft(6, '0');
  }

  // Feature 1: pick contact to prefill name + phone
  Future<Map<String, String>?> _pickContact() async {
    try {
      // Request contacts permission before opening the picker
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'يرجى السماح بالوصول لجهات الاتصال من إعدادات الهاتف')),
          );
        }
        return null;
      }
      // Use in-app contacts list to avoid crash from native picker
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      if (!mounted) return null;
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => _ContactPickerDialog(contacts: contacts),
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  void _showEditCredentialsDialog(User u) {
    final nameCtrl = TextEditingController(text: u.name);
    final phoneCtrl = TextEditingController(text: u.phone ?? '');
    String? selectedDeptType = u.departmentType ?? AppConstants.deptAll;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('تعديل: ${u.name}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Feature 1: Import from contacts button
              OutlinedButton.icon(
                onPressed: () async {
                  final contact = await _pickContact();
                  if (contact != null) {
                    if (contact['name'] != null) {
                      nameCtrl.text = contact['name']!;
                    }
                    if (contact['phone'] != null) {
                      phoneCtrl.text = contact['phone']!;
                    }
                  }
                },
                icon: const Icon(Icons.contacts, size: 18),
                label: const Text('استيراد من جهات الاتصال'),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'الاسم', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              if (u.role == AppConstants.roleManager) ...[
                const Text('القسم المسؤول عنه:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedDeptType,
                  decoration: const InputDecoration(
                      labelText: 'القسم', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String>(
                        value: AppConstants.deptAll,
                        child: Text('جميع الأقسام')),
                    ..._departments.map((d) => DropdownMenuItem<String>(
                        value: d.storeType, child: Text(d.name))),
                  ],
                  onChanged: (v) => setS(() => selectedDeptType = v),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _dao.update(u.copyWith(
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    departmentType: u.role == AppConstants.roleManager
                        ? selectedDeptType
                        : u.departmentType,
                  ));
                  Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('خطأ: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog([String? initialRole]) {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = initialRole ?? AppConstants.roleManager;
    String deptType = AppConstants.deptAll;
    String codeType = AppConstants.codeTypePermanent;
    bool saving = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('إضافة مستخدم جديد'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Feature 1: Import from contacts
              OutlinedButton.icon(
                onPressed: () async {
                  final contact = await _pickContact();
                  if (contact != null) {
                    setS(() {
                      if (contact['name'] != null) {
                        nameCtrl.text = contact['name']!;
                        usernameCtrl.text =
                            contact['name']!.replaceAll(' ', '_').toLowerCase();
                      }
                      if (contact['phone'] != null) {
                        phoneCtrl.text = contact['phone']!;
                      }
                    });
                  }
                },
                icon: const Icon(Icons.contacts, size: 18),
                label: const Text('استيراد من جهات الاتصال'),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'الاسم الكامل *',
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اسم المستخدم *',
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              if (role != AppConstants.roleManager &&
                  role != AppConstants.rolePartner) ...[
                TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'كلمة المرور *',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
              ],
              TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(
                    labelText: 'الدور *', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: AppConstants.roleAdmin, child: Text('مشرف')),
                  DropdownMenuItem(
                      value: AppConstants.roleManager, child: Text('مدير')),
                  DropdownMenuItem(
                      value: AppConstants.rolePartner, child: Text('شريك')),
                ],
                onChanged: (v) => setS(() => role = v!),
              ),
              const SizedBox(height: 12),
              if (role == AppConstants.roleManager) ...[
                DropdownButtonFormField<String>(
                  value: deptType,
                  decoration: const InputDecoration(
                      labelText: 'القسم المسؤول عنه',
                      border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String>(
                        value: AppConstants.deptAll,
                        child: Text('جميع الأقسام')),
                    ..._departments.map((d) => DropdownMenuItem<String>(
                        value: d.storeType, child: Text(d.name))),
                  ],
                  onChanged: (v) => setS(() => deptType = v!),
                ),
                const SizedBox(height: 12),
              ],
              // Feature 3: code type selection
              const Text('نوع كود الدخول:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _TypeOption(
                    label: 'دائم',
                    subtitle: 'لا ينتهي',
                    icon: Icons.all_inclusive,
                    color: Colors.blue,
                    selected: codeType == AppConstants.codeTypePermanent,
                    onTap: () =>
                        setS(() => codeType = AppConstants.codeTypePermanent),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeOption(
                    label: 'مؤقت',
                    subtitle: '${AppConstants.temporaryCodeHours}h',
                    icon: Icons.timer,
                    color: Colors.orange,
                    selected: codeType == AppConstants.codeTypeTemporary,
                    onTap: () =>
                        setS(() => codeType = AppConstants.codeTypeTemporary),
                  ),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final needsPassword = role != AppConstants.roleManager &&
                          role != AppConstants.rolePartner;
                      if (nameCtrl.text.trim().isEmpty ||
                          usernameCtrl.text.trim().isEmpty ||
                          (needsPassword && passwordCtrl.text.trim().isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('يرجى ملء الحقول المطلوبة')));
                        return;
                      }
                      setS(() => saving = true);
                      try {
                        final rawPassword = needsPassword
                            ? passwordCtrl.text.trim()
                            : usernameCtrl.text.trim();
                        String? expiry;
                        if (codeType == AppConstants.codeTypeTemporary) {
                          expiry = DateTime.now()
                              .add(Duration(
                                  hours: AppConstants.temporaryCodeHours))
                              .toIso8601String();
                        }
                        final user = User(
                          username: usernameCtrl.text.trim(),
                          passwordHash: HashHelper.hashPassword(rawPassword),
                          role: role,
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                          departmentType: role == AppConstants.roleManager
                              ? deptType
                              : null,
                          codeType: codeType,
                          codeExpiry: expiry,
                          createdAt: DateTime.now().toIso8601String(),
                        );
                        final id = await _dao.insert(user);
                        if (id == -2) {
                          setS(() => saving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(_dao.lastError ??
                                      'اسم المستخدم موجود بالفعل'),
                                  backgroundColor: Colors.red),
                            );
                          }
                          return;
                        }
                        if (id <= 0) {
                          setS(() => saving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'فشل إضافة المستخدم: ${_dao.lastError ?? 'تحقق من البيانات أو صلاحيات Supabase.'}'),
                                  backgroundColor: Colors.red),
                            );
                          }
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('تم إضافة المستخدم بنجاح ✓'),
                                backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        setS(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('حدث خطأ أثناء الإضافة: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.blue;
      case 'partner':
        return Colors.purple;
      case 'employee':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.manage_accounts;
      case 'partner':
        return Icons.group;
      case 'employee':
        return Icons.badge;
      default:
        return Icons.person_outline;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'مدير النظام';
      case 'manager':
        return 'مدير';
      case 'partner':
        return 'شريك';
      case 'employee':
        return 'موظف';
      default:
        return 'عميل';
    }
  }
}

// ─── Customers Tab ────────────────────────────────────────────────────────────

class _CustomersTab extends StatefulWidget {
  const _CustomersTab();
  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  final _dao = CustomerDao();
  List<Customer> _customers = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final customers = await _dao.getAll(activeOnly: false);
    if (mounted)
      setState(() {
        _customers = customers;
        _loading = false;
      });
  }

  List<Customer> get _filtered {
    if (_filter == 'all') return _customers;
    return _customers.where((c) => c.storeType == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => _showAddCustomerDialog(),
            icon: const Icon(Icons.person_add),
            label: const Text('إضافة عميل جديد'),
          ),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          _FilterChip(
              'الكل', 'all', _filter, (v) => setState(() => _filter = v)),
          _FilterChip('الكهربائية', AppConstants.storeElectrical, _filter,
              (v) => setState(() => _filter = v)),
          _FilterChip('التقسيط', AppConstants.storeInstallment, _filter,
              (v) => setState(() => _filter = v)),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? const Center(child: Text('لا يوجد عملاء'))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final c = _filtered[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    _customerStatusColor(c.customerStatus)
                                        .withValues(alpha: 0.15),
                                child: Text(c.name[0],
                                    style: TextStyle(
                                        color: _customerStatusColor(
                                            c.customerStatus),
                                        fontWeight: FontWeight.bold)),
                              ),
                              if (c.isVip)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: const BoxDecoration(
                                      color: Color(AppColors.vipInt),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                        child: Text('★',
                                            style: TextStyle(fontSize: 8))),
                                  ),
                                )
                              else if (c.isBlacklisted)
                                const Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Icon(Icons.block,
                                      size: 14,
                                      color: Color(AppColors.blacklistInt)),
                                ),
                            ],
                          ),
                          title: Row(children: [
                            Text(c.name),
                            const SizedBox(width: 6),
                            if (c.isVip)
                              _StatusBadge('VIP', const Color(AppColors.vipInt),
                                  Colors.black87)
                            else if (c.isBlacklisted)
                              _StatusBadge(
                                  'محظور',
                                  const Color(AppColors.blacklistInt),
                                  Colors.white),
                            if (!c.isApproved)
                              const _StatusBadge(
                                  'غير مفعّل', Colors.orange, Colors.white),
                          ]),
                          subtitle: Text(
                            '${c.phone ?? 'لا هاتف'} | ${c.storeType == 'installment' ? 'تقسيط' : 'كهربائيات'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) => _handleCustomerAction(v, c),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'approve',
                                  child: Row(children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.green, size: 18),
                                    SizedBox(width: 8),
                                    Text('تفعيل / إلغاء تفعيل')
                                  ])),
                              if (c.loginCode != null)
                                const PopupMenuItem(
                                    value: 'copy_code',
                                    child: Row(children: [
                                      Icon(Icons.copy,
                                          color: Colors.teal, size: 18),
                                      SizedBox(width: 8),
                                      Text('نسخ الكود'),
                                    ])),
                              PopupMenuItem(
                                  value: 'vip',
                                  child: Row(children: [
                                    const Icon(Icons.star,
                                        color: Color(AppColors.vipInt),
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                        c.isVip ? 'إلغاء VIP' : 'تعيين كـ VIP'),
                                  ])),
                            ],
                          ),
                          onTap: () => _showCustomerDetail(c),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }

  void _handleCustomerAction(String action, Customer c) async {
    switch (action) {
      case 'copy_code':
        if (c.loginCode != null) {
          await Clipboard.setData(ClipboardData(text: c.loginCode!));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم نسخ كود "${c.name}": ${c.loginCode}'),
                backgroundColor: Colors.teal,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        break;
      case 'approve':
        await _dao.update(c.copyWith(isApproved: !c.isApproved));
        _load();
        break;
      case 'vip':
        final newStatus = c.isVip
            ? AppConstants.customerStatusRegular
            : AppConstants.customerStatusVip;
        final statusUpdated = await _dao.setCustomerStatus(c.id!, newStatus);
        if (!statusUpdated) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل تحديث حالة العميل'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        await _load();
        break;
      case 'blacklist':
        if (!c.isBlacklisted) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('تأكيد الحظر'),
              content: Text('هل تريد حظر العميل "${c.name}"؟\n'
                  'لن يتمكن من الدخول إلى التطبيق.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('حظر'),
                ),
              ],
            ),
          );
          if (ok != true) return;
        }
        final newStatus = c.isBlacklisted
            ? AppConstants.customerStatusRegular
            : AppConstants.customerStatusBlacklist;
        final statusUpdated = await _dao.setCustomerStatus(c.id!, newStatus);
        if (!statusUpdated) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل تحديث حالة العميل'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        await _load();
        break;
    }
  }

  void _showCustomerDetail(Customer c) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(c.name),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.phone != null) _DetailRow(Icons.phone, 'الهاتف', c.phone!),
              if (c.loginCode != null)
                _DetailRow(Icons.vpn_key, 'كود الدخول', c.loginCode!),
              _DetailRow(Icons.store, 'المتجر',
                  c.storeType == 'installment' ? 'التقسيط' : 'الكهربائيات'),
              _DetailRow(
                  Icons.circle,
                  'الحالة',
                  c.isBlacklisted
                      ? 'محظور'
                      : c.isVip
                          ? 'VIP'
                          : 'عادي'),
              _DetailRow(Icons.check, 'مفعّل', c.isApproved ? 'نعم' : 'لا'),
              if (c.balance != 0)
                _DetailRow(Icons.account_balance_wallet, 'الرصيد',
                    AppFormatters.formatCurrency(c.balance)),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إغلاق')),
        ],
      ),
    );
  }

  // Feature 1: contact picker for customers too
  Future<Map<String, String>?> _pickContact() async {
    try {
      // Request contacts permission before opening the picker
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'يرجى السماح بالوصول لجهات الاتصال من إعدادات الهاتف')),
          );
        }
        return null;
      }
      // Use in-app contacts list to avoid crash from native picker
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      if (!mounted) return null;
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => _ContactPickerDialog(contacts: contacts),
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String storeType = AppConstants.storeElectrical;
    String priceTier = AppConstants.priceRetail;
    String customerType = AppConstants.customerTypeRegular;
    bool saving = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('إضافة عميل جديد'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Feature 1: import from contacts
              OutlinedButton.icon(
                onPressed: () async {
                  final contact = await _pickContact();
                  if (contact != null) {
                    setS(() {
                      if (contact['name'] != null) {
                        nameCtrl.text = contact['name']!;
                      }
                      if (contact['phone'] != null) {
                        phoneCtrl.text = contact['phone']!;
                      }
                    });
                  }
                },
                icon: const Icon(Icons.contacts, size: 18),
                label: const Text('استيراد من جهات الاتصال'),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'الاسم *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: storeType,
                decoration: const InputDecoration(
                    labelText: 'نوع المتجر', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'electrical', child: Text('🔌 كهربائيات')),
                  DropdownMenuItem(
                      value: 'installment', child: Text('💳 تقسيط')),
                ],
                onChanged: (v) => setS(() => storeType = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: customerType,
                decoration: const InputDecoration(
                    labelText: 'نوع العميل', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'regular', child: Text('عادي')),
                  DropdownMenuItem(value: 'technician', child: Text('🔧 فني')),
                ],
                onChanged: (v) => setS(() => customerType = v ?? 'regular'),
              ),
              if (storeType == AppConstants.storeElectrical) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: priceTier,
                  decoration: const InputDecoration(
                      labelText: 'شريحة السعر',
                      border: OutlineInputBorder(),
                      helperText: 'يرى العميل المنتجات المخصصة لشريحته فقط'),
                  items: const [
                    DropdownMenuItem(value: 'wholesale', child: Text('جملة')),
                    DropdownMenuItem(
                        value: 'semi_wholesale', child: Text('نص جملة')),
                    DropdownMenuItem(value: 'retail', child: Text('قطاعي')),
                  ],
                  onChanged: (v) => setS(() => priceTier = v ?? 'retail'),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setS(() => saving = true);
                      try {
                        final now = DateTime.now().toIso8601String();
                        final code = AppFormatters.generateAccessCode();
                        final customer = Customer(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                          storeType: storeType,
                          priceType: storeType == AppConstants.storeElectrical
                              ? priceTier
                              : AppConstants.priceRetail,
                          customerType: customerType,
                          loginCode: code,
                          isApproved: true,
                          createdAt: now,
                        );
                        await _dao.insert(customer);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'تم إضافة العميل ✓ | كود الدخول: $code'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 5)),
                          );
                        }
                      } catch (e) {
                        setS(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Color _customerStatusColor(String status) {
    switch (status) {
      case 'vip':
        return const Color(AppColors.vipInt);
      case 'blacklist':
        return const Color(AppColors.blacklistInt);
      default:
        return const Color(AppColors.primaryInt);
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(AppColors.primaryInt)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onChanged;

  const _FilterChip(this.label, this.value, this.current, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onChanged(value),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _StatusBadge(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style:
              TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Feature 3: Code type option tile ─────────────────────────────────────────

class _TypeOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? color : Colors.grey, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? color : Colors.grey,
                  fontSize: 13)),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 10,
                  color:
                      selected ? color.withValues(alpha: 0.7) : Colors.grey)),
        ]),
      ),
    );
  }
}

// ─── Feature 3: Code type badge ───────────────────────────────────────────────

class _CodeTypeBadge extends StatelessWidget {
  final bool isTemporary;
  final bool isExpired;
  const _CodeTypeBadge({required this.isTemporary, this.isExpired = false});

  @override
  Widget build(BuildContext context) {
    if (!isTemporary) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
            color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
        child: const Text('دائم',
            style: TextStyle(fontSize: 9, color: Colors.blue)),
      );
    }
    final color = isExpired ? Colors.red : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isExpired ? Icons.timer_off : Icons.timer, size: 10, color: color),
        const SizedBox(width: 2),
        Text(isExpired ? 'منتهي' : 'مؤقت',
            style: TextStyle(fontSize: 9, color: color)),
      ]),
    );
  }
}

// ─── Feature 1: Contact picker dialog ────────────────────────────────────────

class _ContactPickerDialog extends StatefulWidget {
  final List<Contact> contacts;
  const _ContactPickerDialog({required this.contacts});

  @override
  State<_ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<_ContactPickerDialog> {
  String _query = '';

  List<Contact> get _filtered {
    if (_query.isEmpty) return widget.contacts;
    return widget.contacts
        .where((c) =>
            c.displayName.toLowerCase().contains(_query.toLowerCase()) ||
            c.phones.any((p) => p.number.contains(_query)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختر جهة اتصال'),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('لا توجد نتائج'))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final c = _filtered[i];
                      final phone =
                          c.phones.isNotEmpty ? c.phones.first.number : null;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(AppColors.primaryInt)
                              .withValues(alpha: 0.1),
                          child: Text(
                              c.displayName.isNotEmpty ? c.displayName[0] : '?',
                              style: const TextStyle(
                                  color: Color(AppColors.primaryInt),
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(c.displayName),
                        subtitle: phone != null ? Text(phone) : null,
                        onTap: () => Navigator.pop(context, {
                          'name': c.displayName,
                          if (phone != null) 'phone': phone,
                        }),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
      ],
    );
  }
}
