import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/customer.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class CustomerProfileScreen extends StatefulWidget {
  final Customer? customer;

  const CustomerProfileScreen({super.key, this.customer});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showChangeCodeDialog(BuildContext context, Color color) {
    final codeCtrl = TextEditingController();
    bool obscure = false;
    final auth = context.read<AuthProvider>();
    final currentCode = auth.currentLoginCode;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.pin, color: color),
              const SizedBox(width: 8),
              const Text('تغيير كود الدخول'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentCode != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الكود الحالي: $currentCode',
                          style: TextStyle(
                              fontSize: 13,
                              color: color,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'بعد تغيير الكود، استخدم الكود الجديد في تسجيل الدخول القادم',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
              TextFormField(
                controller: codeCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'الكود الجديد (4 أحرف على الأقل)',
                  prefixIcon: const Icon(Icons.pin),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setS(() => obscure = !obscure),
                  ),
                ),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final error = await auth.changeMyLoginCode(codeCtrl.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'تم تغيير كود الدخول بنجاح ✓'),
                    backgroundColor: error != null ? Colors.red : Colors.green,
                  ),
                );
              },
              child: const Text('تغيير الكود'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer =
        context.watch<AuthProvider>().currentCustomer ?? widget.customer;
    final isElectrical =
        customer?.storeType == AppConstants.storeElectrical;
    final color = isElectrical
        ? const Color(AppColors.electricalInt)
        : const Color(AppColors.installmentInt);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile card
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Text(
                    (customer?.name.isNotEmpty == true)
                        ? customer!.name[0]
                        : '؟',
                    style: TextStyle(
                        fontSize: 36,
                        color: color,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(customer?.name ?? '',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                const SizedBox(height: 4),
                if (customer?.phone != null)
                  Text(customer!.phone!,
                      style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isElectrical ? 'متجر الكهربائيات' : 'متجر التقسيط',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),

              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Balance & points
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.account_balance_wallet,
                    color: (customer?.balance ?? 0) > 0
                        ? Colors.red
                        : Colors.green),
                title: const Text('رصيدي المدين'),
                trailing: Text(
                  AppFormatters.formatCurrency(customer?.balance ?? 0),
                  style: TextStyle(
                    color: (customer?.balance ?? 0) > 0
                        ? Colors.red
                        : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Contact info
        if (customer?.whatsapp != null ||
            customer?.email != null ||
            customer?.homeAddress != null) ...[
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                if (customer?.whatsapp != null)
                  ListTile(
                    leading: const Icon(Icons.chat, color: Colors.green),
                    title: const Text('واتساب'),
                    subtitle: Text(customer!.whatsapp!),
                  ),
                if (customer?.email != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email, color: Colors.blue),
                    title: const Text('البريد الإلكتروني'),
                    subtitle: Text(customer!.email!),
                  ),
                ],
                if (customer?.homeAddress != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.home, color: Colors.orange),
                    title: const Text('عنوان السكن'),
                    subtitle: Text(customer!.homeAddress!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Change login code
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Icon(Icons.pin, color: color),
            title: const Text('تغيير كود الدخول'),
            subtitle: customer?.loginCode != null
                ? Text('الكود الحالي: ${customer!.loginCode}',
                    style: TextStyle(color: color, fontSize: 12))
                : const Text('اضغط لتغيير الكود',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangeCodeDialog(context, color),
          ),
        ),
        const SizedBox(height: 12),
        // Logout
        Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: () async {
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
        ),
      ],
    );
  }

}
