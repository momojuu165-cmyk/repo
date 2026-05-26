import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class CustomerRegisterScreen extends StatefulWidget {
  final String storeType;

  const CustomerRegisterScreen({
    super.key,
    this.storeType = AppConstants.storeElectrical,
  });

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _homeAddressCtrl = TextEditingController();
  final _workAddressCtrl = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  bool get _isElectrical => widget.storeType == AppConstants.storeElectrical;
  Color get _storeColor => _isElectrical
      ? const Color(AppColors.electricalInt)
      : const Color(AppColors.installmentInt);
  String get _storeTitle =>
      _isElectrical ? 'متجر الأدوات الكهربائية' : 'متجر التقسيط';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _homeAddressCtrl.dispose();
    _workAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {

    final error = await context.read<AuthProvider>().registerCustomer(
          name: _nameCtrl.text.trim(),
          fullName: _fullNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          whatsapp: _whatsappCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          homeAddress: _homeAddressCtrl.text.trim(),
          workAddress: _workAddressCtrl.text.trim(),
          storeType: widget.storeType,
        );
    setState(() {
      _loading = false;
      if (error == null) _submitted = true;
    });
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating),
      );
    }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('تسجيل في $_storeTitle'),
        backgroundColor: _storeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle,
                  color: Colors.green.shade600, size: 72),
            ),
            const SizedBox(height: 24),
            const Text(
              'تم إرسال طلبك بنجاح!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'سيراجع المدير طلبك ويرسل لك كود الدخول عبر واتساب في أقرب وقت.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _storeColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.popUntil(context, (r) => r.isFirst),
              icon: const Icon(Icons.home),
              label: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _storeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _storeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isElectrical
                        ? Icons.electrical_services
                        : Icons.payment,
                    color: _storeColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _storeTitle,
                    style: TextStyle(
                        color: _storeColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(label: 'البيانات الأساسية', icon: Icons.person),
            const SizedBox(height: 12),
            _buildField(
              controller: _nameCtrl,
              label: 'الاسم المعروف (الكنية) *',
              icon: Icons.badge,
              validator: (v) =>
                  v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _fullNameCtrl,
              label: 'الاسم بالكامل *',
              icon: Icons.person,
              validator: (v) =>
                  v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
            ),
            const SizedBox(height: 20),
            _SectionHeader(
                label: 'بيانات التواصل', icon: Icons.contact_phone),
            const SizedBox(height: 12),
            _buildField(
              controller: _phoneCtrl,
              label: 'رقم الهاتف *',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              isLtr: true,
              validator: (v) =>
                  v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _whatsappCtrl,
              label: 'رقم واتساب *',
              icon: Icons.chat,
              keyboardType: TextInputType.phone,
              isLtr: true,
              validator: (v) =>
                  v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _emailCtrl,
              label: 'البريد الإلكتروني',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              isLtr: true,
            ),
            const SizedBox(height: 20),
            _SectionHeader(label: 'بيانات العنوان', icon: Icons.location_on),
            const SizedBox(height: 12),
            _buildField(
              controller: _homeAddressCtrl,
              label: 'عنوان السكن *',
              icon: Icons.home,
              maxLines: 2,
              validator: (v) =>
                  v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _workAddressCtrl,
              label: 'عنوان العمل',
              icon: Icons.business,
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _storeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                    _loading ? 'جارٍ الإرسال...' : 'إرسال طلب التسجيل'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isLtr = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: validator,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }
}
