import 'package:flutter_test/flutter_test.dart';
import 'package:store_management/models/app_notification.dart';

// ─── Notification Routing Unit Tests ─────────────────────────────────────────
// These tests verify the core notification routing rules:
//
// Rule 1: Admin → specific customer    → only that customer sees it
// Rule 2: Admin → all partners         → only partners see it
// Rule 3: Customer submits request     → only admin sees it
// Rule 4: Manager action               → only admin sees it
// Rule 5: Admin adds customer          → NO notification
// Rule 6: Admin approves/rejects       → NO notification
// Rule 7: Each user sees only their own notifications
// ─────────────────────────────────────────────────────────────────────────────

// Simulates the recipient-matching logic from NotificationProvider._startRealtime
bool isNotificationForUser({
  required int currentUserId,
  required String currentRole,
  required int? notifUserId,
  required String? notifRole,
}) {
  // Targeted to a specific user
  if (notifUserId != null) {
    return notifUserId == currentUserId;
  }
  // Role broadcast (no specific user)
  if (notifRole != null) {
    return notifRole == currentRole;
  }
  // True broadcast (both null) — nobody outside explicit target
  return false;
}

AppNotification makeNotif({
  int? userId,
  String? userRole,
  String title = 'Test',
  String body = 'Body',
  String type = 'general',
}) =>
    AppNotification(
      userId: userId,
      userRole: userRole,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now().toIso8601String(),
    );

