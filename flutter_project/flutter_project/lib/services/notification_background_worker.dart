import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../database/daos/notification_dao.dart';
import '../database/daos/user_dao.dart';
import '../utils/constants.dart';
import '../utils/supabase_config.dart';
import 'local_notification_service.dart';
import 'notification_navigation_service.dart';

const String _notificationPollTask = 'notification_poll_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _notificationPollTask) {
      await NotificationBackgroundWorker.run();
    }
    return true;
  });
}

class NotificationBackgroundWorker {
  static Future<void> configure() async {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      _notificationPollTask,
      _notificationPollTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Future<void> run() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    } catch (_) {}

    final localSvc = LocalNotificationService();
    await localSvc.init();

    final prefs = await SharedPreferences.getInstance();
    final sessionType = prefs.getString('session_type');
    final sessionId = prefs.getInt('session_id');

    if (sessionType == null || sessionId == null || sessionId <= 0) {
      return;
    }

    final userId = sessionId;
    final role = sessionType == 'customer'
        ? AppConstants.roleCustomer
        : await _resolveUserRole(sessionId);

    if (role == null) {
      return;
    }

    final notifDao = NotificationDao();
    final notifications = await notifDao.getForUser(userId, role);
    final lastProcessed = await NotificationNavigationService.getLastProcessedNotificationId();

    final pending = notifications
        .where((n) => n.id != null && n.id! > lastProcessed)
        .toList();

    for (final notification in pending) {
      final id = notification.id;
      if (id == null) {
        continue;
      }

      final payload = NotificationNavigationService.buildPayload(
        title: notification.title,
        body: notification.body,
        referenceType: notification.referenceType ?? notification.type,
        referenceId: notification.referenceId,
      );

      await localSvc.showNotification(
        title: notification.title,
        body: notification.body,
        payload: payload,
      );
      await NotificationNavigationService.recordProcessedNotification(id);
    }
  }

  static Future<String?> _resolveUserRole(int userId) async {
    try {
      final user = await UserDao().findById(userId);
      return user?.role;
    } catch (_) {
      return null;
    }
  }
}
