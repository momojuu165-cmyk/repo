import 'package:flutter/material.dart';
import '../../../database/database_helper.dart';
import '../../../database/daos/partner_group_dao.dart';
import '../../../models/partner_group.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/pdf_helper.dart';

// ── PartnerGroupStatementScreen ───────────────────────────────────────────────
// Displays all installments linked to a partner group's assigned products.
// Supports PDF export per whole group OR per individual product.

class PartnerGroupStatementScreen extends StatefulWidget {
  final PartnerGroup group;

  const PartnerGroupStatementScreen({super.key, required this.group});

  @override
  State<PartnerGroupStatementScreen> createState() =>
      _PartnerGroupStatementScreenState();
}

class _PartnerGroupStatementScreenState
    extends State<PartnerGroupStatementScreen> {
  final _dao = PartnerGroupDao();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _allInstallments = [];
  String? _selectedProduct;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {

    final products =
        await _dao.getProductAssignments(widget.group.id!);
    final installments =
        await _dao.getInstallmentsForGroup(widget.group.id!);
    if (mounted) {
      setState(() {
        _products = products;
        _allInstallments = installments;
        _loading = false;
      });
    }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  List<Map<String, dynamic>> get _filtered {
    if (_selectedProduct == null) return _allInstallments;
    return _allInstallments
        .where((r) => r['item_name'] == _selectedProduct)
        .toList();
  }

  double get _totalAmount =>
      _filtered.fold(0.0, (s, r) => s + (r['total_price'] as num? ?? 0));
  double get _totalPaid =>
      _filtered.fold(0.0, (s, r) => s + (r['paid_amount'] as num? ?? 0));
  double get _totalRemaining => _totalAmount - _totalPaid;

  Future<void> _exportPdf({String? productFilter}) async {
    final rows = productFilter == null
        ? _allInstallments
        : _allInstallments
            .where((r) => r['item_name'] == productFilter)
            .toList();

    final title = productFilter == null
        ? 'كشف تقسيط — ${widget.group.name}'
        : 'كشف تقسيط — ${widget.group.name} — $productFilter';

    double total = 0, paid = 0;
    for (final r in rows) {
      total += (r['total_price'] as num? ?? 0).toDouble();
      paid += (r['paid_amount'] as num? ?? 0).toDouble();
    }

    await PdfHelper.printReport(
      context: context,
      title: title,
      subtitle: 'تاريخ الطباعة: ${DateTime.now().toString().substring(0, 10)}',
      headers: const [
        ['العميل', 'المنتج', 'الإجمالي', 'مدفوع', 'متبقي', 'قسط/شهر', 'الحالة'],
      ],
      rows: rows.map((r) {
        final tp = (r['total_price'] as num? ?? 0).toDouble();
        final pa = (r['paid_amount'] as num? ?? 0).toDouble();
        final status = r['status'] as String? ?? 'active';
        final statusLabel = status == 'completed'
            ? 'مكتمل'
            : status == 'overdue'
                ? 'متأخر'
                : 'نشط';
        return [
          r['customer_name'] as String? ?? '',
          r['item_name'] as String? ?? '',
          AppFormatters.formatCurrency(tp),
          AppFormatters.formatCurrency(pa),
          AppFormatters.formatCurrency(tp - pa),
          AppFormatters.formatCurrency(
              (r['monthly_amount'] as num? ?? 0).toDouble()),
          statusLabel,
        ];
      }).toList(),
      summaryRows: [
        {'label': 'إجمالي القيم', 'value': AppFormatters.formatCurrency(total)},
        {'label': 'إجمالي المدفوع', 'value': AppFormatters.formatCurrency(paid)},
        {
          'label': 'إجمالي المتبقي',
          'value': AppFormatters.formatCurrency(total - paid)
        },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('كشف تقسيط — ${widget.group.name}'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF للمجموعة كلها',
            onPressed: _allInstallments.isEmpty
                ? null
                : () => _exportPdf(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Summary strip ─────────────────────────────────────────
                Container(
                  color: const Color(AppColors.primaryInt),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _SummaryChip('الإجمالي', _totalAmount, Colors.white),
                      const SizedBox(width: 8),
                      _SummaryChip('مدفوع', _totalPaid, Colors.green.shade200),
                      const SizedBox(width: 8),
                      _SummaryChip(
                          'متبقي', _totalRemaining, Colors.orange.shade200),
                    ],
                  ),
                ),

                // ── Product filter + per-product export ───────────────────
                if (_products.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _selectedProduct,
                            decoration: const InputDecoration(
                              labelText: 'فلتر حسب المنتج',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('جميع المنتجات')),
                              ..._products.map((p) => DropdownMenuItem<String?>(
                                    value: p['item_name'] as String,
                                    child: Text(p['item_name'] as String),
                                  )),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedProduct = v),
                          ),
                        ),
                        if (_selectedProduct != null) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                            label: const Text('PDF'),
                            onPressed: () =>
                                _exportPdf(productFilter: _selectedProduct),
                          ),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // ── Installments list ─────────────────────────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('لا توجد أقساط لهذه المجموعة',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final r = _filtered[i];
                            final tp =
                                (r['total_price'] as num? ?? 0).toDouble();
                            final pa =
                                (r['paid_amount'] as num? ?? 0).toDouble();
                            final status =
                                r['status'] as String? ?? 'active';
                            final color = status == 'completed'
                                ? Colors.green
                                : status == 'overdue'
                                    ? Colors.red
                                    : Colors.blue;
                            final statusLabel = status == 'completed'
                                ? 'مكتمل'
                                : status == 'overdue'
                                    ? 'متأخر'
                                    : 'نشط';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withValues(alpha: 0.1),
                                  child: Icon(Icons.payment, color: color),
                                ),
                                title: Text(
                                    r['customer_name'] as String? ?? '—',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        r['item_name'] as String? ?? '',
                                        style: const TextStyle(fontSize: 12)),
                                    Text(
                                        'متبقي: ${AppFormatters.formatCurrency(tp - pa)} | '
                                        '${r['num_installments']} قسط',
                                        style: const TextStyle(fontSize: 11)),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                        AppFormatters.formatCurrency(
                                            (r['monthly_amount'] as num? ?? 0)
                                                .toDouble()),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green)),
                                    Text(statusLabel,
                                        style: TextStyle(
                                            color: color, fontSize: 11)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double value;
  final Color textColor;
  const _SummaryChip(this.label, this.value, this.textColor);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: textColor.withValues(alpha: 0.8), fontSize: 11)),
          Text(AppFormatters.formatCurrency(value),
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