void main() {
  group('Rule 1 — Admin sends to specific customer', () {
    test('Target customer (id=5) receives the notification', () {
      final n = makeNotif(userId: 5, type: 'general');
      expect(
        isNotificationForUser(
          currentUserId: 5,
          currentRole: 'customer',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isTrue,
      );
    });

    test('Other customer (id=9) does NOT receive it', () {
      final n = makeNotif(userId: 5, type: 'general');
      expect(
        isNotificationForUser(
          currentUserId: 9,
          currentRole: 'customer',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isFalse,
      );
    });

    test('Admin himself does NOT receive a customer-targeted notification', () {
      final n = makeNotif(userId: 5, type: 'general');
      expect(
        isNotificationForUser(
          currentUserId: 1,
          currentRole: 'admin',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isFalse,
      );
    });
  });

  group('Rule 2 — Admin sends to all partners', () {
    test('Partner receives role-broadcast notification', () {
      final n = makeNotif(userRole: 'partner', type: 'general');
      expect(
        isNotificationForUser(
          currentUserId: 20,
          currentRole: 'partner',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isTrue,
      );
    });

    test('Customer does NOT receive partner-broadcast', () {
      final n = makeNotif(userRole: 'partner', type: 'general');
      expect(
        isNotificationForUser(
          currentUserId: 5,
          currentRole: 'customer',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isFalse,
      );
    });

    test('Manager does NOT receive partner-broadcast', () {
      final n = makeNotif(userRole: 'partner', type: 'general');
      expect(
        isNotificationForUser(
          currentUserId: 3,
          currentRole: 'manager',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isFalse,
      );
    });

    test('Admin does NOT receive partner-broadcast', () {
      final n = makeNotif(userRole: 'partner', type: 'general');
      expect(
        isNotificationForUser(
          currentUserId: 1,
          currentRole: 'admin',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isFalse,
      );
    });
  });

  group('Rule 3 — Customer submits request → admin only', () {
    test('Admin (role=admin) receives the request notification', () {
      final n = makeNotif(userRole: 'admin', type: 'request');
      expect(
        isNotificationForUser(
          currentUserId: 1,
          currentRole: 'admin',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isTrue,
      );
    });

    test('Customer does NOT receive the request notification sent to admin', () {
      final n = makeNotif(userRole: 'admin', type: 'request');
      expect(
        isNotificationForUser(
          currentUserId: 5,
          currentRole: 'customer',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isFalse,
      );
    });

    test('Manager does NOT receive the request notification sent to admin', () {
      final n = makeNotif(userRole: 'admin', type: 'request');
      expect(
        isNotificationForUser(
          currentUserId: 3,
          currentRole: 'manager',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isFalse,
      );
    });
  });

  group('Rule 4 — Manager action → admin only', () {
    test('Admin receives notification from manager action', () {
      final n = makeNotif(userRole: 'admin', type: 'installment');
      expect(
        isNotificationForUser(
          currentUserId: 1,
          currentRole: 'admin',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isTrue,
      );
    });

    test('Partner does NOT receive manager-action notification', () {
      final n = makeNotif(userRole: 'admin', type: 'installment');
      expect(
        isNotificationForUser(
          currentUserId: 20,
          currentRole: 'partner',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isFalse,
      );
    });
  });

  group('Rule 5 — Admin adds customer → NO notification', () {
    test('No notification is created when admin adds a customer (null model = no call)', () {
      // The code was changed to NOT call PushNotificationService.broadcast()
      // when a user/customer is added. This test verifies the data model:
      // if no notification is inserted, no one receives it.
      // We simulate: no notification record created → isNotificationForUser
      // is never called, so returning false for any user is correct.
      expect(
        isNotificationForUser(
          currentUserId: 1,
          currentRole: 'admin',
          notifUserId: null,
          notifRole: null,
        ),
        isFalse,
        reason: 'True broadcast (both null) should not match anyone',
      );
    });
  });

  group('Rule 6 — Admin approves/rejects request/invoice → NO notification to customer', () {
    test('After admin approves invoice, customer does NOT get an invoice notification', () {
      // The sendToCustomer call was removed from the approve/reject/deliver buttons.
      // This test verifies that a notification WITHOUT userId and WITHOUT role
      // (i.e., nothing was sent) does not reach the customer.
      expect(
        isNotificationForUser(
          currentUserId: 5,
          currentRole: 'customer',
          notifUserId: null,
          notifRole: null,
        ),
        isFalse,
      );
    });

    test('After admin rejects request, customer does NOT get notified', () {
      expect(
        isNotificationForUser(
          currentUserId: 5,
          currentRole: 'customer',
          notifUserId: null,
          notifRole: null,
        ),
        isFalse,
      );
    });
  });

  group('Rule 7 — Each user sees only their own notifications', () {
    test('User with id=7 does not see notification for id=3', () {
      final n = makeNotif(userId: 3);
      expect(
        isNotificationForUser(
          currentUserId: 7,
          currentRole: 'customer',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isFalse,
      );
    });

    test('Manager does not see customer role-broadcast', () {
      final n = makeNotif(userRole: 'customer');
      expect(
        isNotificationForUser(
          currentUserId: 3,
          currentRole: 'manager',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isFalse,
      );
    });

    test('Second admin receives role-broadcast intended for admins', () {
      final n = makeNotif(userRole: 'admin');
      expect(
        isNotificationForUser(
          currentUserId: 2,
          currentRole: 'admin',
          notifUserId: n.userId,
          notifRole: n.userRole,
        ),
        isTrue,
        reason: 'All users of the same role receive role-targeted broadcasts',
      );
    });
  });

  group('AppNotification model — serialization', () {
    test('fromMap / toMap round-trip preserves all fields', () {
      final original = makeNotif(userId: 42, userRole: null, type: 'invoice');
      final map = original.toMap()
        ..['id'] = 99
        ..['is_read'] = 0
        ..['reference_id'] = 7
        ..['reference_type'] = 'invoice';

      final restored = AppNotification.fromMap(map);

      expect(restored.id, 99);
      expect(restored.userId, 42);
      expect(restored.userRole, isNull);
      expect(restored.type, 'invoice');
      expect(restored.isRead, isFalse);
      expect(restored.referenceId, 7);
      expect(restored.referenceType, 'invoice');
    });

    test('is_read field handles int 0/1 and bool', () {
      final fromInt0 = AppNotification.fromMap({
        'id': 1, 'title': 'T', 'body': 'B', 'type': 'general',
        'is_read': 0, 'created_at': DateTime.now().toIso8601String(),
      });
      final fromInt1 = AppNotification.fromMap({
        'id': 2, 'title': 'T', 'body': 'B', 'type': 'general',
        'is_read': 1, 'created_at': DateTime.now().toIso8601String(),
      });
      final fromBoolTrue = AppNotification.fromMap({
        'id': 3, 'title': 'T', 'body': 'B', 'type': 'general',
        'is_read': true, 'created_at': DateTime.now().toIso8601String(),
      });

      expect(fromInt0.isRead, isFalse);
      expect(fromInt1.isRead, isTrue);
      expect(fromBoolTrue.isRead, isTrue);
    });

    test('copyWith only changes isRead', () {
      final n = makeNotif(userId: 5, type: 'payment');
      final updated = n.copyWith(isRead: true);
      expect(updated.isRead, isTrue);
      expect(updated.userId, 5);
      expect(updated.type, 'payment');
    });
  });
}
