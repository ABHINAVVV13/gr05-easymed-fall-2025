import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';
import 'auth_service.dart';
import 'doctor_service.dart';

/// Helper class to send notifications for various app events
class NotificationHelper {
  final NotificationService _notificationService;
  final AuthService _authService;
  final DoctorService? _doctorService;

  NotificationHelper({
    required NotificationService notificationService,
    required AuthService authService,
    DoctorService? doctorService,
  })  : _notificationService = notificationService,
        _authService = authService,
        _doctorService = doctorService;

  /// Send notification when appointment is booked
  Future<void> notifyAppointmentBooked({
    required String appointmentId,
    required String patientId,
    required String doctorId,
    required DateTime scheduledTime,
  }) async {
    try {
      final doctor = await _doctorService?.getDoctorById(doctorId);
      final doctorName = doctor?.displayName ?? 'A doctor';
      
      await _notificationService.sendNotification(
        userId: doctorId,
        type: NotificationType.appointmentBooked,
        title: 'New Appointment Booked',
        body: 'You have a new appointment scheduled with a patient on ${_formatDateTime(scheduledTime)}',
        data: {
          'appointmentId': appointmentId,
          'patientId': patientId,
        },
      );
    } catch (e) {
      // Silently fail - notifications shouldn't break the main flow
      debugPrint('Error sending appointment booked notification: $e');
    }
  }

  /// Send notification when appointment is started
  Future<void> notifyAppointmentStarted({
    required String appointmentId,
    required String patientId,
    required String doctorId,
  }) async {
    try {
      final doctor = await _doctorService?.getDoctorById(doctorId);
      final doctorName = doctor?.displayName ?? 'Your doctor';
      
      await _notificationService.sendNotification(
        userId: patientId,
        type: NotificationType.appointmentStarted,
        title: 'Appointment Started',
        body: '$doctorName has started your appointment. You can join now.',
        data: {
          'appointmentId': appointmentId,
          'doctorId': doctorId,
        },
      );
    } catch (e) {
      debugPrint('Error sending appointment started notification: $e');
    }
  }

  /// Send notification when appointment status changes
  Future<void> notifyAppointmentStatusChanged({
    required String appointmentId,
    required String patientId,
    required String doctorId,
    required String status,
  }) async {
    try {
      final statusText = status.replaceAll('_', ' ').toUpperCase();
      
      // Notify both patient and doctor
      await _notificationService.sendNotificationToUsers(
        userIds: [patientId, doctorId],
        type: NotificationType.appointmentStatusChanged,
        title: 'Appointment Status Updated',
        body: 'Appointment status has been updated to: $statusText',
        data: {
          'appointmentId': appointmentId,
          'status': status,
        },
      );
    } catch (e) {
      debugPrint('Error sending appointment status changed notification: $e');
    }
  }

  /// Send notification when appointment is cancelled
  Future<void> notifyAppointmentCancelled({
    required String appointmentId,
    required String patientId,
    required String doctorId,
  }) async {
    try {
      // Notify both patient and doctor
      await _notificationService.sendNotificationToUsers(
        userIds: [patientId, doctorId],
        type: NotificationType.appointmentCancelled,
        title: 'Appointment Cancelled',
        body: 'An appointment has been cancelled.',
        data: {
          'appointmentId': appointmentId,
        },
      );
    } catch (e) {
      debugPrint('Error sending appointment cancelled notification: $e');
    }
  }

  /// Send notification for new chat message
  Future<void> notifyNewMessage({
    required String appointmentId,
    required String senderId,
    required String recipientId,
    required String senderName,
    required String message,
  }) async {
    try {
      await _notificationService.sendNotification(
        userId: recipientId,
        type: NotificationType.newMessage,
        title: 'New Message from $senderName',
        body: message.length > 50 ? '${message.substring(0, 50)}...' : message,
        data: {
          'appointmentId': appointmentId,
          'senderId': senderId,
        },
      );
    } catch (e) {
      debugPrint('Error sending new message notification: $e');
    }
  }

  /// Send notification when payment is created
  Future<void> notifyPaymentCreated({
    required String paymentId,
    required String appointmentId,
    required String patientId,
    required double amount,
  }) async {
    try {
      await _notificationService.sendNotification(
        userId: patientId,
        type: NotificationType.paymentCreated,
        title: 'Payment Required',
        body: 'Please complete payment of \$${amount.toStringAsFixed(2)} for your appointment.',
        data: {
          'paymentId': paymentId,
          'appointmentId': appointmentId,
        },
      );
    } catch (e) {
      debugPrint('Error sending payment created notification: $e');
    }
  }

