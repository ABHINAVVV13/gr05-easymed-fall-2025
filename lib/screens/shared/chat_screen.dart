import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/appointment_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/appointment_service.dart';
import '../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final appointmentDetailsProvider = StreamProvider.family<AppointmentModel?, String>((ref, appointmentId) {
  return FirebaseFirestore.instance
      .collection('appointments')
      .doc(appointmentId)
      .snapshots()
      .map((doc) {
        if (doc.exists && doc.data() != null) {
          return AppointmentModel.fromMap(doc.data()!);
        }
        return null;
      });
});

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  return AppointmentService();
});

final chatMessagesProvider = StreamProvider.family<List<ChatMessageModel>, String>((ref, appointmentId) {
  final chatService = ref.read(chatServiceProvider);
  return chatService.getMessagesStream(appointmentId);
});

class ChatScreen extends ConsumerStatefulWidget {
  final String appointmentId;

  const ChatScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = ref.read(authStateNotifierProvider).value;
    if (currentUser != null) {
      final chatService = ref.read(chatServiceProvider);
      await chatService.markMessagesAsRead(
        appointmentId: widget.appointmentId,
        userId: currentUser.uid,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) {
      return;
    }

    final currentUser = ref.read(authStateNotifierProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to send messages')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        appointmentId: widget.appointmentId,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 
            (currentUser.userType == UserType.patient ? 'Patient' : 'Doctor'),
        message: _messageController.text.trim(),
      );

      _messageController.clear();
      
      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(timestamp);
    } else {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentAsync = ref.watch(appointmentDetailsProvider(widget.appointmentId));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.appointmentId));
    final currentUser = ref.watch(authStateNotifierProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: appointmentAsync.when(
          data: (appointment) {
            if (appointment == null) {
              return const Text('Chat');
            }
            // Show the other person's name
            if (currentUser?.userType == UserType.patient) {
              return const Text('Chat with Doctor');
            } else {
              return const Text('Chat with Patient');
            }
          },
          loading: () => const Text('Chat'),
          error: (_, __) => const Text('Chat'),
        ),
        automaticallyImplyLeading: true,
      ),
      body: appointmentAsync.when(
        data: (appointment) {
          if (appointment == null) {
            return const Center(
              child: Text('Appointment not found'),
            );
          }

          // Check if appointment is in progress
          if (appointment.status != AppointmentStatus.inProgress) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.schedule, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'Appointment is not in progress',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please wait for the doctor to start the appointment.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Messages list
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start the conversation',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isCurrentUser = currentUser?.uid == message.senderId;
                        
                        return Align(
                          alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            child: Column(
                              crossAxisAlignment: isCurrentUser 
                                  ? CrossAxisAlignment.end 
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!isCurrentUser)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Text(
                                      message.senderName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 10.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrentUser
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(18.0),
                                  ),
                                  child: Text(
                                    message.message,
                                    style: TextStyle(
                                      color: isCurrentUser ? Colors.white : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    _formatTimestamp(message.timestamp),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error loading messages: ${error.toString()}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(chatMessagesProvider(widget.appointmentId)),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Message input
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.0),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 10.0,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        IconButton(
                          onPressed: _isSending ? null : _sendMessage,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          appBar: AppBar(title: const Text('Chat')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${error.toString()}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(appointmentDetailsProvider(widget.appointmentId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

