import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../database/daos/customer_dao.dart';
import '../../../models/customer.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

enum _TxnType { invoice, payment, installmentPayment, returnInvoice }

class _Transaction {
  final String date;
  final String title;
  final String subtitle;
  final double amount;
  final _TxnType type;

  _Transaction({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
  });
}

class CustomerStatementScreen extends StatefulWidget {
  const CustomerStatementScreen({super.key});

  @override
  State<CustomerStatementScreen> createState() =>
      _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  final _customerDao = CustomerDao();
  List<Customer> _customers = [];
  Customer? _selected;
  List<_Transaction> _transactions = [];
  bool _loadingCustomers = true;
  bool _loadingStatement = false;

  double _totalInvoiced = 0;
  double _totalPaid = 0;
  double _totalReturns = 0;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final list = await _customerDao.getAll();
    if (mounted) setState(() { _customers = list; _loadingCustomers = false; });
  }

  Future<void> _loadStatement(Customer customer) async {
    setState(() { _loadingStatement = true; _transactions = []; });
    try {
      final client = Supabase.instance.client;

      final List<_Transaction> txns = [];
      double invoiced = 0, paid = 0, returns = 0;

      // ── Sales invoices ───────────────────────────────────────────────
      final invoices = await client
          .from('sales_invoices')
          .select()
          .eq('customer_id', customer.id!)
          .order('date', ascending: true);
      for (final row in invoices) {
        final total = (row['total'] as num? ?? 0).toDouble();
        final isReturn = row['status'] == AppConstants.invoiceStatusReturn;
        if (isReturn) {
          returns += total;
          txns.add(_Transaction(
            date: row['date'] as String? ?? '',
            title: 'مرتجع: ${row['invoice_no']}',
            subtitle: 'مرتجع مبيعات',
            amount: total,
            type: _TxnType.returnInvoice,
          ));
        } else {
          invoiced += total;
          txns.add(_Transaction(
            date: row['date'] as String? ?? '',
            title: 'فاتورة: ${row['invoice_no']}',
            subtitle: _paymentTypeLabel(row['payment_type'] as String? ?? ''),
            amount: total,
            type: _TxnType.invoice,
          ));
        }
      }

      // ── Customer direct payments ──────────────────────────────────────
      final payments = await client
          .from('customer_payments')
          .select()
          .eq('customer_id', customer.id!)
          .order('date', ascending: true);
      for (final row in payments) {
        final amount = (row['amount'] as num? ?? 0).toDouble();
        paid += amount;
        txns.add(_Transaction(
          date: row['date'] as String? ?? '',
          title: 'دفعة مباشرة',
          subtitle: _methodLabel(row['payment_method'] as String? ?? ''),
          amount: amount,
          type: _TxnType.payment,
        ));
      }

      // ── Installment payments ──────────────────────────────────────────
      try {
        final instList = await client
            .from('installments')
            .select('id, item_name')
            .eq('customer_id', customer.id!);
        final instIds = List<Map<String, dynamic>>.from(instList)
            .map((r) => r['id'] as int)
            .toList();
        if (instIds.isNotEmpty) {
          final instPayments = await client
              .from('installment_payments')
              .select('paid_date, amount, installment_id')
              .inFilter('installment_id', instIds)
              .eq('status', 'paid')
              .order('paid_date', ascending: true);
          final instNameMap = {
            for (final r in instList)
              r['id'] as int: r['item_name'] as String? ?? ''
          };
          for (final row in instPayments) {
            final amount = (row['amount'] as num? ?? 0).toDouble();
            final instId = row['installment_id'] as int? ?? 0;
            paid += amount;
            txns.add(_Transaction(
              date: row['paid_date'] as String? ?? '',
              title: 'قسط: ${instNameMap[instId] ?? ''}',
              subtitle: 'دفعة قسط',
              amount: amount,
              type: _TxnType.installmentPayment,
            ));
          }
        }
      } catch (_) {
        // installment_payments table may not exist for all customers
      }

      // Sort by date descending (newest first)
      txns.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _transactions = txns;
          _totalInvoiced = invoiced;
          _totalPaid = paid;
          _totalReturns = returns;
          _loadingStatement = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStatement = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الكشف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double get _outstanding => _totalInvoiced - _totalReturns - _totalPaid;

  String _paymentTypeLabel(String type) {
    switch (type) {
      case 'cash': return 'نقدي';
      case 'installment': return 'أقساط';
      case 'partial': return 'جزئي';
      case 'transfer': return 'تحويل';
      default: return type;
    }
  }

  String _methodLabel(String method) {
    return method == AppConstants.paymentMethodStore ? 'في المتجر' : 'إيصال';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف حساب عميل'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          if (_selected != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadStatement(_selected!),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Customer Selector ──────────────────────────────────────
          Container(
            color: const Color(AppColors.primaryInt).withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: _loadingCustomers
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<Customer>(
                    isExpanded: true,
                    value: _selected,
                    decoration: const InputDecoration(
                      labelText: 'اختر العميل',
                      prefixIcon: Icon(Icons.person_search),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _customers
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                '${c.name}${c.phone != null ? " | ${c.phone}" : ""}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (c) {
                      if (c != null) {
                        setState(() => _selected = c);
                        _loadStatement(c);
                      }
                    },
                  ),
          ),

          if (_selected != null && !_loadingStatement) ...[
            // ── Summary Cards ────────────────────────────────────────
            _SummaryRow(
              invoiced: _totalInvoiced,
              paid: _totalPaid,
              returns: _totalReturns,
              outstanding: _outstanding,
            ),
          ],

          // ── Transaction List ───────────────────────────────────────
          Expanded(
            child: _loadingStatement
                ? const Center(child: CircularProgressIndicator())
                : _selected == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 72, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('اختر عميلاً لعرض كشف حسابه',
                                style: TextStyle(color: Colors.grey, fontSize: 15)),
                          ],
                        ),
                      )
                    : _transactions.isEmpty
                        ? const Center(
                            child: Text('لا توجد معاملات لهذا العميل',
                                style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _transactions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (ctx, i) =>
                                _TxnCard(txn: _transactions[i]),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final double invoiced;
  final double paid;
  final double returns;
  final double outstanding;

  const _SummaryRow({
    required this.invoiced,
    required this.paid,
    required this.returns,
    required this.outstanding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(AppColors.primaryInt),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          _summaryCell('إجمالي الفواتير', invoiced, Colors.white),
          _divider(),
          _summaryCell('إجمالي المدفوع', paid, Colors.greenAccent.shade100),
          _divider(),
          _summaryCell('المرتجعات', returns, Colors.orangeAccent.shade100),
          _divider(),
          _summaryCell(
            'المتبقي',
            outstanding,
            outstanding > 0 ? Colors.red.shade200 : Colors.greenAccent.shade100,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1, height: 36,
        color: Colors.white24,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  Widget _summaryCell(String label, double amount, Color amountColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 10, height: 1.2)),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              AppFormatters.formatCurrency(amount),
              style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Transaction Card ─────────────────────────────────────────────────────────

class _TxnCard extends StatelessWidget {
  final _Transaction txn;

  const _TxnCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isDebit = txn.type == _TxnType.invoice;
    final isReturn = txn.type == _TxnType.returnInvoice;
    final isCredit =
        txn.type == _TxnType.payment || txn.type == _TxnType.installmentPayment;

    Color leadingColor;
    IconData leadingIcon;
    Color amountColor;
    String sign;

    if (isReturn) {
      leadingColor = Colors.orange.shade700;
      leadingIcon = Icons.assignment_return;
      amountColor = Colors.orange.shade800;
      sign = '- ';
    } else if (isDebit) {
      leadingColor = const Color(AppColors.dangerInt);
      leadingIcon = Icons.receipt_long;
      amountColor = const Color(AppColors.dangerInt);
      sign = '+ ';
    } else {
      leadingColor = const Color(AppColors.successInt);
      leadingIcon = isCredit && txn.type == _TxnType.installmentPayment
          ? Icons.calendar_month
          : Icons.payment;
      amountColor = const Color(AppColors.successInt);
      sign = '- ';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: leadingColor.withValues(alpha: 0.12),
          child: Icon(leadingIcon, color: leadingColor, size: 18),
        ),
        title: Text(txn.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(
          '${txn.subtitle}  |  ${AppFormatters.formatDateFromString(txn.date)}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Text(
          '$sign${AppFormatters.formatCurrency(txn.amount)}',
          style: TextStyle(
            color: amountColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
