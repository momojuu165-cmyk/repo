import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../database/daos/customer_invoice_dao.dart';
import '../../../database/daos/installment_dao.dart';
import '../../../models/customer_invoice.dart';
import '../../../models/installment.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../utils/whatsapp_helper.dart';
import '../../../services/push_notification_service.dart';
import '../../../utils/pdf_helper.dart';
import 'package:printing/printing.dart';
import '../../../utils/notification_messages.dart';

class CustomerInvoicesAdminScreen extends StatefulWidget {
  final String? storeType;
  const CustomerInvoicesAdminScreen({super.key, this.storeType});
  @override
  State<CustomerInvoicesAdminScreen> createState() => _CustomerInvoicesAdminScreenState();
}

class _CustomerInvoicesAdminScreenState extends State<CustomerInvoicesAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _dao = CustomerInvoiceDao();
  Map<String, List<CustomerInvoice>> _byStatus = {
    'pending': [], 'approved': [], 'rejected': []
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final storeType = auth.effectiveStoreType(widget.storeType);
      final all = await _dao.getAll(storeType: storeType);
      final map = <String, List<CustomerInvoice>>{
        'pending': [], 'approved': [], 'rejected': [], 'delivered': []
      };
    for (final inv in all) {
      (map[inv.status] ?? map['pending']!).add(inv);
    }
    if (mounted) setState(() { _byStatus = map; _loading = false; });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
}

  @override
  Widget build(BuildContext context) {
    final pendingCount = _byStatus['pending']?.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('فواتير العملاء'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(AppColors.primaryInt), Color(AppColors.primary2Int)],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('انتظار'),
              if (pendingCount > 0) ...[
                const SizedBox(width: 4),
                CircleAvatar(radius: 9, backgroundColor: Colors.red,
                    child: Text('$pendingCount',
                        style: const TextStyle(fontSize: 10, color: Colors.white))),
              ],
            ])),
            const Tab(text: 'مقبول'),
            const Tab(text: 'مرفوض'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _InvoiceList(invoices: _byStatus['pending'] ?? [], dao: _dao, onRefresh: _load,
                    showActions: true),
                _InvoiceList(invoices: _byStatus['approved'] ?? [], dao: _dao, onRefresh: _load,
                    showActions: true),
                _InvoiceList(invoices: _byStatus['rejected'] ?? [], dao: _dao, onRefresh: _load,
                    showActions: false),
              ],
            ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  final List<CustomerInvoice> invoices;
  final CustomerInvoiceDao dao;
  final Future<void> Function() onRefresh;
  final bool showActions;

  const _InvoiceList({
    required this.invoices, required this.dao, required this.onRefresh,
    required this.showActions,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Text('لا توجد فواتير', style: TextStyle(color: Colors.grey)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: invoices.length,
        itemBuilder: (ctx, i) {
          final inv = invoices[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: _statusColor(inv.status).withValues(alpha: 0.12),
                child: Icon(_statusIcon(inv.status),
                    color: _statusColor(inv.status), size: 20),
              ),
              title: Text(inv.invoiceNo,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(inv.customerName ?? 'عميل ${inv.customerId}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(AppFormatters.formatDateFromString(inv.date),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(AppFormatters.formatCurrency(inv.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(inv.paymentMethodLabel,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Items
                    ...inv.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        const Icon(Icons.fiber_manual_record, size: 8, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(child: Text(item.itemName, style: const TextStyle(fontSize: 13))),
                        Text('${item.qty.toStringAsFixed(0)} × ${AppFormatters.formatCurrency(item.unitPrice)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 8),
                        Text(AppFormatters.formatCurrency(item.total),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                    )),
                    if (inv.notes != null && inv.notes!.isNotEmpty) ...[
                      const Divider(),
                      Text('ملاحظات: ${inv.notes}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                    // Receipt image
                    if (inv.receiptPath != null) ...[
                      const Divider(),
                      const Text('إيصال الدفع:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(inv.receiptPath!),
                            height: 150, width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Text(
                                'لا يمكن تحميل الصورة', style: TextStyle(color: Colors.grey))),
                      ),
                    ],
                    if (showActions) ...[
                      const Divider(),
                      Row(children: [
                        if (inv.status == 'pending' || inv.status == 'approved') ...[
                          Expanded(child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                            onPressed: () async {
                              await dao.updateStatus(inv.id!, 'rejected');
                              onRefresh();
                            },
                            icon: const Icon(Icons.cancel, size: 16),
                            label: const Text('رفض', style: TextStyle(fontSize: 12)),
                          )),
                          const SizedBox(width: 8),
                        ],
                        if (inv.status == 'pending') ...[
                          Expanded(child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () async {
                              await dao.updateStatus(inv.id!, 'approved');
                              onRefresh();
                            },
                            icon: const Icon(Icons.check_circle, size: 16),
                            label: const Text('قبول', style: TextStyle(fontSize: 12)),
                          )),
                          const SizedBox(width: 8),
                        ],
                        if (inv.status == 'approved')
                          Expanded(child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue, foregroundColor: Colors.white),
                            onPressed: () async {
                              await dao.updateStatus(inv.id!, 'delivered');
                              onRefresh();
                            },
                            icon: const Icon(Icons.local_shipping, size: 16),
                            label: const Text('تم التسليم', style: TextStyle(fontSize: 12)),
                          )),
                        if (inv.customerPhone != null)
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.green),
                            tooltip: 'تواصل على واتساب',
                            onPressed: () => WhatsAppHelper.sendMessage(
                              phone: inv.customerPhone!,
                              message: 'مرحباً، بخصوص طلبك رقم ${inv.invoiceNo}',
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.print, color: Colors.black87),
                          tooltip: 'طباعة الفاتورة',
                          onPressed: () async {
                            try {
                              final items = inv.items.map((it) => {
                                'name': it.itemName,
                                'qty': it.qty.toInt(),
                                'price': it.unitPrice,
                                'total': it.total,
                              }).toList();
                              final bytes = await PdfHelper.generateInvoicePdf(
                                invoiceNo: inv.invoiceNo ?? '${inv.id}',
                                date: inv.date ?? '',
                                customerName: inv.customerName ?? 'عميل',
                                paymentType: inv.paymentMethodLabel,
                                items: items,
                                subtotal: inv.total,
                                discount: inv.discount ?? 0,
                                total: inv.total,
                                paid: inv.amountPaid ?? 0,
                                remaining: inv.remaining ?? 0,
                              );
                              await Printing.layoutPdf(onLayout: (_) async => bytes);
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ أثناء الطباعة: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                        ),
                      ]),
                    ],
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Issue 14: Create installment plan after approving invoice ───────────────
  static Future<void> _showInstallmentDialog(
      BuildContext context, CustomerInvoice inv, CustomerInvoiceDao dao) async {
    final monthsCtrl = TextEditingController(text: '12');
    final downCtrl = TextEditingController(text: '0');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنشاء خطة تقسيط'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('هل تريد إنشاء خطة تقسيط لهذا الطلب؟ (${AppFormatters.formatCurrency(inv.total)})', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: monthsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد الأشهر', isDense: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: downCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الدفعة الأولى', isDense: true),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تخطي')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    if (result != true || !context.mounted) return;
    final months = int.tryParse(monthsCtrl.text) ?? 12;
    final down = double.tryParse(downCtrl.text) ?? 0;
    final now = DateTime.now();
    final monthly = months > 0 ? ((inv.total - down) / months) : 0.0;
    final installment = Installment(
      customerId: inv.customerId,
      invoiceId: inv.id,
      productName: inv.invoiceNo,
      purchasePrice: inv.total,
      salePrice: inv.total,
      totalInstallmentPrice: inv.total,
      downPayment: down,
      numInstallments: months,
      monthlyAmount: monthly.toDouble(),
      startDate: now.toIso8601String().substring(0, 10),
      storeType: AppConstants.storeElectrical,
      createdAt: now.toIso8601String(),
    );
    try {
      await InstallmentDao().insertInstallment(installment);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء خطة التقسيط ✓'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
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
