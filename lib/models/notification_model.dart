import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  appointmentBooked,
  appointmentStarted,
  appointmentStatusChanged,
  appointmentCancelled,
  appointmentReminder,
  newMessage,
  paymentCreated,
  paymentCompleted,
  paymentFailed,
  prescriptionCreated,
  prescriptionUpdated,
  stethoscopeUploaded,
  medicalReportUploaded,
  videoCallStarted,
  waitingRoomJoined,
  waitingRoomLeft,
}

class NotificationModel {
  final String id;
  final String userId; // Recipient user ID
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data; // Additional data (appointmentId, etc.)
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'title': title,
      'body': body,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.appointmentBooked,
      ),
      title: map['title'] as String,
      body: map['body'] as String,
      data: map['data'] as Map<String, dynamic>?,
      isRead: (map['isRead'] as bool?) ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

