import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../models/customer.dart';
import '../../../models/department.dart';
import '../../../database/daos/department_dao.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/whatsapp_helper.dart';
import '../../../widgets/common/search_bar_widget.dart';
import 'customer_detail_screen.dart';
import 'customer_points_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final customers = provider.customers
        .where((c) =>
            _query.isEmpty ||
            c.name.contains(_query) ||
            (c.phone?.contains(_query) ?? false))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('العملاء'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          SearchBarWidget(
            hint: 'ابحث بالاسم أو الهاتف...',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : customers.isEmpty
                    ? const Center(child: Text('لا يوجد عملاء'))
                    : ListView.builder(
                        itemCount: customers.length,
                        itemBuilder: (ctx, i) =>
                            _CustomerTile(customer: customers[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => _showAddCustomerDialog(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final provider = context.read<CustomerProvider>();
    showDialog(
      context: context,
      builder: (_) => _AddCustomerDialog(provider: provider),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;

  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: const Color(AppColors.primaryInt).withValues(alpha: 0.1),
              child: Text(customer.name[0],
                  style: const TextStyle(
                      color: Color(AppColors.primaryInt),
                      fontWeight: FontWeight.bold)),
            ),
            if (customer.isBlacklisted)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.block, color: Colors.white, size: 10),
                ),
              )
            else if (customer.isVip)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700, shape: BoxShape.circle),
                  child: const Icon(Icons.star, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
        title: Row(children: [
          Expanded(child: Text(customer.name)),
          if (customer.isVip)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Text('VIP', style: TextStyle(fontSize: 10, color: Colors.amber.shade800, fontWeight: FontWeight.bold)),
            )
          else if (customer.isBlacklisted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: const Text('محظور', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
            ),
        ]),
        subtitle: Text(
          '${customer.phone ?? 'لا يوجد هاتف'} | ${_storeTypeLabel(customer.storeType)}${_priceTypeLabel(customer.priceType).isNotEmpty ? ' | ${_priceTypeLabel(customer.priceType)}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (customer.balance > 0)
                  Text(
                    AppFormatters.formatCurrency(customer.balance),
                    style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerPointsScreen(customer: customer),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text('⭐ ${customer.points} نقطة',
                        style: TextStyle(
                            color: Colors.amber.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _showCustomerDetails(context),
      ),
    );
  }

  void _showCustomerDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(customer: customer),
      ),
    );
  }

  String _priceTypeLabel(String type) {
    switch (type) {
      case 'wholesale':
        return 'جملة';
      case 'semi_wholesale':
        return 'نصف جملة';
      default:
        return '';
    }
  }

  String _storeTypeLabel(String type) {
    switch (type) {
      case 'electrical':
        return 'كهربائيات';
      case 'installment':
        return 'تقسيط';
      default:
        return type;
    }
  }
}

class _AddCustomerDialog extends StatefulWidget {
  final Customer? customer;
  final CustomerProvider provider;

