# Notification Integration Guide

This document outlines where notifications have been integrated and where they still need to be added.

## ✅ Completed Setup

1. **Core Infrastructure**
   - `lib/models/notification_model.dart` - Notification data model
   - `lib/services/notification_service.dart` - FCM service for sending notifications
   - `lib/services/notification_helper.dart` - Helper methods for common notification scenarios
   - `functions/index.js` - Cloud Function `sendPushNotification` added
   - `firestore.rules` - Security rules for notifications collection
   - `lib/main.dart` - Notification initialization added

2. **Dependencies**
   - `firebase_messaging: ^15.1.3` added to `pubspec.yaml`

## 📋 Integration Points (To Be Added)

### Appointment Notifications

1. **Patient Books Appointment** → Notify Doctor
   - File: `lib/screens/patient/appointment_booking_screen.dart`
   - Location: After `appointmentService.createAppointment(appointment)` (line ~301)
   - Code:
   ```dart
   final notificationHelper = ref.read(notificationHelperProvider);
   await notificationHelper.notifyAppointmentBooked(
     appointmentId: appointment.id,
     patientId: appointment.patientId,
     doctorId: appointment.doctorId,
     scheduledTime: appointment.scheduledTime,
   );
   ```

2. **Patient Joins Waiting Room (Instant)** → Notify Doctor
   - File: `lib/screens/patient/appointment_booking_screen.dart`
   - Location: After `appointmentService.createAppointment(appointment)` in `_startInstantConsultation()` (line ~372)
   - Code:
   ```dart
   final notificationHelper = ref.read(notificationHelperProvider);
   await notificationHelper.notifyWaitingRoomJoined(
     appointmentId: appointment.id,
     patientId: appointment.patientId,
     doctorId: appointment.doctorId,
   );
   ```

3. **Doctor Starts Appointment** → Notify Patient
   - File: `lib/screens/doctor/doctor_waiting_room_screen.dart`
   - Location: After `appointmentService.updateAppointmentStatus()` (line ~377)
   - Code:
   ```dart
   final notificationHelper = ref.read(notificationHelperProvider);
   await notificationHelper.notifyAppointmentStarted(
     appointmentId: appointment.id,
     patientId: appointment.patientId,
     doctorId: appointment.doctorId,
   );
   ```

4. **Appointment Status Changed** → Notify Both
   - File: `lib/services/appointment_service.dart`
   - Location: In `updateAppointmentStatus()` method (line ~92)
   - Note: Requires passing NotificationHelper or calling from screen

5. **Appointment Cancelled** → Notify Both
   - File: `lib/services/appointment_service.dart`
   - Location: In `cancelAppointment()` method (line ~107)
   - Note: Requires passing NotificationHelper or calling from screen

### Chat Notifications

6. **New Chat Message** → Notify Recipient
   - File: `lib/services/chat_service.dart`
   - Location: In `sendMessage()` method (line ~8)
   - Code:
   ```dart
   // After message is saved
   final notificationHelper = ref.read(notificationHelperProvider);
   final appointment = await appointmentService.getAppointmentById(appointmentId);
   if (appointment != null) {
     final recipientId = senderId == appointment.patientId 
         ? appointment.doctorId 
         : appointment.patientId;
     await notificationHelper.notifyNewMessage(
       appointmentId: appointmentId,
       senderId: senderId,
       recipientId: recipientId,
       senderName: senderName,
       message: message,
     );
   }
   ```

### Payment Notifications

7. **Payment Created** → Notify Patient
   - File: `lib/services/payment_service.dart`
   - Location: In `createPayment()` method (line ~100)
   - Note: Requires NotificationHelper injection

8. **Payment Completed** → Notify Both
   - File: `functions/index.js` and `lib/services/payment_service.dart`
   - Location: In `confirmPayment` Cloud Function (line ~62) and `markPaymentAsCompleted()` (line ~254)
   - Note: Can be handled in Cloud Function or service

9. **Payment Failed** → Notify Patient
   - File: `lib/services/payment_service.dart`
   - Location: In `updatePaymentStatus()` when status is failed (line ~242)

### Prescription Notifications

10. **Prescription Created** → Notify Patient
    - File: `lib/services/prescription_service.dart`
    - Location: In `createPrescription()` method (line ~8)
    - Note: Requires NotificationHelper injection

11. **Prescription Updated** → Notify Patient
    - File: `lib/services/prescription_service.dart`
    - Location: In `updatePrescription()` method (line ~87)

### Stethoscope Notifications

12. **Stethoscope Uploaded** → Notify Doctor
    - File: `lib/services/stethoscope_service.dart`
    - Location: In `createRecording()` method (line ~46)
    - Note: Requires getting doctorId from appointment

### Medical Report Notifications

13. **Medical Report Uploaded** → Notify Doctor
    - File: `lib/services/medical_report_service.dart`
    - Location: In `createReport()` method (line ~29)
    - Note: Requires getting doctorId from appointment

### Waiting Room Notifications

14. **Patient Joins Waiting Room** → Notify Doctor
    - File: `lib/services/appointment_service.dart`
    - Location: In `joinWaitingRoom()` method (line ~196)

15. **Patient Leaves Waiting Room** → Notify Doctor
    - File: `lib/services/appointment_service.dart`
    - Location: In `leaveWaitingRoom()` method (line ~208)

## 🔧 Required Providers

Add these providers to your app (create `lib/providers/notification_provider.dart`):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../services/notification_helper.dart';
import '../services/auth_service.dart';
import '../services/doctor_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationHelperProvider = Provider<NotificationHelper>((ref) {
  return NotificationHelper(
    notificationService: ref.read(notificationServiceProvider),
    authService: ref.read(authServiceProvider),
    doctorService: ref.read(doctorServiceProvider),
  );
});
```

## 📝 Next Steps

1. Create the notification providers file
2. Integrate notifications in each screen/service listed above
3. Test notifications on both Android and iOS
4. Add notification UI (notification list screen, badge counts, etc.)
5. Implement appointment reminder notifications (scheduled task)

## 🧪 Testing

To test notifications:
1. Ensure FCM is properly configured in Firebase Console
2. Run the app and check that FCM token is generated
3. Trigger each notification scenario and verify:
   - Notification appears in system tray
   - Notification data is saved to Firestore
   - Tapping notification navigates to correct screen

