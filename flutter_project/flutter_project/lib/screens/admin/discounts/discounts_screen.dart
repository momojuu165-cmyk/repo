import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../database/daos/request_dao.dart';
import '../../../providers/customer_provider.dart';
import '../../../models/customer.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadAll();
    });
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
        title: const Text('إدارة الخصومات'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions, size: 18),
              text: 'طلبات بعربون',
            ),
            Tab(
              icon: Icon(Icons.loyalty, size: 18),
              text: 'خصومات العملاء',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _DepositRequestsTab(),
          _CustomerDiscountsTab(),
        ],
      ),
    );
  }
}

// ─── Tab 1: Requests with Deposits ───────────────────────────────────────────

class _DepositRequestsTab extends StatefulWidget {
  const _DepositRequestsTab();

  @override
  State<_DepositRequestsTab> createState() => _DepositRequestsTabState();
}

class _DepositRequestsTabState extends State<_DepositRequestsTab> {
  final _dao = RequestDao();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {

    final all =
        await _dao.getAllWithCustomer(status: AppConstants.requestStatusPending);
    final withDeposit =
        all.where((r) => (r['deposit_amount'] as num? ?? 0) > 0).toList();
    if (mounted) setState(() {
      _requests = withDeposit;
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

    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.discount_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد طلبات بعربون',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'ستظهر هنا الطلبات التي دفع فيها العميل عربوناً',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'هذه الطلبات يمكنك تطبيق خصم عليها قبل الموافقة — العميل دفع عربوناً',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._requests.map((r) => _DepositRequestCard(
                request: r,
                onRefresh: _load,
                dao: _dao,
              )),
        ],
      ),
    );
  }
}

class _DepositRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onRefresh;
  final RequestDao dao;

  const _DepositRequestCard({
    required this.request,
    required this.onRefresh,
    required this.dao,
  });

  @override
  Widget build(BuildContext context) {
    final deposit = (request['deposit_amount'] as num? ?? 0).toDouble();
    final months = request['num_installments'] as int?;
    final phone = request['customer_phone'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_bag,
                      color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['product_name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'العميل: ${request['customer_name'] ?? 'غير محدد'}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'عربون: ${AppFormatters.formatCurrency(deposit)}',
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                    if (months != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('$months شهر',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11)),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            Row(
              children: [
                if (phone != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('واتساب', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => _openWhatsApp(phone),
                    ),
                  ),
                if (phone != null) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.discount, size: 16),
                    label: const Text('تطبيق خصم', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      side: const BorderSide(color: Colors.deepOrange),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _showDiscountDialog(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label:
                        const Text('موافقة', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onPressed: () =>
                        _approve(context, discount: 0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    final number = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted =
        number.startsWith('0') ? '2$number' : number;
    final uri = Uri.parse('https://wa.me/$formatted');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showDiscountDialog(BuildContext context) {
    final discCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.discount, color: Colors.deepOrange),
            const SizedBox(width: 8),
            const Text('تطبيق خصم'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'المنتج: ${request['product_name']}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'العربون المدفوع: ${AppFormatters.formatCurrency((request['deposit_amount'] as num? ?? 0).toDouble())}',
              style: const TextStyle(color: Colors.green, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: discCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'نسبة الخصم %',
                prefixIcon: Icon(Icons.percent),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'أو قيمة ثابتة',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryInt),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final disc = double.tryParse(discCtrl.text) ?? 0;
              Navigator.pop(context);
              await _approve(context, discount: disc);
            },
            child: const Text('تطبيق والموافقة'),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, {required double discount}) async {
    await dao.updateStatus(
      request['id'] as int,
      AppConstants.requestStatusApproved,
      adminDiscount: discount,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              discount > 0 ? 'تمت الموافقة مع خصم $discount%' : 'تمت الموافقة'),
          backgroundColor: Colors.green,
        ),
      );
    }
    onRefresh();
  }
}

// ─── Tab 2: Customer Discounts ────────────────────────────────────────────────

class _CustomerDiscountsTab extends StatelessWidget {
  const _CustomerDiscountsTab();

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>().customers;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  color: Colors.purple.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'يمكنك تطبيق خصم خاص على أي عميل — يُطبق على طلباته القادمة',
                  style: TextStyle(
                      color: Colors.purple.shade700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (customers.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('لا يوجد عملاء',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...customers.map((c) => _CustomerDiscountCard(customer: c)),
      ],
    );
  }
}

class _CustomerDiscountCard extends StatelessWidget {
  final Customer customer;

  const _CustomerDiscountCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              const Color(AppColors.primaryInt).withValues(alpha: 0.1),
          child: Text(
            customer.name[0],
            style: const TextStyle(
                color: Color(AppColors.primaryInt),
                fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(customer.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          customer.phone ?? 'لا يوجد هاتف',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PriceTypeBadge(customer.priceType),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.discount,
                  color: Colors.deepOrange, size: 20),
              tooltip: 'تطبيق خصم',
              onPressed: () => _showDiscountDialog(context, customer),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, Customer customer) {
    final discCtrl = TextEditingController();
    String selectedType = 'percent';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('خصم لـ ${customer.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('نسبة %',
                          style: TextStyle(fontSize: 13)),
                      value: 'percent',
                      groupValue: selectedType,
                      onChanged: (v) =>
                          setS(() => selectedType = v ?? 'percent'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('قيمة ثابتة',
                          style: TextStyle(fontSize: 13)),
                      value: 'fixed',
                      groupValue: selectedType,
                      onChanged: (v) =>
                          setS(() => selectedType = v ?? 'fixed'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: discCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: selectedType == 'percent'
                      ? 'نسبة الخصم %'
                      : 'قيمة الخصم',
                  prefixIcon: Icon(
                    selectedType == 'percent'
                        ? Icons.percent
                        : Icons.attach_money,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'الخصم يُطبق على طلبات العميل القادمة فقط بعد دفع العربون',
                  style: TextStyle(fontSize: 11, color: Colors.deepOrange),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryInt),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final value = double.tryParse(discCtrl.text) ?? 0;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'تم حفظ خصم ${selectedType == 'percent' ? '$value%' : '${value} ج.م'} للعميل ${customer.name}'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('حفظ الخصم'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceTypeBadge extends StatelessWidget {
  final String priceType;

  const _PriceTypeBadge(this.priceType);

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (priceType) {
      case 'wholesale':
        label = 'جملة';
        color = Colors.blue;
        break;
      case 'semi_wholesale':
        label = 'نصف جملة';
        color = Colors.purple;
        break;
      default:
        label = 'قطاعي';
        color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
