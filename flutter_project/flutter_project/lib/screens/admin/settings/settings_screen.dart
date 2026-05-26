import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../../database/daos/user_dao.dart';
import '../../../models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/hash_helper.dart';
import 'supabase_diagnostic_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
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
        title: const Text('الإعدادات'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'المستخدمون'),
            Tab(text: 'النظام'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _UsersTab(),
          _SystemTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1: المستخدمون
// ═══════════════════════════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _dao = UserDao();
  List<User> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await _dao.getAll();
      if (mounted)
        setState(() {
          _users = users;
          _loading = false;
        });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryInt),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showAddUserDialog(context),
            icon: const Icon(Icons.person_add),
            label: const Text('إضافة مستخدم'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _users.length,
            itemBuilder: (ctx, i) {
              final u = _users[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _roleColor(u.role).withValues(alpha: 0.1),
                  child: Icon(
                    _roleIcon(u.role),
                    color: _roleColor(u.role),
                  ),
                ),
                title: Text(u.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${u.username} | ${_roleLabel(u.role)}'),
                    if (u.loginCode != null && u.role != AppConstants.roleAdmin)
                      Text(
                        'كود الدخول: ${u.loginCode}',
                        style:
                            const TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!u.isActive)
                      const Icon(Icons.block, color: Colors.red, size: 16),
                    if (u.role != AppConstants.roleAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.blue, size: 20),
                        tooltip: 'تعديل كود الدخول',
                        onPressed: () => _showEditUserCodeDialog(context, u),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await _dao.hardDelete(u.id!);
                        _load();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.blue;
      case 'partner':
        return Colors.green;
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
        return Icons.people;
      default:
        return Icons.person;
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
      default:
        return 'موظف';
    }
  }

  void _showEditUserCodeDialog(BuildContext context, User user) {
    final codeCtrl = TextEditingController(text: user.loginCode ?? '');
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            Icon(_roleIcon(user.role), color: _roleColor(user.role)),
            const SizedBox(width: 8),
            Expanded(child: Text('كود دخول: ${user.name}')),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'هذا الكود يستخدمه المستخدم لتسجيل الدخول للتطبيق',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'كود الدخول الجديد',
                prefixIcon: Icon(Icons.pin),
              ),
              textDirection: TextDirection.ltr,
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final code = codeCtrl.text.trim();
                if (code.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('الكود يجب أن يكون 4 أحرف على الأقل'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                await _dao.updateLoginCode(user.id!, code);
                _load();
                if (ctx.mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('تم تحديث كود دخول ${user.name} بنجاح: $code'),
                    backgroundColor: Colors.green,
                  ),
                );
                print(
                    'Settings: updated loginCode for user ${user.id} -> $code');
              },
              child: const Text('حفظ الكود'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = AppConstants.roleManager;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('إضافة مستخدم'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم *'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: usernameCtrl,
                decoration: const InputDecoration(labelText: 'اسم المستخدم *'),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 8),
              if (role == AppConstants.roleAdmin)
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'كلمة المرور *'),
                  obscureText: true,
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'المدير/الشريك يسجل دخوله بكود. يمكن تعديل الكود لاحقاً.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'الهاتف'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'الصلاحية'),
                items: const [
                  DropdownMenuItem(
                      value: AppConstants.roleAdmin,
                      child: Text('مدير النظام')),
                  DropdownMenuItem(
                      value: AppConstants.roleManager, child: Text('مدير')),
                  DropdownMenuItem(
                      value: AppConstants.rolePartner, child: Text('شريك')),
                ],
                onChanged: (v) => setS(() => role = v ?? role),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || usernameCtrl.text.isEmpty) return;
                if (role == AppConstants.roleAdmin && passwordCtrl.text.isEmpty)
                  return;
                final now = DateTime.now().toIso8601String();
                final password = role == AppConstants.roleAdmin
                    ? passwordCtrl.text
                    : 'code_login_${DateTime.now().millisecondsSinceEpoch}';
                final loginCode = role != AppConstants.roleAdmin
                    ? '${DateTime.now().millisecondsSinceEpoch % 100000}'
                        .padLeft(5, '0')
                    : null;
                await _dao.insert(User(
                  username: usernameCtrl.text.trim(),
                  passwordHash: HashHelper.hashPassword(password),
                  role: role,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  loginCode: loginCode,
                  createdAt: now,
                ));
                _load();
                if (context.mounted) {
                  Navigator.pop(context);
                  if (loginCode != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'تم إضافة المستخدم ✓ | كود الدخول: $loginCode'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 6),
                      ),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2: النظام
// ═══════════════════════════════════════════════════════════════════════════════

