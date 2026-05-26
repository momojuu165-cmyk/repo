import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background notification handler — must be top-level
@pragma('vm:entry-point')
void onNotificationBackground(NotificationResponse response) {}

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _notifId = 0;

  static const _channelId = 'store_high_channel';
  static const _channelName = 'إشعارات المتجر';

  Future<void> init() async {
    if (_initialized) return;

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Create a high-importance channel so notifications appear as heads-up
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'إشعارات المتجر الرئيسية',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
          ),
        );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {},
      onDidReceiveBackgroundNotificationResponse: onNotificationBackground,
    );

    _initialized = true;
  }

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'إشعارات المتجر الرئيسية',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showWhen: true,
      // Heads-up display even when screen is on
      fullScreenIntent: false,
      visibility: NotificationVisibility.public,
    );
    const notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(_notifId++, title, body, notifDetails);
  }
}
