import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send a message in a chat
  Future<void> sendMessage({
    required String appointmentId,
    required String senderId,
    required String senderName,
    required String message,
  }) async {
    try {
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final chatMessage = ChatMessageModel(
        id: messageId,
        appointmentId: appointmentId,
        senderId: senderId,
        senderName: senderName,
        message: message.trim(),
        timestamp: DateTime.now(),
        isRead: false,
      );

      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .collection('messages')
          .doc(messageId)
          .set(chatMessage.toMap());
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Get real-time stream of messages for an appointment
  Stream<List<ChatMessageModel>> getMessagesStream(String appointmentId) {
    return _firestore
        .collection('appointments')
        .doc(appointmentId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessageModel.fromMap(doc.data()))
            .toList());
  }

  /// Get messages for an appointment (one-time fetch)
  Future<List<ChatMessageModel>> getMessages(String appointmentId) async {
    try {
      final snapshot = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => ChatMessageModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get messages: $e');
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead({
    required String appointmentId,
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      // Silently fail - not critical
      print('Failed to mark messages as read: $e');
    }
  }

  /// Get unread message count for an appointment
  Stream<int> getUnreadCountStream({
    required String appointmentId,
    required String userId,
  }) {
    return _firestore
        .collection('appointments')
        .doc(appointmentId)
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}

