import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  String? _fcmToken;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      // Request permission for notifications
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✓ User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('✓ User granted provisional notification permission');
      } else {
        debugPrint('⚠ User declined notification permission');
        return;
      }

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        debugPrint('✓ FCM Token: $_fcmToken');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('✓ FCM Token refreshed: $newToken');
        _saveFcmToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages (when app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Save FCM token to user document
  Future<void> saveFcmToken(String userId) async {
    if (_fcmToken == null) {
      _fcmToken = await _messaging.getToken();
    }

    if (_fcmToken != null) {
      await _saveFcmToken(_fcmToken!);
    }
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      // This will be called from saveFcmToken with userId
      // For now, we'll save it when we have the userId
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Save FCM token to user document in Firestore
  Future<void> saveFcmTokenForUser(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error saving FCM token for user: $e');
    }
  }

  /// Get FCM token for a user
  Future<String?> getFcmTokenForUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['fcmToken'] as String?;
    } catch (e) {
      debugPrint('Error getting FCM token for user: $e');
      return null;
    }
  }

  /// Send a notification via Cloud Function
  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Create notification document in Firestore
      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: type,
        title: title,
        body: body,
        data: data,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());

      // Send push notification via Cloud Function
      await _functions.httpsCallable('sendPushNotification').call({
        'userId': userId,
        'title': title,
        'body': body,
        'data': {
          'type': type.name,
          ...?data,
        },
      });

      debugPrint('✓ Notification sent to user $userId: $title');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Send notification to multiple users
  Future<void> sendNotificationToUsers({
    required List<String> userIds,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    for (final userId in userIds) {
      await sendNotification(
        userId: userId,
        type: type,
        title: title,
        body: body,
        data: data,
      );
    }
  }

  /// Get notifications for a user (stream)
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data()))
            .toList());
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.notification?.title}');
    // You can show a local notification or update UI here
  }

  /// Handle background messages (when app is opened from notification)
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('Background message opened: ${message.notification?.title}');
    // Handle navigation based on notification data
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;
}

/// Top-level function for handling background messages
/// This must be a top-level function to be used as a background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.notification?.title}');
  // Handle background notification here if needed
}

