import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../database/daos/request_dao.dart';
import '../../models/product_request.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _dao = RequestDao();
  List<ProductRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final customerId = auth.currentCustomer?.id;
    if (customerId == null) return;
    setState(() => _loading = true);
    try {

    final r = await _dao.getByCustomer(customerId);
    if (mounted) setState(() {
      _requests = r;
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
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد طلبات بعد',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _requests.length,
        itemBuilder: (ctx, i) {
          final req = _requests[i];
          return _RequestCard(request: req);
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ProductRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(request.productName,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                _StatusBadge(request.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'تاريخ الطلب: ${AppFormatters.formatDateFromString(request.date)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              'طريقة الدفع: ${request.paymentMethod == AppConstants.paymentMethodStore ? 'في المحل' : 'رفع إيصال'}',
              style: const TextStyle(fontSize: 13),
            ),
            if (request.numInstallments != null)
              Text(
                'عدد الأقساط: ${request.numInstallments} شهر',
                style: const TextStyle(fontSize: 13),
              ),
            if (request.depositAmount > 0)
              Text(
                'العربون: ${AppFormatters.formatCurrency(request.depositAmount)}',
                style: const TextStyle(fontSize: 13),
              ),
            if (request.adminDiscount > 0)
              Text(
                'خصم الإدارة: ${request.adminDiscount.toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.green, fontSize: 13),
              ),
            if (request.receiptPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('إيصال مرفوع',
                        style: TextStyle(color: Colors.green, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;
    late IconData icon;
    switch (status) {
      case AppConstants.requestStatusApproved:
        color = Colors.green;
        label = 'مقبول';
        icon = Icons.check_circle;
        break;
      case AppConstants.requestStatusRejected:
        color = Colors.red;
        label = 'مرفوض';
        icon = Icons.cancel;
        break;
      case AppConstants.requestStatusCompleted:
        color = Colors.blue;
        label = 'مكتمل';
        icon = Icons.done_all;
        break;
      default:
        color = Colors.orange;
        label = 'قيد المراجعة';
        icon = Icons.hourglass_empty;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
