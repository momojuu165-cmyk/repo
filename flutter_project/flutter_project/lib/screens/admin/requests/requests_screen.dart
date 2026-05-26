import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../database/daos/customer_invoice_dao.dart';
import '../../../database/daos/request_dao.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';

import '../customer_invoices/customer_invoices_admin_screen.dart';

class RequestsScreen extends StatefulWidget {
  final String? storeType;
  const RequestsScreen({super.key, this.storeType});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  final _dao = RequestDao();
  late final TabController _tabCtrl;

  Color _themeColorFor(String? storeType) {
    switch (storeType) {
      case AppConstants.storeElectrical:
        return const Color(AppColors.electricalInt);
      case AppConstants.storeClothing:
        return const Color(AppColors.clothingInt);
      case AppConstants.storeMobiles:
        return const Color(AppColors.mobilesInt);
      case AppConstants.storeAccessories:
        return const Color(AppColors.accessoriesInt);
      default:
        return const Color(AppColors.installmentInt);
    }
  }

  String _titleFor(String? storeType) {
    final label = storeType == null ? null : AppConstants.storeLabels[storeType];
    return label != null ? 'فواتير — $label' : 'فواتير العملاء';
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final resolvedStoreType = auth.effectiveStoreType(widget.storeType);
    final themeColor = _themeColorFor(resolvedStoreType);
    final title = _titleFor(resolvedStoreType);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(
                icon: Icon(Icons.hourglass_top, size: 16),
                text: 'قيد الانتظار'),
            Tab(
                icon: Icon(Icons.check_circle_outline, size: 16),
                text: 'مقبولة'),
            Tab(icon: Icon(Icons.cancel_outlined, size: 16), text: 'مرفوضة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _RequestsList(
            dao: _dao,
            status: AppConstants.requestStatusPending,
            storeType: resolvedStoreType,
            themeColor: themeColor,
          ),
          _RequestsList(
            dao: _dao,
            status: AppConstants.requestStatusApproved,
            storeType: resolvedStoreType,
            themeColor: themeColor,
          ),
          _RequestsList(
            dao: _dao,
            status: AppConstants.requestStatusRejected,
            storeType: resolvedStoreType,
            themeColor: themeColor,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RequestsList extends StatefulWidget {
  final RequestDao dao;
  final String status;
  final String? storeType;
  final Color themeColor;

  const _RequestsList({
    required this.dao,
    required this.status,
    required this.themeColor,
    this.storeType,
  });

  @override
  State<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends State<_RequestsList> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  final _invoiceDao = CustomerInvoiceDao();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final requestList = await widget.dao.getAllWithCustomer(
          status: widget.status, storeType: widget.storeType);
      final invoiceList =
          await _invoiceDao.getAllForRequests(storeType: widget.storeType);

      final filteredInvoices = invoiceList.where((row) {
        final status = row['status'] as String? ?? '';
        if (widget.status == AppConstants.requestStatusApproved) {
          return status == AppConstants.requestStatusApproved;
        }
        return status == widget.status;
      }).toList();

      final merged = <Map<String, dynamic>>[
        ...requestList.map((row) => {...row, 'source': 'request'}),
        ...filteredInvoices.map((row) => {...row, 'source': 'invoice'}),
      ];

      merged.sort((a, b) {
        final left = (a['created_at'] as String? ?? a['date'] as String? ?? '');
        final right =
            (b['created_at'] as String? ?? b['date'] as String? ?? '');
        return right.compareTo(left);
      });

      if (mounted) {
        setState(() {
          _requests = merged;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Accept with optional discount ────────────────────────────────────────
  Future<void> _accept(Map<String, dynamic> r) async {
    final discCtrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionSheet(
        title: 'قبول الطلب',
        icon: Icons.check_circle,
        iconColor: Colors.green,
        productName: r['product_name'] as String,
        customerName: r['customer_name'] as String? ?? '-',
        confirmLabel: 'قبول الطلب',
        confirmColor: Colors.green,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: discCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'خصم الأدمن (اختياري %)',
              prefixIcon: const Icon(Icons.discount_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: '0',
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final disc = double.tryParse(discCtrl.text.trim()) ?? 0;
    await widget.dao.updateStatus(
      r['id'] as int,
      AppConstants.requestStatusApproved,
      adminDiscount: disc > 0 ? disc : null,
    );
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✓ تم قبول الطلب'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // ── Reject with optional reason ───────────────────────────────────────────
  Future<void> _reject(Map<String, dynamic> r) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionSheet(
        title: 'رفض الطلب',
        icon: Icons.cancel,
        iconColor: Colors.red,
        productName: r['product_name'] as String,
        customerName: r['customer_name'] as String? ?? '-',
        confirmLabel: 'رفض الطلب',
        confirmColor: Colors.red,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: reasonCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'سبب الرفض (اختياري)',
              prefixIcon: const Icon(Icons.comment_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'اكتب سبب الرفض ليصله العميل…',
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final reason = reasonCtrl.text.trim();
    await widget.dao.updateStatus(
      r['id'] as int,
      AppConstants.requestStatusRejected,
      rejectReason: reason.isNotEmpty ? reason : null,
    );
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('تم رفض الطلب'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requests.isEmpty) {
      return _EmptyState(status: widget.status, themeColor: widget.themeColor);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: widget.themeColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        itemCount: _requests.length,
        itemBuilder: (ctx, i) {
          final r = _requests[i];
          final source = r['source'] as String? ?? 'request';
          if (source == 'invoice') {
            return _InvoiceRequestCard(
              data: r,
              themeColor: widget.themeColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerInvoicesAdminScreen(),
                  ),
                );
              },
            );
          }

          return _RequestCard(
            data: r,
            themeColor: widget.themeColor,
            isPending: widget.status == AppConstants.requestStatusPending,
            onAccept: () => _accept(r),
            onReject: () => _reject(r),
            onTap: () => _showDetail(context, r),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        data: r,
        themeColor: widget.themeColor,
        isPending: widget.status == AppConstants.requestStatusPending,
        onAccept: () {
          Navigator.pop(context);
          _accept(r);
        },
        onReject: () {
          Navigator.pop(context);
          _reject(r);
        },
      ),
    );
  }
}

// ─── Request Card ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color themeColor;
  final bool isPending;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTap;

  const _RequestCard({
    required this.data,
    required this.themeColor,
    required this.isPending,
    required this.onAccept,
    required this.onReject,
    required this.onTap,
  });

  String get _paymentLabel {
    switch (data['payment_method']) {
      case 'in_store':
        return 'داخل المحل';
      case 'receipt':
        return 'إيصال';
      default:
        return data['payment_method'] as String? ?? '-';
    }
  }

  String get _dateLabel {
    final raw = (data['date'] as String?) ?? (data['created_at'] as String?);
    if (raw == null) return '-';
    try {
      return AppFormatters.formatDateFromString(raw);
    } catch (_) {
      return raw.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReceipt = data['receipt_path'] != null;
    final deposit = (data['deposit_amount'] as num?)?.toDouble() ?? 0;
    final installments = data['num_installments'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Coloured header bar ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [themeColor.withValues(alpha: 0.95), themeColor.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['product_name'] as String? ?? '-',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ),
                  if (!isPending)
                    _StatusBadge(data['status'] as String? ?? 'pending'),
                ],
              ),
            ),

            // ── Body info ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                      icon: Icons.person_outline,
                      label: 'العميل',
                      value: data['customer_name'] as String? ?? '-'),
                  if ((data['customer_phone'] as String?) != null)
                    _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'الهاتف',
                        value: data['customer_phone'] as String),
                  _InfoRow(
                      icon: Icons.payment,
                      label: 'الدفع',
                      value: _paymentLabel),
                  if (installments != null)
                    _InfoRow(
                        icon: Icons.calendar_month_outlined,
                        label: 'الأقساط',
                        value: '$installments شهر'),
                  if (deposit > 0)
                    _InfoRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'العربون',
                        value: AppFormatters.formatCurrency(deposit)),
                  _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'التاريخ',
                      value: _dateLabel),
                  if (hasReceipt)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.attach_file,
                              size: 14, color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          Text('إيصال مرفق',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  if ((data['notes'] as String?) != null &&
                      (data['notes'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notes_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              data['notes'] as String,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Action buttons (pending only) ─────────────────────────────
            if (isPending)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('رفض',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('قبول',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color themeColor;
  final VoidCallback onTap;

  const _InvoiceRequestCard({
    required this.data,
    required this.themeColor,
    required this.onTap,
  });

  String get _paymentLabel {
    switch (data['payment_method']) {
      case 'in_store':
        return 'دفع عند الاستلام';
      case 'vodafone_cash':
        return 'فودافون كاش';
      case 'instapay':
        return 'إنستاباي';
      case 'bank_transfer':
        return 'تحويل بنكي';
      default:
        return data['payment_method'] as String? ?? '-';
    }
  }

  String get _dateLabel {
    final raw = (data['date'] as String?) ?? (data['created_at'] as String?);
    if (raw == null) return '-';
    try {
      return AppFormatters.formatDateFromString(raw);
    } catch (_) {
      return raw.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: themeColor,
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['product_name'] as String? ?? 'فاتورة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      color: Colors.white.withValues(alpha: 0.9), size: 15),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'العميل',
                    value: data['customer_name'] as String? ?? '-',
                  ),
                  if ((data['customer_phone'] as String?) != null)
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'الهاتف',
                      value: data['customer_phone'] as String,
                    ),
                  _InfoRow(
                    icon: Icons.payment,
                    label: 'طريقة الدفع',
                    value: _paymentLabel,
                  ),
                  _InfoRow(
                    icon: Icons.attach_money,
                    label: 'الإجمالي',
                    value: AppFormatters.formatCurrency(total),
                  ),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'التاريخ',
                    value: _dateLabel,
                  ),
                  if ((data['notes'] as String?) != null &&
                      (data['notes'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notes_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              data['notes'] as String,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail bottom sheet ──────────────────────────────────────────────────────

class _DetailSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color themeColor;
  final bool isPending;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _DetailSheet({
    required this.data,
    required this.themeColor,
    required this.isPending,
    required this.onAccept,
    required this.onReject,
  });

  String get _paymentLabel {
    switch (data['payment_method']) {
      case 'in_store':
        return 'داخل المحل';
      case 'receipt':
        return 'رفع إيصال';
      default:
        return data['payment_method'] as String? ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final deposit = (data['deposit_amount'] as num?)?.toDouble() ?? 0;
    final installments = data['num_installments'] as int?;
    final discount = (data['admin_discount'] as num?)?.toDouble() ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: themeColor.withValues(alpha: 0.12),
                  child: Icon(Icons.inventory_2_outlined,
                      color: themeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['product_name'] as String? ?? '-',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17)),
                        Text('تفاصيل الطلب',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                      ]),
                ),
                _StatusBadge(data['status'] as String? ?? 'pending'),
              ]),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  _DetailGroup(title: 'بيانات العميل', items: [
                    _DetailItem(
                        icon: Icons.person,
                        label: 'الاسم',
                        value: data['customer_name'] as String? ?? '-'),
                    if ((data['customer_phone'] as String?) != null)
                      _DetailItem(
                          icon: Icons.phone,
                          label: 'الهاتف',
                          value: data['customer_phone'] as String),
                  ]),
                  const SizedBox(height: 16),
                  _DetailGroup(title: 'تفاصيل الطلب', items: [
                    _DetailItem(
                        icon: Icons.payment,
                        label: 'طريقة الدفع',
                        value: _paymentLabel),
                    if (installments != null)
                      _DetailItem(
                          icon: Icons.calendar_month,
                          label: 'عدد الأقساط',
                          value: '$installments شهر'),
                    if (deposit > 0)
                      _DetailItem(
                          icon: Icons.account_balance_wallet,
                          label: 'مبلغ العربون',
                          value: AppFormatters.formatCurrency(deposit)),
                    if (discount > 0)
                      _DetailItem(
                          icon: Icons.discount,
                          label: 'خصم الأدمن',
                          value: '$discount %',
                          valueColor: Colors.green),
                    _DetailItem(
                        icon: Icons.calendar_today,
                        label: 'تاريخ الطلب',
                        value: () {
                          final raw = (data['date'] as String?) ??
                              (data['created_at'] as String?);
                          if (raw == null) return '-';
                          try {
                            return AppFormatters.formatDateFromString(raw);
                          } catch (_) {
                            return raw.substring(0, 10);
                          }
                        }()),
                  ]),
                  if ((data['notes'] as String?) != null &&
                      (data['notes'] as String).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _DetailGroup(title: 'ملاحظات', items: [
                      _DetailItem(
                          icon: Icons.notes,
                          label: '',
                          value: data['notes'] as String),
                    ]),
                  ],
                  if ((data['reject_reason'] as String?) != null &&
                      (data['reject_reason'] as String).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.red.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('سبب الرفض',
                                    style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(data['reject_reason'] as String,
                                    style: TextStyle(
                                        color: Colors.red.shade800,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (data['receipt_path'] != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.attach_file,
                            color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('إيصال دفع مرفق بالطلب',
                              style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            // Action buttons
            if (isPending)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.cancel, size: 20),
                        label: const Text('رفض الطلب',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: const Text('قبول الطلب',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Action confirmation bottom sheet ────────────────────────────────────────

class _ActionSheet extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String productName;
  final String customerName;
  final Widget child;
  final String confirmLabel;
  final Color confirmColor;

  const _ActionSheet({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.productName,
    required this.customerName,
    required this.child,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<_ActionSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(children: [
              CircleAvatar(
                backgroundColor: widget.iconColor.withValues(alpha: 0.12),
                radius: 22,
                child: Icon(widget.icon, color: widget.iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
                Text(widget.productName,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ]),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text('العميل: ${widget.customerName}',
                    style: const TextStyle(fontSize: 13)),
              ]),
            ),
            widget.child,
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('إلغاء',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.confirmColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(widget.confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String status;
  final Color themeColor;
  const _EmptyState({required this.status, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String message;
    switch (status) {
      case AppConstants.requestStatusApproved:
        icon = Icons.check_circle_outline;
        message = 'لا توجد طلبات مقبولة';
        break;
      case AppConstants.requestStatusRejected:
        icon = Icons.cancel_outlined;
        message = 'لا توجد طلبات مرفوضة';
        break;
      default:
        icon = Icons.inbox_outlined;
        message = 'لا توجد طلبات معلقة';
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 64, color: themeColor.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text(message,
            style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('اسحب للأسفل للتحديث',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      ]),
    );
  }
}

// ─── Shared helper widgets ────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 5),
        Text('$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _DetailGroup extends StatelessWidget {
  final String title;
  final List<_DetailItem> items;
  const _DetailGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey.shade500)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: items
              .asMap()
              .entries
              .map((e) => Column(children: [
                    if (e.key > 0)
                      Divider(height: 1, color: Colors.grey.shade200),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Icon(e.value.icon,
                            size: 18, color: Colors.grey.shade500),
                        const SizedBox(width: 10),
                        if (e.value.label.isNotEmpty) ...[
                          Text('${e.value.label}: ',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600)),
                        ],
                        Expanded(
                          child: Text(
                            e.value.value,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: e.value.valueColor,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]))
              .toList(),
        ),
      ),
    ]);
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailItem(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
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
      default:
        color = Colors.orange;
        label = 'انتظار';
        icon = Icons.hourglass_top;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
