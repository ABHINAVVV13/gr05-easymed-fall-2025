import 'dart:io';
import 'package:easymed/screens/patient/medical_reports_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medical_report_model.dart';

class MedicalReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload a medical report file
  Future<String> uploadReportFile(File file, String patientId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = _storage.ref().child('medical_reports/$patientId/$fileName');
      
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Create a medical report
  Future<MedicalReportModel> createReport(MedicalReportModel report) async {
    try {
      await _firestore
          .collection('medicalReports')
          .doc(report.id)
          .set(report.toMap());
      return report;
    } catch (e) {
      rethrow;
    }
  }

  // Get reports for a patient
  Stream<List<MedicalReportModel>> getPatientReportsStream(String patientId) {
    return _firestore
        .collection('medicalReports')
        .where('patientId', isEqualTo: patientId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MedicalReportModel.fromMap(doc.data()))
            .toList());
  }

  // Get report by ID (stream)
  Stream<MedicalReportModel?> getReportStreamById(String reportId) {
    return _firestore
        .collection('medicalReports')
        .doc(reportId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return MedicalReportModel.fromMap(doc.data()!);
          }
          return null;
        });
  }

  // Get reports for a doctor (all patients they've seen)
  Stream<List<MedicalReportModel>> getDoctorReportsStream(String doctorId) {
    return _firestore
        .collection('medicalReports')
        .where('reviewedBy', isEqualTo: doctorId)
        .orderBy('reviewedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MedicalReportModel.fromMap(doc.data()))
            .toList());
  }

  // Get reports for a specific patient (for doctors)
  Future<List<MedicalReportModel>> getPatientReportsForDoctor(
    String doctorId,
    String patientId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('medicalReports')
          .where('patientId', isEqualTo: patientId)
          .get();

      return snapshot.docs
          .map((doc) => MedicalReportModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Delete a report
  Future<void> deleteReport(String reportId, String fileUrl) async {
    try {
      // Delete from Firestore
      await _firestore.collection('medicalReports').doc(reportId).delete();
      
      // Delete from Storage
      try {
        final ref = _storage.refFromURL(fileUrl);
        await ref.delete();
      } catch (e) {
        // If storage delete fails, continue (file might already be deleted)
        debugPrint('Warning: Could not delete file from storage: $e');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Mark report as reviewed by doctor
  Future<void> markReportAsReviewed(String reportId, String doctorId) async {
    try {
      await _firestore.collection('medicalReports').doc(reportId).update({
        'reviewedAt': Timestamp.now(),
        'reviewedBy': doctorId,
      });
    } catch (e) {
      rethrow;
    }
  }
}

final reportStreamProvider = StreamProvider.family<MedicalReportModel?, String>((ref, reportId) {
  
  final reportService = ref.read(medicalReportServiceProvider);
  
  return reportService.getReportStreamById(reportId);
});