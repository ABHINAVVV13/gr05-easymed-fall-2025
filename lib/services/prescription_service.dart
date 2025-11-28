import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prescription_model.dart';

class PrescriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a prescription
  Future<PrescriptionModel> createPrescription(PrescriptionModel prescription) async {
    try {
      await _firestore
          .collection('prescriptions')
          .doc(prescription.id)
          .set(prescription.toMap());
      
      // If linked to appointment, update appointment with prescription ID
      if (prescription.appointmentId != null) {
        await _firestore
            .collection('appointments')
            .doc(prescription.appointmentId)
            .update({
          'prescriptionId': prescription.id,
          'updatedAt': Timestamp.now(),
        });
      }
      
      return prescription;
    } catch (e) {
      rethrow;
    }
  }

  // Get prescription by ID (stream)
  Stream<PrescriptionModel?> getPrescriptionStreamById(String prescriptionId) {
    return _firestore
        .collection('prescriptions')
        .doc(prescriptionId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return PrescriptionModel.fromMap(doc.data()!);
          }
          return null;
        });
  }

  // Get prescriptions for a patient (stream)
  Stream<List<PrescriptionModel>> getPatientPrescriptionsStream(String patientId) {
    return _firestore
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .orderBy('prescribedDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PrescriptionModel.fromMap(doc.data()))
            .toList());
  }

  // Get prescriptions for a doctor (stream)
  Stream<List<PrescriptionModel>> getDoctorPrescriptionsStream(String doctorId) {
    return _firestore
        .collection('prescriptions')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('prescribedDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PrescriptionModel.fromMap(doc.data()))
            .toList());
  }

  // Get prescriptions for a specific appointment
  Future<List<PrescriptionModel>> getPrescriptionsByAppointment(String appointmentId) async {
    try {
      final snapshot = await _firestore
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: appointmentId)
          .get();

      return snapshot.docs
          .map((doc) => PrescriptionModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Update prescription (doctors only)
  Future<void> updatePrescription(PrescriptionModel prescription) async {
    try {
      await _firestore
          .collection('prescriptions')
          .doc(prescription.id)
          .update({
        ...prescription.toMap(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      rethrow;
    }
  }
}

