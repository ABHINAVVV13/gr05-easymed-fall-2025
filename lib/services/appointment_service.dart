import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new appointment
  Future<AppointmentModel> createAppointment(AppointmentModel appointment) async {
    try {
      await _firestore
          .collection('appointments')
          .doc(appointment.id)
          .set(appointment.toMap());
      return appointment;
    } catch (e) {
      rethrow;
    }
  }

  // Get appointment by ID
  Future<AppointmentModel?> getAppointmentById(String appointmentId) async {
    try {
      final doc = await _firestore.collection('appointments').doc(appointmentId).get();
      if (doc.exists) {
        return AppointmentModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get appointments for a patient (stream - real-time updates)
  Stream<List<AppointmentModel>> getPatientAppointmentsStream(String patientId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppointmentModel.fromMap(doc.data()))
            .toList());
  }

  // Get appointments for a patient (future - for one-time fetch)
  Future<List<AppointmentModel>> getPatientAppointments(String patientId) async {
    try {
      final snapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('scheduledTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get appointments for a doctor (stream - real-time updates)
  Stream<List<AppointmentModel>> getDoctorAppointmentsStream(String doctorId) {
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppointmentModel.fromMap(doc.data()))
            .toList());
  }

  // Get appointments for a doctor (future - for one-time fetch)
  Future<List<AppointmentModel>> getDoctorAppointments(String doctorId) async {
    try {
      final snapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('scheduledTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Update appointment status
  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': status.name,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Cancel appointment
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': AppointmentStatus.cancelled.name,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Check if doctor is available at a specific time
  Future<bool> isDoctorAvailable(String doctorId, DateTime dateTime) async {
    try {
      // Get all appointments for this doctor
      final snapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', whereIn: [
            AppointmentStatus.scheduled.name,
            AppointmentStatus.inProgress.name,
          ])
          .get();

      // Check if any appointment overlaps with the requested time
      for (var doc in snapshot.docs) {
        final appointment = AppointmentModel.fromMap(doc.data());
        final appointmentTime = appointment.scheduledTime;
        
        // Check if appointment time is within 15 minutes of requested time
        final timeDiff = appointmentTime.difference(dateTime).abs();
        if (timeDiff.inMinutes < 30) {
          return false; // Doctor is busy
        }
      }

      return true; // Doctor is available
    } catch (e) {
      rethrow;
    }
  }

  // Get upcoming appointments for a patient
  Future<List<AppointmentModel>> getUpcomingPatientAppointments(String patientId) async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .where('scheduledTime', isGreaterThan: now)
          .where('status', whereIn: [
            AppointmentStatus.scheduled.name,
            AppointmentStatus.inProgress.name,
          ])
          .orderBy('scheduledTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get upcoming appointments for a doctor
  Future<List<AppointmentModel>> getUpcomingDoctorAppointments(String doctorId) async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('scheduledTime', isGreaterThan: now)
          .where('status', whereIn: [
            AppointmentStatus.scheduled.name,
            AppointmentStatus.inProgress.name,
          ])
          .orderBy('scheduledTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Join waiting room
  Future<void> joinWaitingRoom(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'waitingRoomJoinedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Leave waiting room
  Future<void> leaveWaitingRoom(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'waitingRoomLeftAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get waiting patients for a doctor (stream - real-time updates)
  Stream<List<AppointmentModel>> getWaitingPatientsStream(String doctorId) {
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', whereIn: [
          AppointmentStatus.scheduled.name,
          AppointmentStatus.inProgress.name,
        ])
        .snapshots()
        .map((snapshot) {
          final appointments = snapshot.docs
              .map((doc) => AppointmentModel.fromMap(doc.data()))
              .toList();
          // Filter to only appointments where patient has joined waiting room and not left
          return appointments
              .where((apt) => apt.waitingRoomJoinedAt != null && apt.waitingRoomLeftAt == null)
              .toList()
            ..sort((a, b) {
              if (a.waitingRoomJoinedAt == null || b.waitingRoomJoinedAt == null) return 0;
              return a.waitingRoomJoinedAt!.compareTo(b.waitingRoomJoinedAt!);
            });
        });
  }

  // Get waiting patients for a doctor (future - for one-time fetch)
  Future<List<AppointmentModel>> getWaitingPatients(String doctorId) async {
    try {
      final snapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', whereIn: [
            AppointmentStatus.scheduled.name,
            AppointmentStatus.inProgress.name,
          ])
          .get();

      final appointments = snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data()))
          .toList();
      // Filter to only appointments where patient has joined waiting room and not left
      final waiting = appointments
          .where((apt) => apt.waitingRoomJoinedAt != null && apt.waitingRoomLeftAt == null)
          .toList();
      waiting.sort((a, b) {
        if (a.waitingRoomJoinedAt == null || b.waitingRoomJoinedAt == null) return 0;
        return a.waitingRoomJoinedAt!.compareTo(b.waitingRoomJoinedAt!);
      });
      return waiting;
    } catch (e) {
      rethrow;
    }
  }
}
