import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  String? _fcmToken;
  
  // Expose messaging for token access
  FirebaseMessaging get messaging => _messaging;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      // Initialize local notifications for foreground display
      await _initializeLocalNotifications();

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
        debugPrint('✓ FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
        debugPrint('✓ Full FCM Token: $_fcmToken');
      } else {
        debugPrint('⚠ FCM Token is null - requesting again...');
        await Future.delayed(const Duration(seconds: 1));
        _fcmToken = await _messaging.getToken();
        if (_fcmToken != null) {
          debugPrint('✓ FCM Token obtained on retry: ${_fcmToken!.substring(0, 20)}...');
        } else {
          debugPrint('✗ FCM Token still null after retry');
        }
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('✓ FCM Token refreshed: $newToken');
        _saveFcmToken(newToken);
      });

      // Handle foreground messages - show local notification
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages (when app is opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'easymed_notifications',
        'EasyMed Notifications',
        description: 'Notifications for appointments, messages, and updates',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
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
      debugPrint('📤 Sending notification to user $userId: $title');
      
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
      debugPrint('✓ Notification document created in Firestore');

      // Check if user has FCM token
      final userToken = await getFcmTokenForUser(userId);
      if (userToken == null) {
        debugPrint('⚠ No FCM token found for user $userId - notification will not be delivered');
        debugPrint('⚠ Make sure user has logged in and granted notification permissions');
      } else {
        debugPrint('✓ FCM token found for user $userId');
      }

      // Send push notification via Cloud Function
      try {
        debugPrint('📤 Calling Cloud Function sendPushNotification...');
        final result = await _functions.httpsCallable('sendPushNotification').call({
          'userId': userId,
          'title': title,
          'body': body,
          'data': {
            'type': type.name,
            ...?data,
          },
        });
        debugPrint('✓ Cloud Function called successfully');
        debugPrint('✓ Cloud Function result: $result');
      } catch (e) {
        debugPrint('✗ Error calling Cloud Function: $e');
        debugPrint('✗ Error details: ${e.toString()}');
        // Don't rethrow - we still want the Firestore notification to be saved
      }

      debugPrint('✓ Notification process completed for user $userId: $title');
    } catch (e) {
      debugPrint('✗ Error sending notification: $e');
      debugPrint('✗ Stack trace: ${StackTrace.current}');
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

  /// Handle foreground messages - show local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message received: ${message.notification?.title}');
    
    // Show local notification when app is in foreground
    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'EasyMed',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'easymed_notifications',
        'EasyMed Notifications',
        channelDescription: 'Notifications for appointments, messages, and updates',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: payload,
      );
      debugPrint('✓ Local notification displayed: $title');
    } catch (e) {
      debugPrint('✗ Error showing local notification: $e');
    }
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

