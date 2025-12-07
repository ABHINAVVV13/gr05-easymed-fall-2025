import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/stethoscope_model.dart';

class StethoscopeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload stethoscope audio file to Firebase Storage
  Future<String> uploadAudioFile(File file, String patientId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = _storage.ref().child('stethoscope/$patientId/$fileName');
      
      // Determine content type based on file extension
      String contentType = 'audio/mp4'; // Default to m4a
      final extension = file.path.split('.').last.toLowerCase();
      if (extension == 'mp3') {
        contentType = 'audio/mpeg';
      } else if (extension == 'wav') {
        contentType = 'audio/wav';
      } else if (extension == 'm4a') {
        contentType = 'audio/mp4';
      } else if (extension == 'aac') {
        contentType = 'audio/aac';
      } else if (extension == 'ogg') {
        contentType = 'audio/ogg';
      }
      
      final metadata = SettableMetadata(
        contentType: contentType,
      );
      
      final uploadTask = await ref.putFile(file, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading audio file: $e');
      rethrow;
    }
  }

  /// Create a stethoscope recording document
  Future<StethoscopeModel> createRecording(StethoscopeModel recording) async {
    try {
      await _firestore
          .collection('stethoscope')
          .doc(recording.id)
          .set(recording.toMap());
      return recording;
    } catch (e) {
      debugPrint('Error creating recording: $e');
      rethrow;
    }
  }

  /// Get all recordings for a patient
  Stream<List<StethoscopeModel>> getPatientRecordingsStream(String patientId) {
    return _firestore
        .collection('stethoscope')
        .where('patientId', isEqualTo: patientId)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StethoscopeModel.fromMap(doc.data()))
            .toList());
  }

  /// Get all recordings for a doctor (from their patients via appointments)
  /// This gets recordings from all patients who have appointments with the doctor
  Future<List<StethoscopeModel>> getDoctorRecordings(String doctorId) async {
    try {
      // First, get all appointments for this doctor to find patient IDs
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .get();
      
      final patientIds = appointmentsSnapshot.docs
          .map((doc) => doc.data()['patientId'] as String)
          .toSet()
          .toList();
      
      if (patientIds.isEmpty) {
        return [];
      }
      
      // Get all recordings from these patients
      // Note: Firestore 'in' queries are limited to 10 items, so we need to batch
      final allRecordings = <StethoscopeModel>[];
      
      for (int i = 0; i < patientIds.length; i += 10) {
        final batch = patientIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection('stethoscope')
            .where('patientId', whereIn: batch)
            .orderBy('recordedAt', descending: true)
            .get();
        
        allRecordings.addAll(
          snapshot.docs.map((doc) => StethoscopeModel.fromMap(doc.data())),
        );
      }
      
      // Sort by recordedAt descending
      allRecordings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      
      return allRecordings;
    } catch (e) {
      debugPrint('Error getting doctor recordings: $e');
      rethrow;
    }
  }
  
  /// Get all recordings for a doctor (stream version - watches appointments and recordings)
  Stream<List<StethoscopeModel>> getDoctorRecordingsStream(String doctorId) {
    // Watch appointments to get patient IDs, then watch recordings from those patients
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .asyncExpand((appointmentsSnapshot) {
          final patientIds = appointmentsSnapshot.docs
              .map((doc) => doc.data()['patientId'] as String)
              .toSet()
              .toList();
          
          if (patientIds.isEmpty) {
            return Stream.value(<StethoscopeModel>[]);
          }
          
          // Watch stethoscope collection for all patient IDs
          // Since Firestore 'in' queries are limited to 10 items, we need to combine multiple streams
          if (patientIds.length <= 10) {
            // Single query if 10 or fewer patients
            return _firestore
                .collection('stethoscope')
                .where('patientId', whereIn: patientIds)
                .orderBy('recordedAt', descending: true)
                .snapshots()
                .map((snapshot) {
                  final recordings = snapshot.docs
                      .map((doc) => StethoscopeModel.fromMap(doc.data()))
                      .toList();
                  // Sort by recordedAt descending
                  recordings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
                  return recordings;
                });
          } else {
            // For more than 10 patients, watch all stethoscope recordings and filter
            // This ensures real-time updates when new recordings are added
            final patientIdsSet = patientIds.toSet();
            return _firestore
                .collection('stethoscope')
                .orderBy('recordedAt', descending: true)
                .snapshots()
                .map((snapshot) {
                  final recordings = snapshot.docs
                      .map((doc) => StethoscopeModel.fromMap(doc.data()))
                      .where((recording) => patientIdsSet.contains(recording.patientId))
                      .toList();
                  // Already sorted by orderBy, but ensure descending
                  recordings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
                  return recordings;
                });
          }
        });
  }

  /// Get recordings for a specific patient (for doctors viewing patient history)
  Future<List<StethoscopeModel>> getPatientRecordingsForDoctor(
    String patientId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('stethoscope')
          .where('patientId', isEqualTo: patientId)
          .orderBy('recordedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => StethoscopeModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting patient recordings: $e');
      rethrow;
    }
  }

  /// Update doctor notes on a recording
  Future<void> updateDoctorNotes(String recordingId, String doctorId, String notes) async {
    try {
      await _firestore.collection('stethoscope').doc(recordingId).update({
        'doctorId': doctorId,
        'doctorNotes': notes,
      });
    } catch (e) {
      debugPrint('Error updating doctor notes: $e');
      rethrow;
    }
  }

  /// Delete a recording
  Future<void> deleteRecording(String recordingId, String audioUrl) async {
    try {
      // Delete from Firestore
      await _firestore.collection('stethoscope').doc(recordingId).delete();
      
      // Delete from Storage
      try {
        final ref = _storage.refFromURL(audioUrl);
        await ref.delete();
      } catch (e) {
        debugPrint('Warning: Could not delete audio file from storage: $e');
      }
    } catch (e) {
      debugPrint('Error deleting recording: $e');
      rethrow;
    }
  }
}