  const _AddCustomerDialog({this.customer, required this.provider});

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late String _customerType;
  late String _priceType;
  late String _storeType;
  bool _saving = false;
  List<Department> _departments = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer?.name);
    _phoneCtrl = TextEditingController(text: widget.customer?.phone);
    _addressCtrl = TextEditingController(text: widget.customer?.address);
    _customerType =
        widget.customer?.customerType ?? AppConstants.customerTypeRegular;
    _priceType = widget.customer?.priceType ?? AppConstants.priceRetail;
    _storeType = widget.customer?.storeType ?? AppConstants.storeElectrical;
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    final depts = await DepartmentDao().getAll();
    if (mounted) {
      setState(() {
        _departments = depts;
        if (_departments.isNotEmpty &&
            !_departments.any((d) => d.storeType == _storeType)) {
          _storeType = _departments.first.storeType;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>?> _pickContact() async {
    try {
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى السماح بالوصول لجهات الاتصال من إعدادات الهاتف'),
            ),
          );
        }
        return null;
      }

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    final now = DateTime.now().toIso8601String();
    // Auto-generate login code for new customers
    final loginCode =
        widget.customer?.loginCode ?? AppFormatters.generateAccessCode();

    final c = Customer(
      id: widget.customer?.id,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      customerType: _customerType,
      priceType: _priceType,
      storeType: _storeType,
      loginCode: loginCode,
      isApproved: true,
      createdAt: widget.customer?.createdAt ?? now,
    );

    try {
      if (widget.customer == null) {
        await widget.provider.addCustomer(c);
      } else {
        await widget.provider.updateCustomer(c);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.customer == null
                ? 'تم إضافة العميل بنجاح ✓ | كود الدخول: $loginCode'
                : 'تم تحديث بيانات العميل بنجاح ✓'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        // Issue 7: Offer to send login code via WhatsApp for new customers
        if (widget.customer == null && c.phone != null && c.phone!.isNotEmpty) {
          final ctx = context;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!ctx.mounted) return;
            showDialog(
              context: ctx,
              builder: (_) => AlertDialog(
                title: const Row(children: [
                  Icon(Icons.chat, color: Colors.green),
                  SizedBox(width: 8),
                  Text('إرسال كود الدخول'),
                ]),
                content: Text(
                  'هل تريد إرسال كود الدخول للعميل ${c.name} عبر واتساب؟\n\nالكود: $loginCode',
                  style: const TextStyle(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('لا، شكراً'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('إرسال عبر واتساب'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      WhatsAppHelper.sendCustomerCode(
                        phone: c.phone!,
                        name: c.name,
                        code: loginCode,
                      );
                    },
                  ),
                ],
              ),
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'إضافة عميل' : 'تعديل العميل'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم *'),
                validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'الهاتف'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final contact = await _pickContact();
                    if (contact == null) return;
                    setState(() {
                      if (contact['name'] != null && contact['name']!.isNotEmpty) {
                        _nameCtrl.text = contact['name']!;
                      }
                      if (contact['phone'] != null && contact['phone']!.isNotEmpty) {
                        _phoneCtrl.text = contact['phone']!;
                      }
                    });
                  },
                  icon: const Icon(Icons.contacts, size: 18),
                  label: const Text('استيراد من جهات الاتصال'),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _customerType,
                decoration: const InputDecoration(labelText: 'نوع العميل'),
                items: const [
                  DropdownMenuItem(value: 'regular', child: Text('عادي')),
                  DropdownMenuItem(value: 'technician', child: Text('فني')),
                ],
                onChanged: (v) =>
                    setState(() => _customerType = v ?? _customerType),
              ),
              const SizedBox(height: 8),
              _departments.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: _departments.any((d) => d.storeType == _storeType)
                          ? _storeType
                          : _departments.first.storeType,
                      decoration: const InputDecoration(labelText: 'القسم'),
                      items: _departments
                          .map((d) => DropdownMenuItem(
                                value: d.storeType,
                                child: Text(d.name),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _storeType = v ?? _storeType),
                    ),
              const SizedBox(height: 8),
              if (_storeType == 'electrical') ...[
                DropdownButtonFormField<String>(
                  value: _priceType,
                  decoration: const InputDecoration(
                      labelText: 'مستوى الأسعار (للكهربائيات)'),
                  items: const [
                    DropdownMenuItem(value: 'retail', child: Text('قطاعي')),
                    DropdownMenuItem(
                        value: 'semi_wholesale', child: Text('نصف جملة')),
                    DropdownMenuItem(value: 'wholesale', child: Text('جملة')),
                  ],
                  onChanged: (v) =>
                      setState(() => _priceType = v ?? _priceType),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'مستوى الأسعار يحدد ما يراه العميل في تطبيق الكهربائيات',
                    style: TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

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
                      final phone = c.phones.isNotEmpty ? c.phones.first.number : null;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(AppColors.primaryInt)
                              .withValues(alpha: 0.1),
                          child: Text(
                            c.displayName.isNotEmpty ? c.displayName[0] : '?',
                            style: const TextStyle(
                              color: Color(AppColors.primaryInt),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      ],
    );
  }
}
