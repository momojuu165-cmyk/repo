import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../database/daos/user_dao.dart';
import '../../../database/daos/customer_dao.dart';
import '../../../models/user.dart';
import '../../../models/customer.dart';
import '../../../providers/notification_provider.dart';
import '../../../utils/constants.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});
  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _userDao = UserDao();
  final _custDao = CustomerDao();

  String _targetType = 'all';
  int? _selectedUserId;
  int? _selectedCustomerId;
  List<User> _users = [];
  List<Customer> _customers = [];
  bool _loading = false;
  bool _sent = false;

  static const _targetTypes = {
    'all': 'جميع المستخدمين',
    'all_customers': 'جميع العملاء',
    'all_partners': 'جميع الشركاء',
    'specific_customer': 'عميل محدد',
    'specific_user': 'مستخدم محدد',
  };

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipients() async {
    final users = await _userDao.getAll();
    final customers = await _custDao.getAll();
    if (mounted) setState(() { _users = users; _customers = customers; });
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى ملء العنوان والمحتوى')));
      return;
    }
    setState(() { _loading = true; _sent = false; });

    final np = context.read<NotificationProvider>();
    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();
    int sentCount = 0;
    try {
    switch (_targetType) {
      case 'all':
        await np.sendToAll(title, body);
        sentCount = _users.length + _customers.length;
        break;

      case 'all_customers':
        await np.sendToRole(AppConstants.roleCustomer, title, body);
        sentCount = _customers.length;
        break;

      case 'all_partners':
        await np.sendToRole(AppConstants.rolePartner, title, body);
        sentCount = _users.where((u) => u.role == AppConstants.rolePartner).length;
        break;

      case 'specific_customer':
        if (_selectedCustomerId != null) {
          await np.sendToUser(_selectedCustomerId!, title, body);
          sentCount = 1;
        }
        break;

      case 'specific_user':
        if (_selectedUserId != null) {
          await np.sendToUser(_selectedUserId!, title, body);
          sentCount = 1;
        }
        break;
    }
    // try block opened above — close it here
    setState(() { _loading = false; _sent = true; });
    _titleCtrl.clear();
    _bodyCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال الإشعار' + (sentCount > 0 ? ' إلى $sentCount مستلم' : '')),
          backgroundColor: Colors.green,
        ),
      );
    }
    } catch (e) {
      setState(() { _loading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الإشعار: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إرسال إشعار'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ─── Target Selection ────────────────────────────────────────────
          const Text('المستلم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: _targetTypes.entries.map((e) => RadioListTile<String>(
              title: Text(e.value),
              value: e.key,
              groupValue: _targetType,
              dense: true,
              onChanged: (v) => setState(() {
                _targetType = v!;
                _selectedCustomerId = null;
                _selectedUserId = null;
              }),
              activeColor: const Color(AppColors.primaryInt),
            )).toList()),
          ),
          const SizedBox(height: 12),

          // ─── Specific Target Selector ────────────────────────────────────
          if (_targetType == 'specific_customer') ...[
            DropdownButtonFormField<int>(
              value: _selectedCustomerId,
              decoration: const InputDecoration(labelText: 'اختر العميل', border: OutlineInputBorder()),
              items: _customers.map((c) => DropdownMenuItem<int>(
                value: c.id!,
                child: Text('${c.name}  (${c.storeType == AppConstants.storeInstallment ? "تقسيط" : "كهربائية"})'),
              )).toList(),
              onChanged: (v) => setState(() => _selectedCustomerId = v),
            ),
            const SizedBox(height: 12),
          ],

          if (_targetType == 'specific_user') ...[
            DropdownButtonFormField<int>(
              value: _selectedUserId,
              decoration: const InputDecoration(labelText: 'اختر المستخدم', border: OutlineInputBorder()),
              items: _users.map((u) => DropdownMenuItem<int>(
                value: u.id!,
                child: Text('${u.name}  (${_roleLabel(u.role)})'),
              )).toList(),
              onChanged: (v) => setState(() => _selectedUserId = v),
            ),
            const SizedBox(height: 12),
          ],

          // ─── Notification Content ────────────────────────────────────────
          const Text('محتوى الإشعار', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'عنوان الإشعار *',
              prefixIcon: Icon(Icons.title),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bodyCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'نص الإشعار *',
              prefixIcon: Icon(Icons.message),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),

          // ─── Templates ───────────────────────────────────────────────────
          const Text('قوالب سريعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _TemplateChip(
              'تذكير قسط', 'تذكير: موعد القسط',
              'يرجى سداد القسط المستحق في أقرب وقت. شكراً لتعاملكم معنا.',
              _titleCtrl, _bodyCtrl, setState,
            ),
            _TemplateChip(
              'عرض خاص', 'عرض خاص لك!',
              'لدينا عرض حصري لك. تفضل بزيارتنا أو التواصل معنا لمعرفة التفاصيل.',
              _titleCtrl, _bodyCtrl, setState,
            ),
            _TemplateChip(
              'ترحيب', 'أهلاً بك!',
              'مرحباً بك في منظومة فرصتك للتقسيط. نحن سعداء بخدمتك.',
              _titleCtrl, _bodyCtrl, setState,
            ),
            _TemplateChip(
              'إغلاق العطلة', 'إشعار بالعطلة',
              'عزيزنا العميل، سيكون المحل مغلقاً في العطلة الرسمية. سنعود للعمل قريباً.',
              _titleCtrl, _bodyCtrl, setState,
            ),
          ]),
          const SizedBox(height: 24),

          // ─── Send Button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _loading ? null : _send,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_loading ? 'جاري الإرسال...' : 'إرسال الإشعار'),
            ),
          ),

          if (_sent) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('تم إرسال الإشعار بنجاح', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  String _roleLabel(String role) {
    const labels = {
      'admin': 'مدير النظام', 'manager': 'مدير',
      'partner': 'شريك', 'employee': 'موظف',
    };
    return labels[role] ?? role;
  }
}

class _TemplateChip extends StatelessWidget {
  final String label, title, body;
  final TextEditingController titleCtrl, bodyCtrl;
  final Function(Function()) rebuild;
  const _TemplateChip(this.label, this.title, this.body, this.titleCtrl, this.bodyCtrl, this.rebuild);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: () => rebuild(() { titleCtrl.text = title; bodyCtrl.text = body; }),
      backgroundColor: const Color(AppColors.primaryInt).withValues(alpha: 0.1),
    );
  }
}
