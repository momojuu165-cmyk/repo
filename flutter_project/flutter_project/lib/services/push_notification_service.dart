import 'local_notification_service.dart';
import '../database/daos/notification_dao.dart';

// ─── Push / In-app Notification Service ──────────────────────────────────────
// Saves notifications to Supabase. The Supabase Realtime channel in
// NotificationProvider fires on the RECIPIENT's device and shows the
// local system-tray notification there — not on the sender's device.
//
// Rule: NEVER call _localSvc.showNotification() here. That would pop a
// heads-up alert on the device that's doing the sending (e.g. the admin's
// phone), not on the intended recipient's device.
// ─────────────────────────────────────────────────────────────────────────────

class PushNotificationService {
  static final PushNotificationService _i = PushNotificationService._();
  factory PushNotificationService() => _i;
  PushNotificationService._();

  static final _localSvc = LocalNotificationService();
  static final _dao = NotificationDao();

  /// Call once from main() before runApp.
  static Future<void> initialize() async {
    await _localSvc.init();
  }

  /// No-op: local notifications don't use device tokens.
  Future<void> registerToken({int? userId, int? customerId}) async {}

  /// No-op: nothing to unregister.
  Future<void> unregisterToken() async {}

  // ── Send to a specific user ID ─────────────────────────────────────────────
  static Future<void> sendToUser({
    required int userId,
    required String title,
    required String body,
    String type = 'general',
    int? referenceId,
    String? referenceType,
  }) async {
    try {
      await _dao.sendToUser(
        userId: userId,
        title: title,
        body: body,
        type: type,
        referenceId: referenceId,
        referenceType: referenceType,
      );
    } catch (_) {}
  }

  // ── Send to a specific customer (alias — customer IDs are user IDs) ────────
  static Future<void> sendToCustomer({
    required int customerId,
    required String title,
    required String body,
    String type = 'general',
    int? referenceId,
    String? referenceType,
  }) async {
    await sendToUser(
      userId: customerId,
      title: title,
      body: body,
      type: type,
      referenceId: referenceId,
      referenceType: referenceType,
    );
  }

  // ── Send to all users of a specific role ──────────────────────────────────
  static Future<void> sendToRole({
    required String role,
    required String title,
    required String body,
    String type = 'general',
    int? referenceId,
    String? referenceType,
  }) async {
    try {
      await _dao.sendToRole(
        userRole: role,
        title: title,
        body: body,
        type: type,
        referenceId: referenceId,
        referenceType: referenceType,
      );
    } catch (_) {}
  }

  // ── True broadcast — use sparingly, only for system-wide events ───────────
  static Future<void> broadcast({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    try {
      await _dao.sendToAll(title: title, body: body, type: type);
    } catch (_) {}
  }
}
