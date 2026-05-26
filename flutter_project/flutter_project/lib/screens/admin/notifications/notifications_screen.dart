import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/app_notification.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/constants.dart';
import '../requests/requests_screen.dart';
import '../customer_invoices/customer_invoices_admin_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NotificationProvider>();
    final all = np.notifications;
    final unread = all.where((n) => !n.isRead).toList();
    final read = all.where((n) => n.isRead).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Row(children: [
          const Text('الإشعارات',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          if (np.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12)),
              child: Text('${np.unreadCount}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        backgroundColor: const Color(AppColors.primaryInt),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (np.unreadCount > 0)
            TextButton(
              onPressed: () => np.markAllRead(),
              child: const Text('تحديد الكل كمقروء',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          IconButton(
            icon: np.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: () => np.load(),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'الكل (${all.length})'),
            Tab(text: 'غير مقروء (${unread.length})'),
            Tab(text: 'مقروء (${read.length})'),
          ],
        ),
      ),
      body: np.loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _NotifList(items: all),
                _NotifList(items: unread),
                _NotifList(items: read),
              ],
            ),
      floatingActionButton: _AdminSendFab(),
    );
  }
}

// ─── Notification list ────────────────────────────────────────────────────────
class _NotifList extends StatelessWidget {
  final List<AppNotification> items;
  const _NotifList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none,
                size: 40, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          const Text('لا توجد إشعارات',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('ستظهر إشعاراتك هنا عند وصولها',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final prev = i > 0 ? items[i - 1] : null;
        final showDateHeader = prev == null ||
            !_sameDay(
                DateTime.tryParse(item.createdAt),
                DateTime.tryParse(prev.createdAt));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeader) _DateHeader(item.createdAt),
            _NotifTile(notification: item),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}

// ─── Date section header ──────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String iso;
  const _DateHeader(this.iso);

  String _label() {
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays;
      if (diff == 0) return 'اليوم';
      if (diff == 1) return 'أمس';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        _label(),
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.3),
      ),
    );
  }
}

// ─── Notification tile ────────────────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final AppNotification notification;
  const _NotifTile({required this.notification});

  _TypeMeta get _meta => _TypeMeta.from(notification.type);

  String _timeAgo() {
    try {
      final d = DateTime.parse(notification.createdAt).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
      return 'منذ ${diff.inDays} يوم';
    } catch (_) {
      return '';
    }
  }

  void _deepLink(BuildContext context) {
    final target = notification.referenceType?.isNotEmpty == true
        ? notification.referenceType!
        : notification.type;

    switch (target) {
      case 'request':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RequestsScreen()),
        );
        break;
      case 'invoice':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomerInvoicesAdminScreen()),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final np = context.read<NotificationProvider>();
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: () {
        if (isUnread && notification.id != null) np.markRead(notification.id!);
        _deepLink(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: isUnread ? Colors.white : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: isUnread
              ? Border.all(color: _meta.color.withValues(alpha: 0.25), width: 1)
              : null,
          boxShadow: isUnread
              ? [
                  BoxShadow(
                      color: _meta.color.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1))
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: _meta.color.withValues(alpha: isUnread ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(_meta.icon,
                  color: _meta.color.withValues(alpha: isUnread ? 1 : 0.6),
                  size: 21),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 14,
                            color: isUnread
                                ? const Color(0xFF1A1A2E)
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_timeAgo(),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400)),
                      if (isUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: _meta.color,
                                shape: BoxShape.circle)),
                      ],
                    ]),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    // Type chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _meta.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_meta.label,
                          style: TextStyle(
                              fontSize: 10,
                              color: _meta.color,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Type metadata ────────────────────────────────────────────────────────────
class _TypeMeta {
  final IconData icon;
  final Color color;
  final String label;
  const _TypeMeta(this.icon, this.color, this.label);

  static _TypeMeta from(String type) {
    switch (type) {
      case 'request':
        return const _TypeMeta(Icons.request_page, Color(0xFF6366F1), 'طلب');
      case 'installment':
        return const _TypeMeta(
            Icons.receipt_long, Color(0xFF3B82F6), 'تقسيط');
      case 'payment':
        return const _TypeMeta(
            Icons.payments_outlined, Color(0xFF10B981), 'دفع');
      case 'invoice':
        return const _TypeMeta(
            Icons.description_outlined, Color(0xFF8B5CF6), 'فاتورة');
      case 'chat':
        return const _TypeMeta(
            Icons.chat_bubble_outline, Color(0xFFF59E0B), 'رسالة');
      case 'postpone':
        return const _TypeMeta(
            Icons.calendar_month_outlined, Color(0xFFF97316), 'تأجيل');
      case 'product':
        return const _TypeMeta(
            Icons.inventory_2_outlined, Color(0xFF14B8A6), 'منتج');
      default:
        return const _TypeMeta(
            Icons.notifications_outlined, Color(0xFF64748B), 'عام');
    }
  }
}

// ─── Admin send FAB ───────────────────────────────────────────────────────────
class _AdminSendFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.currentUser?.role ?? '';
    if (role != 'admin' && role != 'manager') return const SizedBox.shrink();

    return FloatingActionButton.extended(
      backgroundColor: const Color(AppColors.primaryInt),
      foregroundColor: Colors.white,
      elevation: 3,
      onPressed: () => _showSendSheet(context),
      icon: const Icon(Icons.send_rounded),
      label: const Text('إرسال إشعار',
          style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _showSendSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String target = 'admin';
    String type = 'general';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 20,
              right: 20,
              top: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('إرسال إشعار جديد',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 6),
            Text('سيتم تسليم الإشعار فقط إلى المستلم المحدد',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 20),
            TextFormField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'عنوان الإشعار *',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: bodyCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'نص الإشعار *',
                prefixIcon: const Icon(Icons.message_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: target,
              decoration: InputDecoration(
                labelText: 'المستلم',
                prefixIcon: const Icon(Icons.people_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('المديرين')),
                DropdownMenuItem(value: 'manager', child: Text('المشرفين')),
                DropdownMenuItem(value: 'customer', child: Text('العملاء')),
                DropdownMenuItem(value: 'partner', child: Text('الشركاء')),
                DropdownMenuItem(value: 'all', child: Text('الجميع')),
              ],
              onChanged: (v) => setS(() => target = v ?? 'admin'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              decoration: InputDecoration(
                labelText: 'نوع الإشعار',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('عام')),
                DropdownMenuItem(value: 'payment', child: Text('دفع')),
                DropdownMenuItem(
                    value: 'installment', child: Text('تقسيط')),
                DropdownMenuItem(value: 'invoice', child: Text('فاتورة')),
                DropdownMenuItem(value: 'request', child: Text('طلب')),
              ],
              onChanged: (v) => setS(() => type = v ?? 'general'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primaryInt),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty ||
                      bodyCtrl.text.trim().isEmpty) return;
                  final np = context.read<NotificationProvider>();
                  if (target == 'all') {
                    await np.sendToAll(
                        titleCtrl.text.trim(), bodyCtrl.text.trim(),
                        type: type);
                  } else {
                    await np.sendToRole(target, titleCtrl.text.trim(),
                        bodyCtrl.text.trim(),
                        type: type);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(children: const [
                          Icon(Icons.check_circle,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('تم إرسال الإشعار بنجاح'),
                        ]),
                        backgroundColor: Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('إرسال الإشعار',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
