import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/sales_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/pdf_helper.dart';
import '../../../widgets/common/date_range_picker.dart';
import '../../../database/daos/invoice_dao.dart';
import '../../../database/daos/treasury_dao.dart';
import '../../../database/daos/installment_dao.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _from = DateTime.now().copyWith(day: 1);
  DateTime _to = DateTime.now();
  String _section = 'all';

  static const _sections = [
    ('all', 'الكل'),
    ('store', 'المتجر'),
    ('installments', 'الأقساط'),
    ('electrical', 'الكهربائية'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Section filter ─────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _sections.map((s) {
                final selected = _section == s.$1;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(s.$2),
                    selected: selected,
                    selectedColor: const Color(AppColors.primaryInt),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _section = s.$1),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          DateRangePickerWidget(
            fromDate: _from,
            toDate: _to,
            onFromChanged: (d) => setState(() => _from = d),
            onToChanged: (d) => setState(() => _to = d),
          ),
          const SizedBox(height: 16),

          // ── Store reports ──────────────────────────────────────────────
          if (_section == 'all' || _section == 'store') ...[
            if (_section == 'all') _SectionHeader(label: 'تقارير المتجر'),
            _ReportTile(
              icon: Icons.point_of_sale,
              color: Colors.green,
              title: 'تقرير المبيعات',
              subtitle: 'إجمالي المبيعات والخصومات والمحصّل',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => _SalesReport(from: _from, to: _to))),
            ),


            _ReportTile(
              icon: Icons.inventory_2,
              color: Colors.purple,
              title: 'تقرير المخزون',
              subtitle: 'الكميات والأسعار لجميع الأصناف',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _InventoryReport())),
            ),
            _ReportTile(
              icon: Icons.account_balance_wallet,
              color: Colors.brown,
              title: 'تقرير الخزنة',
              subtitle: 'حركات الدخل والصرف',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => _TreasuryReport(from: _from, to: _to))),
            ),
            _ReportTile(
              icon: Icons.block,
              color: Colors.grey,
              title: 'تقرير المنتجات الموقوفة',
              subtitle: 'الأصناف الموقوفة عن البيع',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _BlockedItemsReport())),
            ),
          ],

          // ── Installments reports ───────────────────────────────────────
          if (_section == 'all' || _section == 'installments') ...[
            if (_section == 'all') _SectionHeader(label: 'تقارير الأقساط'),
            _ReportTile(
              icon: Icons.payment,
              color: Colors.orange,
              title: 'تقرير الأقساط',
              subtitle: 'جميع عقود التقسيط النشطة',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => _InstallmentsReport(from: _from, to: _to))),
            ),
            _ReportTile(
              icon: Icons.stars,
              color: Colors.amber,
              title: 'تقرير نقاط العملاء',
              subtitle: 'رصيد النقاط المتراكمة لكل عميل',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _CustomerPointsReport())),
            ),
          ],

          // ── Electrical reports ─────────────────────────────────────────
          if (_section == 'all' || _section == 'electrical') ...[
            if (_section == 'all') _SectionHeader(label: 'تقارير الكهربائية'),
            _ReportTile(
              icon: Icons.electrical_services,
              color: Colors.indigo,
              title: 'تقرير مبيعات الكهربائية',
              subtitle: 'فواتير العملاء في قسم الكهربائية',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => _SalesReport(from: _from, to: _to, storeType: 'electrical'))),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(AppColors.primaryInt))),
  );
}

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────── PDF action button ───────────────────────────

class _PdfButton extends StatefulWidget {
  final Future<void> Function() onGeneratePdf;
  const _PdfButton({required this.onGeneratePdf});

  @override
  State<_PdfButton> createState() => _PdfButtonState();
}

class _PdfButtonState extends State<_PdfButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'طباعة / تصدير PDF',
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.picture_as_pdf, color: Colors.white),
      onPressed: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              try {
                await widget.onGeneratePdf();
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
    );
  }
}

