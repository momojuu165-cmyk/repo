import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/sales_provider.dart';
import '../../../models/sales_invoice.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/common/date_range_picker.dart';
import 'sales_invoice_screen.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  List<SalesInvoice> _invoices = [];
  bool _loading = true;
  DateTime _from = DateTime.now().copyWith(day: 1);
  DateTime _to = DateTime.now();
  // null = all, 'cash', 'installment', 'return'
  String? _deptFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {

    final auth = context.read<AuthProvider>();
    final int? employeeId = auth.isAdmin ? null : auth.currentUser?.id;
    final invs = await context.read<SalesProvider>().getInvoices(
          fromDate: _from.toIso8601String().substring(0, 10),
          toDate: _to.toIso8601String().substring(0, 10),
          employeeId: employeeId,
        );
    if (mounted) setState(() {
      _invoices = invs;
      _loading = false;
    });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  List<SalesInvoice> get _filtered {
    if (_deptFilter == null) return _invoices;
    if (_deptFilter == 'return') {
      return _invoices.where((i) => i.status == 'return').toList();
    }
    return _invoices
        .where((i) => i.paymentType == _deptFilter && i.status != 'return')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('المبيعات'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SalesInvoiceScreen()),
            ).then((_) => _load()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DateRangePickerWidget(
              fromDate: _from,
              toDate: _to,
              onFromChanged: (d) {
                setState(() => _from = d);
                _load();
              },
              onToChanged: (d) {
                setState(() => _to = d);
                _load();
              },
            ),
          ),
          // ─── Department filter chips ───────────────────────────
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterChip(
                  label: 'الكل',
                  icon: Icons.all_inclusive,
                  color: Colors.grey,
                  selected: _deptFilter == null,
                  onTap: () => setState(() => _deptFilter = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'كاش',
                  icon: Icons.payments,
                  color: Colors.green,
                  selected: _deptFilter == 'cash',
                  onTap: () => setState(() => _deptFilter = 'cash'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'تقسيط',
                  icon: Icons.calendar_month,
                  color: Colors.blue,
                  selected: _deptFilter == 'installment',
                  onTap: () => setState(() => _deptFilter = 'installment'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'مرتجع',
                  icon: Icons.undo,
                  color: Colors.red,
                  selected: _deptFilter == 'return',
                  onTap: () => setState(() => _deptFilter = 'return'),
                ),
              ]),
            ),
          ),
          // ─── Invoice count summary ───────────────────────────
          if (!_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} فاتورة',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    AppFormatters.formatCurrency(
                        filtered.fold(0.0, (s, inv) => s + inv.total)),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('لا توجد فواتير'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final inv = filtered[i];
                          return _InvoiceTile(invoice: inv);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesInvoiceScreen()),
        ).then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('فاتورة جديدة'),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? color : Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? color : Colors.grey.shade700,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ]),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final SalesInvoice invoice;

  const _InvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(invoice.status).withValues(alpha: 0.1),
          child: Icon(_statusIcon(invoice.status),
              color: _statusColor(invoice.status), size: 20),
        ),
        title: Text(invoice.invoiceNo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(children: [
          Text(AppFormatters.formatDateFromString(invoice.date)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: invoice.paymentType == 'cash'
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              invoice.paymentType == 'cash' ? 'كاش' : 'تقسيط',
              style: TextStyle(
                fontSize: 10,
                color: invoice.paymentType == 'cash'
                    ? Colors.green.shade700
                    : Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ]),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AppFormatters.formatCurrency(invoice.total),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (invoice.remaining > 0)
              Text(
                'متبقي: ${AppFormatters.formatCurrency(invoice.remaining)}',
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
          ],
        ),
        onTap: () => _showInvoiceDetail(context),
      ),
    );
  }

  void _showInvoiceDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _InvoiceDetailSheet(invoice: invoice),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'return':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'paid':
        return Icons.check_circle;
      case 'partial':
        return Icons.pending;
      case 'return':
        return Icons.undo;
      default:
        return Icons.receipt;
    }
  }
}

class _InvoiceDetailSheet extends StatefulWidget {
  final SalesInvoice invoice;

  const _InvoiceDetailSheet({required this.invoice});

  @override
  State<_InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends State<_InvoiceDetailSheet> {
  List<SalesInvoiceItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await context
        .read<SalesProvider>()
        .getInvoiceItems(widget.invoice.id!);
    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(inv.invoiceNo,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(AppFormatters.formatDateFromString(inv.date),
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const Divider(),
          ..._items.map((item) => ListTile(
                dense: true,
                title: Text(item.itemName),
                subtitle: Text(
                    '${item.qty} × ${AppFormatters.formatCurrency(item.unitPrice)}'),
                trailing: Text(
                  AppFormatters.formatCurrency(item.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                AppFormatters.formatCurrency(inv.total),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green),
              ),
            ],
          ),
          if (inv.remaining > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المتبقي:',
                    style: TextStyle(color: Colors.red)),
                Text(
                  AppFormatters.formatCurrency(inv.remaining),
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
