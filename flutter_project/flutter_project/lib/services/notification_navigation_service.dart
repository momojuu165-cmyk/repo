import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationNavigationService {
  static const String _pendingPayloadKey = 'pending_notification_payload';
  static const String _lastProcessedNotificationIdKey = 'last_notification_id';

  static GlobalKey<NavigatorState>? navigatorKey;

  static void bindNavigator(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  static String buildPayload({
    required String title,
    required String body,
    String? referenceType,
    int? referenceId,
  }) {
    return jsonEncode({
      'title': title,
      'body': body,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'route': _routeForType(referenceType),
    });
  }

  static String _routeForType(String? referenceType) {
    switch (referenceType) {
      case 'request':
        return '/requests';
      case 'invoice':
        return '/customer-invoices';
      case 'installment':
        return '/installments';
      case 'payment':
        return '/treasury';
      default:
        return '/notifications';
    }
  }

  static Future<void> persistPayload(String? payload) async {
    if (payload == null || payload.trim().isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingPayloadKey, payload);
  }

  static Future<void> clearPendingPayload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingPayloadKey);
  }

  static Future<void> recordProcessedNotification(int notificationId) async {
    if (notificationId <= 0) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_lastProcessedNotificationIdKey) ?? 0;
    if (notificationId > current) {
      await prefs.setInt(_lastProcessedNotificationIdKey, notificationId);
    }
  }

  static Future<int> getLastProcessedNotificationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastProcessedNotificationIdKey) ?? 0;
  }

  static Future<void> handlePayload(String? payload) async {
    if (payload == null || payload.trim().isEmpty) {
      return;
    }

    final decoded = _decodePayload(payload);
    if (decoded == null) {
      return;
    }

    final nav = navigatorKey?.currentState;
    if (nav == null) {
      await persistPayload(payload);
      return;
    }

    await clearPendingPayload();
    _navigate(nav, decoded);
  }

  static Future<void> consumePendingPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_pendingPayloadKey);
    if (payload == null || payload.trim().isEmpty) {
      return;
    }

    final decoded = _decodePayload(payload);
    if (decoded == null) {
      await prefs.remove(_pendingPayloadKey);
      return;
    }

    final nav = navigatorKey?.currentState;
    if (nav == null) {
      return;
    }

    await prefs.remove(_pendingPayloadKey);
    _navigate(nav, decoded);
  }

  static Map<String, dynamic>? _decodePayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  static void _navigate(NavigatorState navigator, Map<String, dynamic> payload) {
    final route = payload['route'] as String? ?? '/notifications';
    try {
      navigator.pushNamed(route, arguments: payload);
    } catch (_) {}
  }
}