// ─────────────────────────────── Sales Report ────────────────────────────────

class _CustomerPointsReport extends StatefulWidget {
  const _CustomerPointsReport();
  @override
  State<_CustomerPointsReport> createState() => _CustomerPointsReportState();
}

class _CustomerPointsReportState extends State<_CustomerPointsReport> {
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await context.read<CustomerProvider>().getAll();
    if (mounted) {
      setState(() {
        _customers = rows
            .where((c) => (c.points ?? 0) > 0)
            .map((c) => {'name': c.name, 'phone': c.phone ?? '', 'points': c.points ?? 0})
            .toList()
          ..sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير نقاط العملاء'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? const Center(child: Text('لا يوجد عملاء لديهم نقاط', style: TextStyle(color: Colors.grey)))
              : Column(
                  children: [
                    Container(
                      color: const Color(AppColors.primaryInt),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('إجمالي العملاء: ${_customers.length}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        Text(
                          'إجمالي النقاط: ${_customers.fold(0, (s, c) => s + (c['points'] as int))}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ]),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _customers.length,
                        itemBuilder: (ctx, i) {
                          final c = _customers[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                child: const Icon(Icons.stars, color: Colors.amber),
                              ),
                              title: Text(c['name'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: c['phone'] != ''
                                  ? Text(c['phone'] as String)
                                  : null,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '${c['points']} نقطة',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                      fontSize: 13),
                                ),
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

class _SalesReport extends StatefulWidget {
  final DateTime from;
  final DateTime to;
  final String? storeType;
  const _SalesReport({required this.from, required this.to, this.storeType});

  @override
  State<_SalesReport> createState() => _SalesReportState();
}

class _SalesReportState extends State<_SalesReport> {
  Map<String, double>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final from = widget.from.toIso8601String().substring(0, 10);
    final to = widget.to.toIso8601String().substring(0, 10);
    final summary = await context.read<SalesProvider>().getSummary(from, to);
    if (mounted) setState(() => _summary = summary);
  }

  Future<void> _exportPdf() async {
    if (_summary == null) return;
    final fromStr = AppFormatters.formatDate(widget.from);
    final toStr = AppFormatters.formatDate(widget.to);
    await PdfHelper.printReport(
      context: context,
      title: 'تقرير المبيعات',
      subtitle: 'من $fromStr إلى $toStr',
      headers: [
        ['البند', 'المبلغ']
      ],
      rows: [
        [
          'إجمالي المبيعات',
          AppFormatters.formatCurrency(_summary!['total_sales']!)
        ],
        [
          'إجمالي الخصومات',
          AppFormatters.formatCurrency(_summary!['total_discounts']!)
        ],
        [
          'المحصّل',
          AppFormatters.formatCurrency(_summary!['total_collected']!)
        ],
        [
          'المتبقي',
          AppFormatters.formatCurrency(_summary!['total_remaining']!)
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير المبيعات'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [_PdfButton(onGeneratePdf: _exportPdf)],
      ),
      body: _summary == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        const Icon(Icons.date_range,
                            color: Colors.grey, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${AppFormatters.formatDate(widget.from)} → ${AppFormatters.formatDate(widget.to)}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _SummaryRow(
                          'إجمالي المبيعات',
                          AppFormatters.formatCurrency(
                              _summary!['total_sales']!)),
                      const Divider(),
                      _SummaryRow(
                          'إجمالي الخصومات',
                          AppFormatters.formatCurrency(
                              _summary!['total_discounts']!),
                          color: Colors.red),
                      _SummaryRow(
                          'المحصّل',
                          AppFormatters.formatCurrency(
                              _summary!['total_collected']!),
                          color: Colors.green),
                      _SummaryRow(
                          'المتبقي',
                          AppFormatters.formatCurrency(
                              _summary!['total_remaining']!),
                          color: Colors.orange),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────── Customer Statement ──────────────────────────

class _CustomerStatementReport extends StatefulWidget {
  final DateTime from;
  final DateTime to;
  const _CustomerStatementReport({required this.from, required this.to});

  @override
  State<_CustomerStatementReport> createState() =>
      _CustomerStatementReportState();
}

class _CustomerStatementReportState extends State<_CustomerStatementReport> {
  int? _selectedCustomerId;
  String? _selectedCustomerName;

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>().customers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف حساب عميل'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'اختر العميل',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: customers
                  .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) {
                final c = customers.firstWhere((c) => c.id == v);
                setState(() {
                  _selectedCustomerId = v;
                  _selectedCustomerName = c.name;
                });
              },
            ),
          ),
          if (_selectedCustomerId != null)
            Expanded(
              child: _CustomerInvoiceList(
                customerId: _selectedCustomerId!,
                customerName: _selectedCustomerName ?? '',
                from: widget.from,
                to: widget.to,
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomerInvoiceList extends StatefulWidget {
  final int customerId;
  final String customerName;
  final DateTime from;
  final DateTime to;
  const _CustomerInvoiceList({
    required this.customerId,
    required this.customerName,
    required this.from,
    required this.to,
  });

  @override
  State<_CustomerInvoiceList> createState() => _CustomerInvoiceListState();
}

class _CustomerInvoiceListState extends State<_CustomerInvoiceList> {
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final from = widget.from.toIso8601String().substring(0, 10);
    final to = widget.to.toIso8601String().substring(0, 10);
    final invs = await context
        .read<SalesProvider>()
        .getInvoices(customerId: widget.customerId, fromDate: from, toDate: to);
    if (mounted) setState(() => _invoices = invs);
  }

  Future<void> _exportPdf() async {
    final fromStr = AppFormatters.formatDate(widget.from);
    final toStr = AppFormatters.formatDate(widget.to);
    await PdfHelper.printReport(
      context: context,
      title: 'كشف حساب: ${widget.customerName}',
      subtitle: 'من $fromStr إلى $toStr',
      headers: [
        ['رقم الفاتورة', 'التاريخ', 'الإجمالي', 'المتبقي']
      ],
      rows: _invoices
          .map((inv) => [
                inv.invoiceNo.toString(),
                AppFormatters.formatDateFromString(inv.date),
                AppFormatters.formatCurrency(inv.total),
                AppFormatters.formatCurrency(inv.remaining),
              ])
          .toList(),
      summaryRows: [
        {'label': 'إجمالي الفواتير', 'value': '${_invoices.length}'},
        {
          'label': 'إجمالي المبلغ',
          'value': AppFormatters.formatCurrency(
              _invoices.fold(0.0, (s, i) => s + (i.total as double)))
        },
        {
          'label': 'إجمالي المتبقي',
          'value': AppFormatters.formatCurrency(
              _invoices.fold(0.0, (s, i) => s + (i.remaining as double)))
        },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalRemaining =
        _invoices.fold(0.0, (s, i) => s + (i.remaining as double));
    return Column(
      children: [
        if (_invoices.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_invoices.length} فاتورة',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _exportPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('PDF', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        if (totalRemaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Text(
                  'إجمالي المتبقي: ${AppFormatters.formatCurrency(totalRemaining)}',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _invoices.length,
            itemBuilder: (ctx, i) {
              final inv = _invoices[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: inv.remaining > 0
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  child: Icon(
                    inv.remaining > 0
                        ? Icons.warning_amber
                        : Icons.check_circle,
                    color: inv.remaining > 0 ? Colors.red : Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(inv.invoiceNo.toString()),
                subtitle: Text(AppFormatters.formatDateFromString(inv.date)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(AppFormatters.formatCurrency(inv.total),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (inv.remaining > 0)
                      Text(
                          'متبقي: ${AppFormatters.formatCurrency(inv.remaining)}',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Debtors Report ──────────────────────────────

class _DebtorsReport extends StatefulWidget {
  const _DebtorsReport();

  @override
  State<_DebtorsReport> createState() => _DebtorsReportState();
}

class _DebtorsReportState extends State<_DebtorsReport> {
  List<Map<String, dynamic>> _debtors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await context.read<CustomerProvider>().getDebtors();
    if (mounted) setState(() => _debtors = d);
  }

  Future<void> _exportPdf() async {
    final total =
        _debtors.fold(0.0, (s, d) => s + (d['balance'] as num).toDouble());
    await PdfHelper.printReport(
      context: context,
      title: 'تقرير المديونين',
      subtitle: 'إجمالي الديون: ${AppFormatters.formatCurrency(total)}',
      headers: [
        ['الاسم', 'الهاتف', 'المبلغ المستحق']
      ],
      rows: _debtors
          .map((d) => [
                d['name'] as String,
                d['phone'] as String? ?? '-',
                AppFormatters.formatCurrency((d['balance'] as num).toDouble()),
              ])
          .toList(),
      summaryRows: [
        {'label': 'عدد المديونين', 'value': '${_debtors.length}'},
        {
          'label': 'إجمالي الديون',
          'value': AppFormatters.formatCurrency(total)
        },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final total =
        _debtors.fold(0.0, (s, d) => s + (d['balance'] as num).toDouble());
    return Scaffold(
      appBar: AppBar(
        title: const Text('إجمالي المديونين'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [_PdfButton(onGeneratePdf: _exportPdf)],
      ),
      body: Column(
        children: [
          if (_debtors.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_debtors.length} مدين',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'الإجمالي: ${AppFormatters.formatCurrency(total)}',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _debtors.isEmpty
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, size: 64, color: Colors.green),
                    SizedBox(height: 8),
                    Text('لا يوجد مديونون',
                        style: TextStyle(color: Colors.green)),
                  ]))
                : ListView.builder(
                    itemCount: _debtors.length,
                    itemBuilder: (ctx, i) {
                      final d = _debtors[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(d['name'] as String,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(d['phone'] as String? ?? ''),
                        trailing: Text(
                          AppFormatters.formatCurrency(
                              (d['balance'] as num).toDouble()),
                          style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
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

// ─────────────────────────────── Inventory Report ────────────────────────────

class _InventoryReport extends StatelessWidget {
  const _InventoryReport();

  @override
  Widget build(BuildContext context) {
    final items = context.watch<InventoryProvider>().items;
    final totalValue =
        items.fold(0.0, (s, i) => s + i.quantity * i.priceRetail);

    Future<void> exportPdf() async {
      await PdfHelper.printReport(
        context: context,
        title: 'تقرير المخزون',
        subtitle:
            'إجمالي قيمة المخزون: ${AppFormatters.formatCurrency(totalValue)}',
        headers: [
          ['الصنف', 'الباركود', 'الكمية', 'سعر البيع']
        ],
        rows: items
            .map((item) => [
                  item.name,
                  item.barcode ?? '-',
                  item.quantity.toString(),
                  AppFormatters.formatCurrency(item.priceRetail),
                ])
            .toList(),
        summaryRows: [
          {'label': 'عدد الأصناف', 'value': '${items.length}'},
          {
            'label': 'إجمالي قيمة المخزون',
            'value': AppFormatters.formatCurrency(totalValue)
          },
          {
            'label': 'أصناف منخفضة المخزون (< 5)',
            'value': '${items.where((i) => i.quantity < 5).length}'
          },
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير المخزون'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          Builder(builder: (ctx) => _PdfButton(onGeneratePdf: exportPdf)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.purple.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${items.length} صنف',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'قيمة المخزون: ${AppFormatters.formatCurrency(totalValue)}',
                  style: const TextStyle(
                      color: Colors.purple, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                final isLow = item.quantity < 5;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLow
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    child: Icon(
                      isLow ? Icons.warning : Icons.inventory_2,
                      color: isLow ? Colors.red : Colors.green,
                      size: 18,
                    ),
                  ),
                  title: Text(item.name),
                  subtitle: Text(item.barcode ?? ''),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('الكمية: ${item.quantity}',
                          style: TextStyle(
                              color: isLow ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold)),
                      Text(AppFormatters.formatCurrency(item.priceRetail),
                          style: const TextStyle(fontSize: 12)),
                    ],
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

// ─────────────────────────────── Treasury Report ─────────────────────────────

// ─────────────────────────────── Treasury Report ─────────────────────────────
class _TreasuryReport extends StatefulWidget {
  final DateTime from;
  final DateTime to;
  const _TreasuryReport({required this.from, required this.to});

  @override
  State<_TreasuryReport> createState() => _TreasuryReportState();
}

class _TreasuryReportState extends State<_TreasuryReport> {
  List<dynamic> _movements = [];
  Map<String, double>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dao = TreasuryDao();
    final from = widget.from.toIso8601String().substring(0, 10);
    final to = widget.to.toIso8601String().substring(0, 10);

    final movements = await dao.getMovements(fromDate: from, toDate: to);
    final summary = await dao.getMovementSummary(1, from, to);

    if (mounted) {
      setState(() {
        _movements = movements;
        _summary = summary;
      });
    }
  }

  Future<void> _exportPdf() async {
    final fromStr = AppFormatters.formatDate(widget.from);
    final toStr = AppFormatters.formatDate(widget.to);

    await PdfHelper.printReport(
      context: context,
      title: 'تقرير الخزنة',
      subtitle: 'من $fromStr إلى $toStr',
      headers: [
        ['النوع', 'الوصف', 'التاريخ', 'المبلغ']
      ],
      rows: _movements.map((m) {
        final isDeposit = m.type == 'deposit';
        return [
          isDeposit ? 'دخل' : 'صرف', // String
          (m.description ?? m.type) as String, // String
          AppFormatters.formatDateFromString(m.date), // String
          AppFormatters.formatCurrency(m.amount), // String
        ];
      }).toList(),
      summaryRows: _summary != null
          ? [
              {
                'label': 'إجمالي الدخل',
                'value': AppFormatters.formatCurrency(_summary!['total_in']!)
              },
              {
                'label': 'إجمالي الصرف',
                'value': AppFormatters.formatCurrency(_summary!['total_out']!)
              },
              {
                'label': 'الصافي',
                'value': AppFormatters.formatCurrency(
                    _summary!['total_in']! - _summary!['total_out']!)
              },
            ]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الخزنة'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [_PdfButton(onGeneratePdf: _exportPdf)],
      ),
      body: Column(
        children: [
          if (_summary != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                      child: _SumCard(
                          'إجمالي الدخل',
                          AppFormatters.formatCurrency(_summary!['total_in']!),
                          Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _SumCard(
                          'إجمالي الصرف',
                          AppFormatters.formatCurrency(_summary!['total_out']!),
                          Colors.red)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _SumCard(
                          'الصافي',
                          AppFormatters.formatCurrency(
                              _summary!['total_in']! - _summary!['total_out']!),
                          Colors.blue)),
                ],
              ),
            ),
          Expanded(
            child: _movements.isEmpty
                ? const Center(child: Text('لا توجد حركات في هذه الفترة'))
                : ListView.builder(
                    itemCount: _movements.length,
                    itemBuilder: (ctx, i) {
                      final m = _movements[i];
                      final isDeposit = m.type == 'deposit';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDeposit
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          child: Icon(
                            isDeposit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isDeposit ? Colors.green : Colors.red,
                            size: 18,
                          ),
                        ),
                        title: Text(m.description ?? m.type),
                        subtitle:
                            Text(AppFormatters.formatDateFromString(m.date)),
                        trailing: Text(
                          AppFormatters.formatCurrency(m.amount),
                          style: TextStyle(
                            color: isDeposit ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
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
// ─────────────────────────────── Installments Report ─────────────────────────

class _InstallmentsReport extends StatefulWidget {
  final DateTime from;
  final DateTime to;
  const _InstallmentsReport({required this.from, required this.to});

  @override
  State<_InstallmentsReport> createState() => _InstallmentsReportState();
}

class _InstallmentsReportState extends State<_InstallmentsReport> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dao = InstallmentDao();
      final d = await dao.getInstallmentsWithCustomer();
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf() async {
    double totalMonthly = 0;
    double totalAmount = 0;
    for (final row in _data) {
      totalMonthly += (row['monthly_amount'] as num? ?? 0).toDouble();
      totalAmount += (row['total_price'] as num? ?? 0).toDouble();
    }
    await PdfHelper.printReport(
      context: context,
      title: 'تقرير الأقساط',
      subtitle: 'جميع عقود التقسيط النشطة — ${_data.length} عقد',
      headers: [
        ['المنتج', 'العميل', 'الإجمالي', 'القسط الشهري', 'عدد الأقساط', 'الحالة']
      ],
      rows: _data
          .map((row) {
            final status = row['status'] as String? ?? 'active';
            final statusLabel = status == 'completed' ? 'مكتمل'
                : status == 'overdue' ? 'متأخر' : 'نشط';
            return [
              (row['item_name'] ?? row['product_name'] ?? '') as String,
              row['customer_name'] as String? ?? '-',
              AppFormatters.formatCurrency((row['total_price'] as num? ?? 0).toDouble()),
              AppFormatters.formatCurrency((row['monthly_amount'] as num? ?? 0).toDouble()),
              '${row['num_installments'] ?? 0} قسط',
              statusLabel,
            ];
          })
          .toList(),
      summaryRows: [
        {'label': 'عدد العقود', 'value': '${_data.length}'},
        {'label': 'إجمالي قيمة العقود', 'value': AppFormatters.formatCurrency(totalAmount)},
        {'label': 'مجموع الأقساط الشهرية', 'value': AppFormatters.formatCurrency(totalMonthly)},
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الأقساط'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [_PdfButton(onGeneratePdf: _exportPdf)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
          ? const Center(
              child:
                  Text('لا توجد أقساط', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: _data.length,
              itemBuilder: (ctx, i) {
                final row = _data[i];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      child: const Icon(Icons.payment,
                          color: Colors.orange, size: 20),
                    ),
                    title: Text((row['item_name'] ?? row['product_name'] ?? '') as String,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(row['customer_name'] as String? ?? ''),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormatters.formatCurrency(
                              (row['monthly_amount'] as num).toDouble()),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                        ),
                        Text('${row['num_installments']} قسط',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────── Blocked Items ───────────────────────────────

class _BlockedItemsReport extends StatelessWidget {
  const _BlockedItemsReport();

  @override
  Widget build(BuildContext context) {
    final items = context
        .watch<InventoryProvider>()
        .items
        .where((i) => i.isBlocked)
        .toList();

    Future<void> exportPdf() async {
      await PdfHelper.printReport(
        context: context,
        title: 'المنتجات الموقوفة',
        subtitle: '${items.length} منتج موقوف',
        headers: [
          ['الصنف', 'الباركود', 'الكمية']
        ],
        rows: items
            .map((item) => [
                  item.name,
                  item.barcode ?? '-',
                  item.quantity.toString(),
                ])
            .toList(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات الموقوفة'),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        actions: [
          Builder(builder: (ctx) => _PdfButton(onGeneratePdf: exportPdf)),
        ],
      ),
      body: items.isEmpty
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green),
              SizedBox(height: 8),
              Text('لا توجد منتجات موقوفة',
                  style: TextStyle(color: Colors.green)),
            ]))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1AFF0000),
                    child: Icon(Icons.block, color: Colors.red, size: 18),
                  ),
                  title: Text(item.name),
                  subtitle: Text(item.barcode ?? ''),
                  trailing: Text('كمية: ${item.quantity}',
                      style: const TextStyle(color: Colors.grey)),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────── Shared Widgets ──────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _SummaryRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _SumCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SumCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
