import 'package:flutter/material.dart';
import '../../database/daos/customer_invoice_dao.dart';
import '../../models/customer_invoice.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'customer_create_invoice_screen.dart';

class CustomerInvoicesListScreen extends StatefulWidget {
  final int customerId;
  final String storeType;
  const CustomerInvoicesListScreen({super.key, required this.customerId, required this.storeType});
  @override
  State<CustomerInvoicesListScreen> createState() => _CustomerInvoicesListScreenState();
}

class _CustomerInvoicesListScreenState extends State<CustomerInvoicesListScreen> {
  final _dao = CustomerInvoiceDao();
  List<CustomerInvoice> _invoices = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {

    final inv = await _dao.getForCustomer(widget.customerId);
    if (mounted) setState(() { _invoices = inv; _loading = false; });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فواتيري'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await Navigator.push<bool>(context, MaterialPageRoute(
            builder: (_) => CustomerCreateInvoiceScreen(
                customerId: widget.customerId, storeType: widget.storeType),
          ));
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('فاتورة جديدة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('لا توجد فواتير بعد', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppColors.primaryInt),
                      foregroundColor: Colors.white),
                    onPressed: () async {
                      final created = await Navigator.push<bool>(context, MaterialPageRoute(
                        builder: (_) => CustomerCreateInvoiceScreen(
                          customerId: widget.customerId, storeType: widget.storeType),
                      ));
                      if (created == true) _load();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('إنشاء أول فاتورة')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _invoices.length,
                    itemBuilder: (ctx, i) {
                      final inv = _invoices[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(inv.status).withValues(alpha: 0.12),
                            child: Icon(_statusIcon(inv.status), color: _statusColor(inv.status), size: 20),
                          ),
                          title: Text(inv.invoiceNo,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(AppFormatters.formatDateFromString(inv.date)),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(AppFormatters.formatCurrency(inv.total),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(inv.status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8)),
                              child: Text(inv.statusLabel,
                                  style: TextStyle(color: _statusColor(inv.status), fontSize: 10,
                                      fontWeight: FontWeight.bold))),
                          ]),
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  const Icon(Icons.payment, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(inv.paymentMethodLabel,
                                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ]),
                                if (inv.notes != null) ...[
                                  const SizedBox(height: 4),
                                  Text('ملاحظات: ${inv.notes}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                                const Divider(),
                                ...inv.items.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(children: [
                                    Expanded(child: Text(item.itemName, style: const TextStyle(fontSize: 13))),
                                    Text('${item.qty.toStringAsFixed(0)} × ${AppFormatters.formatCurrency(item.unitPrice)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(width: 8),
                                    Text(AppFormatters.formatCurrency(item.total),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ]),
                                )),
                                const SizedBox(height: 8),
                              ]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      case 'delivered': return Colors.blue;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      case 'delivered': return Icons.local_shipping;
      default: return Icons.schedule;
    }
  }
}