class _SystemTab extends StatelessWidget {
  const _SystemTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isCodeUser = auth.currentUser != null &&
        auth.currentUser!.role != AppConstants.roleAdmin;
    final isCustomer = auth.currentCustomer != null;
    final canChangeCode = isCodeUser || isCustomer;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: const Text('عن التطبيق'),
              subtitle: const Text('فرصتك للتقسيط v3.0'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAboutDialog(context),
            ),
            if (auth.isAdmin) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.password, color: Colors.orange),
                title: const Text('تغيير كلمة المرور'),
                subtitle: const Text('تغيير كلمة مرور حساب الأدمن'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePasswordDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.purple),
                title: const Text('تغيير اسم المستخدم'),
                subtitle: const Text('تغيير اسم دخول حساب الأدمن'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangeUsernameDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.vpn_key, color: Colors.deepPurple),
                title: const Text('أكواد الوصول المؤقتة'),
                subtitle: const Text('إنشاء أكواد دخول للزوار صالحة 24 ساعة'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTemporaryAccessCodesDialog(context),
              ),
            ],
            if (canChangeCode) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.pin, color: Colors.teal),
                title: const Text('تغيير كود الدخول'),
                subtitle: Text(
                  auth.currentLoginCode != null
                      ? 'الكود الحالي: ${auth.currentLoginCode}'
                      : 'تغيير الكود الخاص بك',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangeCodeDialog(context),
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.backup, color: Colors.green),
              title: const Text('نسخ احتياطي'),
              subtitle: const Text('البيانات محفوظة تلقائياً على السحابة'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _performBackup(context),
            ),
            if (auth.isAdmin) ...[
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.bug_report_outlined, color: Colors.indigo),
                title: const Text('تشخيص Supabase'),
                subtitle: const Text('فحص اتصال قاعدة البيانات والجداول'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SupabaseDiagnosticScreen()),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.blue.shade50,
          child: const ListTile(
            leading: Icon(Icons.info, color: Colors.blue),
            title: Text('فرصتك للتقسيط',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            subtitle: Text(
                'نظام ERP متكامل للمتاجر الكهربائية ومتاجر التقسيط\nالإصدار 3.0.0'),
          ),
        ),
      ],
    );
  }

  Future<void> _performBackup(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'بياناتك محفوظة على Supabase (السحابة) ويتم نسخها احتياطياً تلقائياً.'),
        duration: Duration(seconds: 5),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'فرصتك للتقسيط',
      applicationVersion: 'v3.0.0',
      applicationIcon:
          const Icon(Icons.store, size: 48, color: Color(AppColors.primaryInt)),
      children: const [
        Text('نظام ERP متكامل للمتاجر الكهربائية ومتاجر التقسيط'),
        SizedBox(height: 8),
        Text(
            'يشمل: المبيعات، المشتريات، الأقساط، الخزنة، التقارير، العملاء، الشركاء، الموردين'),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _loadTemporaryAccessCodes() async {
    try {
      final result = await Supabase.instance.client
          .from('temporary_access_codes')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(result as List<dynamic>);
    } catch (e, st) {
      print('Failed to load temporary access codes: $e');
      debugPrint('Failed to load temporary access codes: $e');
      debugPrintStack(stackTrace: st);
      return [];
    }
  }

  bool _isMissingActiveColumnError(Object e) {
    final message = e.toString().toLowerCase();
    return message.contains('active') &&
        (message.contains('does not exist') ||
            message.contains('not found') ||
            message.contains('could not find') ||
            message.contains('unknown column'));
  }

  Future<String?> _createTemporaryAccessCode(
      BuildContext context, String code) async {
    try {
      final auth = context.read<AuthProvider>();
      final creatorId = auth.currentUser?.id;
      if (creatorId == null) {
        return 'غير مسجل دخول. الرجاء تسجيل دخول المسؤول قبل إنشاء الكود.';
      }

      final existing = await Supabase.instance.client
          .from('temporary_access_codes')
          .select('id')
          .eq('code', code)
          .limit(1);
      if ((existing as List).isNotEmpty) {
        return 'الكود موجود بالفعل';
      }
      final payload = {
        'code': code,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'created_by': creatorId,
      };
      try {
        await Supabase.instance.client.from('temporary_access_codes').insert({
          ...payload,
          'active': true,
        });
      } catch (e, st) {
        print('Temporary code insert failed with active=true: $e');
        debugPrint('Temporary code insert failed with active=true: $e');
        debugPrintStack(stackTrace: st);
        if (_isMissingActiveColumnError(e)) {
          await Supabase.instance.client
              .from('temporary_access_codes')
              .insert(payload);
        } else {
          rethrow;
        }
      }
      return null;
    } catch (e, st) {
      print('Failed to create temporary access code: $e');
      debugPrint('Failed to create temporary access code: $e');
      debugPrintStack(stackTrace: st);
      return e.toString();
    }
  }

  void _showTemporaryAccessCodesDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    bool loading = true;
    bool creating = false;
    bool didLoad = false;
    String? errorText;
    List<Map<String, dynamic>> codes = [];

    void loadCodes(StateSetter setState) async {
      try {
        setState(() {
          loading = true;
          errorText = null;
        });
        final items = await _loadTemporaryAccessCodes();
        setState(() {
          codes = items;
          loading = false;
        });
      } catch (_) {
        setState(() {
          loading = false;
          errorText = 'فشل تحميل الأكواد';
        });
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          if (!didLoad) {
            didLoad = true;
            loadCodes(setState);
          }

          return AlertDialog(
            title: const Text('أكواد الوصول المؤقتة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    decoration: InputDecoration(
                      labelText: 'الكود',
                      hintText: 'أدخل أو أنشئ كود جديد',
                      errorText: errorText,
                      prefixIcon: const Icon(Icons.vpn_key),
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: creating
                              ? null
                              : () {
                                  final newCode =
                                      (Random().nextInt(900000) + 100000)
                                          .toString();
                                  setState(() => codeCtrl.text = newCode);
                                },
                          icon: const Icon(Icons.autorenew),
                          label: const Text('توليد كود'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: creating
                              ? null
                              : () async {
                                  final code = codeCtrl.text.trim();
                                  if (code.isEmpty) {
                                    setState(
                                        () => errorText = 'أدخل كود الوصول');
                                    return;
                                  }
                                  setState(() {
                                    creating = true;
                                    errorText = null;
                                  });
                                  final result =
                                      await _createTemporaryAccessCode(
                                          dialogContext, code);
                                  setState(() => creating = false);
                                  if (result != null) {
                                    setState(() => errorText = result);
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(dialogContext)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('خطأ: $result'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } else {
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(dialogContext)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'تم إنشاء الكود بنجاح: $code'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                    codeCtrl.clear();
                                    loadCodes(setState);
                                  }
                                },
                          icon: const Icon(Icons.save),
                          label: const Text('إنشاء'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(AppColors.primaryInt),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (loading)
                    const Center(child: CircularProgressIndicator())
                  else if (codes.isEmpty)
                    const Text('لا توجد أكواد مؤقتة حالياً.')
                  else ...[
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('الأكواد الأخيرة',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    ...codes.map((item) {
                      final created = item['created_at']?.toString() ?? '';
                      final active = item['active'] == true;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['code']?.toString() ?? ''),
                        subtitle: Text(
                          '${active ? 'نشط' : 'غير نشط'} • ${created.replaceAll('T', ' ').split('.').first}',
                        ),
                        trailing: Icon(
                          active ? Icons.check_circle : Icons.block,
                          color: active ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: creating ? null : () => Navigator.pop(dialogContext),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangeCodeDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    bool obscure = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final auth = ctx.read<AuthProvider>();
          return AlertDialog(
            title: const Row(children: [
              Icon(Icons.pin, color: Color(AppColors.primaryInt)),
              SizedBox(width: 8),
              Text('تغيير كود الدخول'),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'بعد تغيير الكود، استخدم الكود الجديد في تسجيل الدخول القادم',
                  style: TextStyle(fontSize: 12, color: Colors.teal),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: codeCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'الكود الجديد',
                  prefixIcon: const Icon(Icons.pin),
                  suffixIcon: IconButton(
                    icon:
                        Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setS(() => obscure = !obscure),
                  ),
                ),
                textDirection: TextDirection.ltr,
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final error = await auth.changeMyLoginCode(codeCtrl.text);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? 'تم تغيير كود الدخول بنجاح ✓'),
                      backgroundColor:
                          error != null ? Colors.red : Colors.green,
                    ),
                  );
                },
                child: const Text('تغيير'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.lock, color: Color(AppColors.primaryInt)),
            SizedBox(width: 8),
            Text('تغيير كلمة المرور'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: oldCtrl,
              obscureText: obscureOld,
              decoration: InputDecoration(
                labelText: 'كلمة المرور الحالية',
                suffixIcon: IconButton(
                  icon: Icon(
                      obscureOld ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setS(() => obscureOld = !obscureOld),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: newCtrl,
              obscureText: obscureNew,
              decoration: InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                suffixIcon: IconButton(
                  icon: Icon(
                      obscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setS(() => obscureNew = !obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: confirmCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('يرجى ملء جميع الحقول'),
                      backgroundColor: Colors.red));
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('كلمتا المرور غير متطابقتين'),
                      backgroundColor: Colors.red));
                  return;
                }
                if (newCtrl.text.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('كلمة المرور قصيرة جداً'),
                      backgroundColor: Colors.red));
                  return;
                }
                final auth = ctx.read<AuthProvider>();
                final error =
                    await auth.changePassword(oldCtrl.text, newCtrl.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(error ?? 'تم تغيير كلمة المرور بنجاح ✓'),
                  backgroundColor: error != null ? Colors.red : Colors.green,
                ));
              },
              child: const Text('تغيير'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeUsernameDialog(BuildContext context) {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.person, color: Color(AppColors.primaryInt)),
            SizedBox(width: 8),
            Text('تغيير اسم المستخدم'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم الجديد',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'كلمة المرور للتأكيد',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (usernameCtrl.text.trim().isEmpty ||
                    passwordCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('يرجى ملء جميع الحقول'),
                      backgroundColor: Colors.red));
                  return;
                }
                final auth = ctx.read<AuthProvider>();
                final error = await auth.changeUsername(
                  usernameCtrl.text.trim(),
                  passwordCtrl.text,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(error ?? 'تم تغيير اسم المستخدم بنجاح ✓'),
                  backgroundColor: error != null ? Colors.red : Colors.green,
                ));
              },
              child: const Text('تغيير'),
            ),
          ],
        ),
      ),
    );
  }
}
