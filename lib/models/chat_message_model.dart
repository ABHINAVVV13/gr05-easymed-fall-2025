import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String appointmentId;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  ChatMessageModel({
    required this.id,
    required this.appointmentId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] as String,
      appointmentId: map['appointmentId'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String,
      message: map['message'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  ChatMessageModel copyWith({
    String? id,
    String? appointmentId,
    String? senderId,
    String? senderName,
    String? message,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

