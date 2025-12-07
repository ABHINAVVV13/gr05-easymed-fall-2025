import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../services/notification_helper.dart';
import '../services/auth_service.dart';
import '../services/doctor_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final doctorServiceProvider = Provider<DoctorService>((ref) {
  return DoctorService();
});

final notificationHelperProvider = Provider<NotificationHelper>((ref) {
  return NotificationHelper(
    notificationService: ref.read(notificationServiceProvider),
    authService: ref.read(authServiceProvider),
    doctorService: ref.read(doctorServiceProvider),
  );
});

