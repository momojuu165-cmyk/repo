import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/daos/notification_dao.dart';
import '../models/app_notification.dart';
import '../services/local_notification_service.dart';

/// Provides real-time in-app notifications via Supabase Realtime.
///
/// KEY RULE — sender suppression:
///   When THIS device sends a notification (via sendToRole/sendToUser/sendToAll),
///   the inserted row ID is stored in [_sentByMeIds].
///   Any realtime INSERT event or list refresh that matches an ID in that set
///   is silently ignored on THIS device — no phone-tray alert, no list entry.
///   Everyone ELSE who matches the recipient criteria sees it normally.
class NotificationProvider extends ChangeNotifier {
  final NotificationDao _dao = NotificationDao();
  SupabaseClient get _client => Supabase.instance.client;
  final _localSvc = LocalNotificationService();

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;
  RealtimeChannel? _channel;

  int? _currentUserId;
  String? _currentRole;

  /// IDs of notifications sent BY this device in the current session.
  /// These are hidden from the sender's own tray and notification list.
  final Set<int> _sentByMeIds = {};

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  bool get hasUnread => _unreadCount > 0;

  /// Call after login — starts listening for this user's notifications.
  Future<void> init(int userId, String? role) async {
    _currentUserId = userId;
    _currentRole = role;
    await _localSvc.init();
    await load();
    _startRealtime();
  }

  Future<void> load() async {
    if (_currentUserId == null) return;
    _loading = true;
    notifyListeners();
    try {
      final all = await _dao.getForUser(_currentUserId!, _currentRole);
      // Filter out any notifications this device sent — sender should not see them
      _notifications = all
          .where((n) => n.id == null || !_sentByMeIds.contains(n.id!))
          .toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  void _startRealtime() {
    _channel?.unsubscribe();
    _channel = _client
        .channel('public:app_notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'app_notifications',
          callback: (payload) async {
            try {
              final data = payload.newRecord;
              final notifId = data['id'] as int?;

              // If this device sent the notification, suppress it entirely —
              // no tray alert, no list update for this event.
              if (notifId != null && _sentByMeIds.contains(notifId)) {
                return;
              }

              final notifUserId = data['user_id'];
              final notifRole = data['user_role'] as String?;

              // Show phone-tray alert only when this notification is addressed to ME
              final isForMe =
                  (notifUserId != null &&
                      notifUserId.toString() == _currentUserId.toString()) ||
                  (notifUserId == null &&
                      notifRole != null &&
                      notifRole == _currentRole) ||
                  (notifUserId == null && notifRole == null);

              if (isForMe) {
                final title = data['title'] as String? ?? 'إشعار جديد';
                final body = data['body'] as String? ?? '';
                await _localSvc.showNotification(title: title, body: body);
              }
            } catch (_) {}
            await load();
          },
        )
        .subscribe();
  }

  Future<void> markRead(int notificationId) async {
    await _dao.markRead(notificationId);
    _notifications = _notifications
        .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
        .toList();
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    if (_currentUserId == null) return;
    await _dao.markAllRead(_currentUserId!, _currentRole);
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();
  }

  // ── Sender suppression — call this when sending via PushNotificationService ─
  /// Track a notification ID that was sent BY this device so it is suppressed
  /// from appearing in this user's tray and notification list.
  void trackSentId(int id) {
    if (id > 0) _sentByMeIds.add(id);
  }

  // ── Send helpers — capture inserted ID to suppress on sender's device ──────

  Future<void> sendToRole(String role, String title, String body,
      {String type = 'general'}) async {
    final id = await _dao.sendToRole(
        userRole: role, title: title, body: body, type: type);
    if (id > 0) _sentByMeIds.add(id);
  }

  Future<void> sendToUser(int userId, String title, String body,
      {String type = 'general'}) async {
    final id = await _dao.sendToUser(
        userId: userId, title: title, body: body, type: type);
    if (id > 0) _sentByMeIds.add(id);
  }

  Future<void> sendToAll(String title, String body,
      {String type = 'general'}) async {
    final id = await _dao.sendToAll(title: title, body: body, type: type);
    if (id > 0) _sentByMeIds.add(id);
  }

  void reset() {
    _channel?.unsubscribe();
    _channel = null;
    _notifications = [];
    _unreadCount = 0;
    _currentUserId = null;
    _currentRole = null;
    _sentByMeIds.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
