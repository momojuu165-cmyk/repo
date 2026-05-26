import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import 'customer_register_screen.dart';
import '../guest/guest_browse_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _adminUsernameCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();
  final _managerCodeCtrl = TextEditingController();
  final _customerCodeCtrl = TextEditingController();
  final _partnerCodeCtrl = TextEditingController();

  bool _loading = false;
  bool _obscureAdmin = true;

  @override
  void initState() {
    super.initState();
    // Feature 11: default tab = customer (index 2)
    _tabCtrl = TabController(length: 4, vsync: this, initialIndex: 2);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _adminUsernameCtrl.dispose();
    _adminPasswordCtrl.dispose();
    _managerCodeCtrl.dispose();
    _customerCodeCtrl.dispose();
    _partnerCodeCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loginAdmin() async {
    if (_adminUsernameCtrl.text.trim().isEmpty || _adminPasswordCtrl.text.isEmpty) {
      _showError('ادخل اسم المستخدم وكلمة المرور');
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final error = await context.read<AuthProvider>().loginUser(
            _adminUsernameCtrl.text.trim(),
            _adminPasswordCtrl.text,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () => 'انتهت مهلة الاتصال. تحقق من الإنترنت وأعد المحاولة',
          );
      if (error != null && mounted) {
        _showError(error);
      } else if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
      }
    } catch (e) {
      if (mounted) _showError('خطأ في الاتصال. تحقق من الإنترنت وأعد المحاولة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginManager() async {
    final code = _managerCodeCtrl.text.trim();
    if (code.isEmpty) { _showError('ادخل كود الدخول'); return; }
    if (mounted) setState(() => _loading = true);
    try {
      print('LoginScreen: manager login attempt with code="$code"');
      final error = await context.read<AuthProvider>().loginWithCode(code, AppConstants.roleManager).timeout(
            const Duration(seconds: 15),
            onTimeout: () => 'انتهت مهلة الاتصال. تحقق من الإنترنت وأعد المحاولة',
          );
      if (error != null && mounted) {
        _showError(error);
      } else if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
      }
    } catch (e) {
      if (mounted) _showError('خطأ في الاتصال. تحقق من الإنترنت وأعد المحاولة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginCustomer() async {
    final code = _customerCodeCtrl.text.trim();
    if (code.isEmpty) { _showError('ادخل كود الدخول'); return; }
    if (mounted) setState(() => _loading = true);
    try {
      print('LoginScreen: customer login attempt with code="$code"');
      final error = await context.read<AuthProvider>().loginCustomer(code).timeout(
            const Duration(seconds: 15),
            onTimeout: () => 'انتهت مهلة الاتصال. تحقق من الإنترنت وأعد المحاولة',
          );
      if (error != null && mounted) {
        _showError(error);
      } else if (mounted) {
        final auth = context.read<AuthProvider>();
        final customer = auth.currentCustomer;
        final route = (customer?.storeType == AppConstants.storeInstallment)
            ? '/installment-home'
            : '/electrical-home';
        Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
      }
    } catch (e) {
      if (mounted) _showError('خطأ في الاتصال. تحقق من الإنترنت وأعد المحاولة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginPartner() async {
    final code = _partnerCodeCtrl.text.trim();
    if (code.isEmpty) { _showError('ادخل كود الدخول'); return; }
    if (mounted) setState(() => _loading = true);
    try {
      print('LoginScreen: partner login attempt with code="$code"');
      final error = await context.read<AuthProvider>().loginWithCode(code, AppConstants.rolePartner).timeout(
            const Duration(seconds: 15),
            onTimeout: () => 'انتهت مهلة الاتصال. تحقق من الإنترنت وأعد المحاولة',
          );
      if (error != null && mounted) {
        _showError(error);
      } else if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/partner-dashboard', (_) => false);
      }
    } catch (e) {
      if (mounted) _showError('خطأ في الاتصال. تحقق من الإنترنت وأعد المحاولة');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showRegisterChoice() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اختر نوع المتجر للتسجيل',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _RegisterCard(
                    icon: Icons.electrical_services,
                    label: 'متجر الأدوات الكهربائية',
                    color: const Color(AppColors.electricalInt),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerRegisterScreen(
                            storeType: AppConstants.storeElectrical,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _RegisterCard(
                    icon: Icons.payment,
                    label: 'متجر التقسيط',
                    color: const Color(AppColors.installmentInt),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerRegisterScreen(
                            storeType: AppConstants.storeInstallment,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  bool _isMissingActiveColumnError(Object e) {
    final message = e.toString().toLowerCase();
    return message.contains('active') &&
        (message.contains('does not exist') ||
            message.contains('not found') ||
            message.contains('could not find') ||
            message.contains('unknown column'));
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
          .limit(1);
      return (result as List).isNotEmpty;
    } catch (e, st) {
      print('Temporary access validation failed: $e');
      debugPrint('Temporary access validation failed: $e');
      debugPrintStack(stackTrace: st);
      if (_isMissingActiveColumnError(e)) {
        try {
          final result = await Supabase.instance.client
              .from('temporary_access_codes')
              .select()
              .eq('code', code)
              .gte('created_at', expiration.toIso8601String())
              .limit(1);
          return (result as List).isNotEmpty;
        } catch (e, st) {
          print('Fallback validation failed: $e');
          debugPrint('Fallback validation failed: $e');
          debugPrintStack(stackTrace: st);
          return false;
        }
      }
      return false;
    }
  }

  Future<void> _showTemporaryAccessCodeDialog() async {
    final codeCtrl = TextEditingController();
    var isChecking = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('كود الوصول المؤقت'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: InputDecoration(
                      hintText: 'أدخل الكود',
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      if (!isChecking) {
                        final navigator = Navigator.of(dialogContext);
                        setState(() => isChecking = true);
                        final valid = await _validateTemporaryAccessCode(codeCtrl.text.trim());
                        setState(() => isChecking = false);
                        if (valid) {
                          if (mounted) {
                            navigator.pop();
                            navigator.push(
                              MaterialPageRoute(builder: (_) => const GuestBrowseScreen()),
                            );
                          }
                        } else {
                          setState(() => errorText = 'الكود غير صحيح أو منتهي الصلاحية');
                        }
                      }
                    },
                  ),
                  if (isChecking) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isChecking ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isChecking
                      ? null
                      : () async {
                          final code = codeCtrl.text.trim();
                          if (code.isEmpty) {
                            setState(() => errorText = 'أدخل كود الوصول');
                            return;
                          }
                          final navigator = Navigator.of(dialogContext);
                          setState(() {
                            isChecking = true;
                            errorText = null;
                          });
                          final valid = await _validateTemporaryAccessCode(code);
                          setState(() => isChecking = false);
                          if (valid) {
                            if (mounted) {
                              navigator.pop();
                              navigator.push(
                                MaterialPageRoute(builder: (_) => const GuestBrowseScreen()),
                              );
                            }
                          } else {
                            setState(() => errorText = 'الكود غير صحيح أو منتهي الصلاحية');
                          }
                        },
                  child: const Text('تحقق'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Feature 10: guest browse without login
  void _guestBrowse() {
    _showTemporaryAccessCodeDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.primaryInt),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Logo + title
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
              ),
              child: const Icon(Icons.store_mall_directory_rounded,
                  color: Color(AppColors.primaryInt), size: 40),
            ),
            const SizedBox(height: 10),
            const Text(
              AppConstants.appName,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              AppConstants.appSubtitle,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            // Feature 10: guest browse button
            TextButton.icon(
              onPressed: _guestBrowse,
              icon: const Icon(Icons.explore, color: Colors.white70, size: 18),
              label: const Text(
                'تصفح المنتجات بدون تسجيل',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabCtrl,
                      labelColor: const Color(AppColors.primaryInt),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(AppColors.primaryInt),
                      isScrollable: false,
                      tabs: const [
                        Tab(icon: Icon(Icons.admin_panel_settings, size: 20), text: 'أدمن'),
                        Tab(icon: Icon(Icons.manage_accounts, size: 20), text: 'مدير'),
                        Tab(icon: Icon(Icons.person, size: 20), text: 'عميل'),
                        Tab(icon: Icon(Icons.handshake, size: 20), text: 'شريك'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _AdminLoginTab(
                            usernameCtrl: _adminUsernameCtrl,
                            passwordCtrl: _adminPasswordCtrl,
                            obscure: _obscureAdmin,
                            onToggleObscure: () =>
                                setState(() => _obscureAdmin = !_obscureAdmin),
                            loading: _loading,
                            onLogin: _loginAdmin,
                          ),
                          _CodeLoginTab(
                            codeCtrl: _managerCodeCtrl,
                            hint: 'ادخل كود المدير',
                            title: 'دخول المدير',
                            subtitle: 'احصل على كود الدخول من مدير النظام عبر واتساب',
                            icon: Icons.manage_accounts,
                            color: Colors.blue,
                            loading: _loading,
                            onLogin: _loginManager,
                          ),
                          _CodeLoginTab(
                            codeCtrl: _customerCodeCtrl,
                            hint: 'ادخل كود العميل',
                            title: 'دخول العميل',
                            subtitle: 'احصل على كود الدخول من الإدارة أو سجل حساب جديد',
                            icon: Icons.person,
                            color: Colors.green,
                            loading: _loading,
                            onLogin: _loginCustomer,
                            extraAction: Column(
                              children: [
                                TextButton.icon(
                                  onPressed: _showRegisterChoice,
                                  icon: const Icon(Icons.person_add, size: 18, color: Colors.green),
                                  label: const Text(
                                    'تسجيل حساب جديد',
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _guestBrowse,
                                  icon: const Icon(Icons.explore, size: 18, color: Colors.teal),
                                  label: const Text(
                                    'تصفح منتجات',
                                    style: TextStyle(color: Colors.teal),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _CodeLoginTab(
                            codeCtrl: _partnerCodeCtrl,
                            hint: 'ادخل كود الشريك',
                            title: 'دخول الشريك',
                            subtitle: 'احصل على كود الدخول من مدير النظام عبر واتساب',
                            icon: Icons.handshake,
                            color: Colors.purple,
                            loading: _loading,
                            onLogin: _loginPartner,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RegisterCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminLoginTab extends StatelessWidget {
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final bool loading;
  final VoidCallback onLogin;

  const _AdminLoginTab({
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.loading,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(AppColors.primaryInt), Color(AppColors.primary2Int)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text('دخول مدير النظام',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('ادخل بيانات حساب الأدمن',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          TextField(
            controller: usernameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم المستخدم',
              prefixIcon: Icon(Icons.person),
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordCtrl,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: onToggleObscure,
              ),
            ),
            textDirection: TextDirection.ltr,
            onSubmitted: (_) => onLogin(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryInt),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              elevation: 2,
            ),
            onPressed: loading ? null : onLogin,
            child: loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('دخول', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _CodeLoginTab extends StatelessWidget {
  final TextEditingController codeCtrl;
  final String hint;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onLogin;
  final Widget? extraAction;

  const _CodeLoginTab({
    required this.codeCtrl,
    required this.hint,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onLogin,
    this.extraAction,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 50, color: color),
          ),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          TextField(
            controller: codeCtrl,
            decoration: InputDecoration(
              labelText: hint,
              prefixIcon: Icon(Icons.vpn_key, color: color),

            ),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            onSubmitted: (_) => onLogin(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              elevation: 2,
            ),
            onPressed: loading ? null : onLogin,
            child: loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('دخول', style: TextStyle(fontSize: 16)),
          ),
          if (extraAction != null) ...[
            const SizedBox(height: 12),
            Center(child: extraAction!),
          ],
        ],
      ),
    );
  }
}