  /// Send notification when payment is completed
  Future<void> notifyPaymentCompleted({
    required String paymentId,
    required String appointmentId,
    required String patientId,
    required String doctorId,
    required double amount,
  }) async {
    try {
      // Notify both patient and doctor
      await _notificationService.sendNotificationToUsers(
        userIds: [patientId, doctorId],
        type: NotificationType.paymentCompleted,
        title: 'Payment Completed',
        body: 'Payment of \$${amount.toStringAsFixed(2)} has been completed successfully.',
        data: {
          'paymentId': paymentId,
          'appointmentId': appointmentId,
        },
      );
    } catch (e) {
      debugPrint('Error sending payment completed notification: $e');
    }
  }

  /// Send notification when payment fails
  Future<void> notifyPaymentFailed({
    required String paymentId,
    required String appointmentId,
    required String patientId,
  }) async {
    try {
      await _notificationService.sendNotification(
        userId: patientId,
        type: NotificationType.paymentFailed,
        title: 'Payment Failed',
        body: 'Your payment could not be processed. Please try again.',
        data: {
          'paymentId': paymentId,
          'appointmentId': appointmentId,
        },
      );
    } catch (e) {
      debugPrint('Error sending payment failed notification: $e');
    }
  }

  /// Send notification when prescription is created
  Future<void> notifyPrescriptionCreated({
    required String prescriptionId,
    required String appointmentId,
    required String patientId,
    required String doctorId,
  }) async {
    try {
      final doctor = await _doctorService?.getDoctorById(doctorId);
      final doctorName = doctor?.displayName ?? 'Your doctor';
      
      await _notificationService.sendNotification(
        userId: patientId,
        type: NotificationType.prescriptionCreated,
        title: 'New Prescription',
        body: '$doctorName has prescribed new medications for you.',
        data: {
          'prescriptionId': prescriptionId,
          'appointmentId': appointmentId,
        },
      );
    } catch (e) {
      debugPrint('Error sending prescription created notification: $e');
    }
  }

  /// Send notification when prescription is updated
  Future<void> notifyPrescriptionUpdated({
    required String prescriptionId,
    required String appointmentId,
    required String patientId,
    required String doctorId,
  }) async {
    try {
      await _notificationService.sendNotification(
        userId: patientId,
        type: NotificationType.prescriptionUpdated,
        title: 'Prescription Updated',
        body: 'Your prescription has been updated.',
        data: {
          'prescriptionId': prescriptionId,
          'appointmentId': appointmentId,
        },
      );
    } catch (e) {
      debugPrint('Error sending prescription updated notification: $e');
    }
  }

  /// Send notification when stethoscope recording is uploaded
  Future<void> notifyStethoscopeUploaded({
    required String recordingId,
    required String patientId,
    required String? doctorId,
  }) async {
    try {
      if (doctorId != null) {
        await _notificationService.sendNotification(
          userId: doctorId,
          type: NotificationType.stethoscopeUploaded,
          title: 'New Stethoscope Recording',
          body: 'A patient has uploaded a new stethoscope recording for review.',
          data: {
            'recordingId': recordingId,
            'patientId': patientId,
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending stethoscope uploaded notification: $e');
    }
  }

  /// Send notification when medical report is uploaded
  Future<void> notifyMedicalReportUploaded({
    required String reportId,
    required String patientId,
    required String? doctorId,
  }) async {
    try {
      if (doctorId != null) {
        await _notificationService.sendNotification(
          userId: doctorId,
          type: NotificationType.medicalReportUploaded,
          title: 'New Medical Report',
          body: 'A patient has uploaded a new medical report.',
          data: {
            'reportId': reportId,
            'patientId': patientId,
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending medical report uploaded notification: $e');
    }
  }

  /// Send notification when patient joins waiting room
  Future<void> notifyWaitingRoomJoined({
    required String appointmentId,
    required String patientId,
    required String doctorId,
  }) async {
    try {
      final patient = await _authService.getUserData(patientId);
      final patientName = patient?.displayName ?? 'A patient';
      
      await _notificationService.sendNotification(
        userId: doctorId,
        type: NotificationType.waitingRoomJoined,
        title: 'Patient in Waiting Room',
        body: '$patientName has joined the waiting room.',
        data: {
          'appointmentId': appointmentId,
          'patientId': patientId,
        },
      );
    } catch (e) {
      debugPrint('Error sending waiting room joined notification: $e');
    }
  }

  /// Send notification when patient leaves waiting room
  Future<void> notifyWaitingRoomLeft({
    required String appointmentId,
    required String patientId,
    required String doctorId,
  }) async {
    try {
      await _notificationService.sendNotification(
        userId: doctorId,
        type: NotificationType.waitingRoomLeft,
        title: 'Patient Left Waiting Room',
        body: 'A patient has left the waiting room.',
        data: {
          'appointmentId': appointmentId,
          'patientId': patientId,
        },
      );
    } catch (e) {
      debugPrint('Error sending waiting room left notification: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointmentDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (appointmentDate == today) {
      return 'Today at ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}

