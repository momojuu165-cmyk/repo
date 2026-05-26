import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/daos/notification_dao.dart';
import '../models/app_notification.dart';
import '../services/local_notification_service.dart';
import '../services/notification_navigation_service.dart';

/// Provides real-time in-app notifications via Supabase Realtime.
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

  final Set<int> _sentByMeIds = {};

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  bool get hasUnread => _unreadCount > 0;

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
      _notifications = all
          .where((n) => n.id == null || !_sentByMeIds.contains(n.id!))
          .toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> _handleIncomingNotification(Map<String, dynamic> data) async {
    final notifId = data['id'] as int?;
    if (notifId != null && _sentByMeIds.contains(notifId)) {
      return;
    }

    final notifUserId = data['user_id'];
    final notifRole = data['user_role'] as String?;
    final isForMe =
        (notifUserId != null &&
            notifUserId.toString() == _currentUserId.toString()) ||
        (notifUserId == null && notifRole != null && notifRole == _currentRole) ||
        (notifUserId == null && notifRole == null);

    if (!isForMe) {
      return;
    }

    final title = data['title'] as String? ?? 'إشعار جديد';
    final body = data['body'] as String? ?? '';
    final referenceType =
        (data['reference_type'] as String?) ?? (data['type'] as String?);
    final referenceId = data['reference_id'] as int?;
    final payload = NotificationNavigationService.buildPayload(
      title: title,
      body: body,
      referenceType: referenceType,
      referenceId: referenceId,
    );

    await _localSvc.showNotification(title: title, body: body, payload: payload);

    if (notifId != null) {
      await NotificationNavigationService.recordProcessedNotification(notifId);
    }
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
              await _handleIncomingNotification(payload.newRecord);
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

  void trackSentId(int id) {
    if (id > 0) _sentByMeIds.add(id);
  }

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
