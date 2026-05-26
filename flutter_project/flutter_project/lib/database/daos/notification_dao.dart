import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_notification.dart';

class NotificationDao {
  SupabaseClient get _client => Supabase.instance.client;

  Future<int> insert(AppNotification n) async {
    try {
      final map = n.toMap()..remove('id');
      final result = await _client
          .from('app_notifications')
          .insert(map)
          .select('id')
          .single();
      return result['id'] as int;
    } catch (_) {
      return -1;
    }
  }

  Future<List<AppNotification>> getForUser(int userId, String? role) async {
    try {
      final results = <AppNotification>[];
      final seen = <int>{};

      // 1. Notifications addressed directly to this user
      if (userId > 0) {
        final r1 = await _client
            .from('app_notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(60);
        for (final m in r1) {
          final n = AppNotification.fromMap(m);
          if (n.id != null && seen.add(n.id!)) results.add(n);
        }
      }

      // 2. Broadcast to this role only (user_id is null, user_role matches)
      if (role != null && role.isNotEmpty) {
        final r2 = await _client
            .from('app_notifications')
            .select()
            .isFilter('user_id', null)
            .eq('user_role', role)
            .order('created_at', ascending: false)
            .limit(60);
        for (final m in r2) {
          final n = AppNotification.fromMap(m);
          if (n.id != null && seen.add(n.id!)) results.add(n);
        }
      }

      // 3. True broadcast — user_id null AND user_role null
      final r3 = await _client
          .from('app_notifications')
          .select()
          .isFilter('user_id', null)
          .isFilter('user_role', null)
          .order('created_at', ascending: false)
          .limit(60);
      for (final m in r3) {
        final n = AppNotification.fromMap(m);
        if (n.id != null && seen.add(n.id!)) results.add(n);
      }

      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results.take(120).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markRead(int id) async {
    try {
      await _client.from('app_notifications').update({'is_read': 1}).eq('id', id);
    } catch (_) {}
  }

  Future<void> markAllRead(int userId, String? role) async {
    try {
      await _client
          .from('app_notifications')
          .update({'is_read': 1})
          .eq('user_id', userId)
          .eq('is_read', 0);
      if (role != null) {
        await _client
            .from('app_notifications')
            .update({'is_read': 1})
            .eq('user_role', role)
            .isFilter('user_id', null)
            .eq('is_read', 0);
      }
    } catch (_) {}
  }

  Future<int> getUnreadCount(int userId, String? role) async {
    try {
      final byUser = await _client
          .from('app_notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', 0);
      int count = byUser.length;
      if (role != null) {
        final byRole = await _client
            .from('app_notifications')
            .select('id')
            .eq('user_role', role)
            .isFilter('user_id', null)
            .eq('is_read', 0);
        count += byRole.length;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  // ── Targeted: one specific user ───────────────────────────────────────────
  // Returns the inserted row ID (or -1 on failure) so callers can suppress
  // the notification from appearing on the SENDER's own device.
  Future<int> sendToUser({
    required int userId,
    required String title,
    required String body,
    String type = 'general',
    int? referenceId,
    String? referenceType,
  }) async {
    try {
      return await insert(AppNotification(
        userId: userId,
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now().toIso8601String(),
        referenceId: referenceId,
        referenceType: referenceType,
      ));
    } catch (_) {
      return -1;
    }
  }

  // ── Role broadcast: all users of a given role ─────────────────────────────
  Future<int> sendToRole({
    required String userRole,
    required String title,
    required String body,
    String type = 'general',
    int? referenceId,
    String? referenceType,
  }) async {
    try {
      return await insert(AppNotification(
        userRole: userRole,
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now().toIso8601String(),
        referenceId: referenceId,
        referenceType: referenceType,
      ));
    } catch (_) {
      return -1;
    }
  }

  // ── True broadcast: every user ────────────────────────────────────────────
  Future<int> sendToAll({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    try {
      return await insert(AppNotification(
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now().toIso8601String(),
      ));
    } catch (_) {
      return -1;
    }
  }
}
