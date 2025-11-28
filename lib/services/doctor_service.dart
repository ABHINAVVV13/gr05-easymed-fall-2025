import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Service for managing doctor-related operations in Firestore
/// Provides methods to search, retrieve, and filter doctors
class DoctorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Search doctors by name
  Future<List<UserModel>> searchDoctorsByName(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'doctor')
          .get();

      final doctors = snapshot.docs
          .map((doc) {
            try {
              return UserModel.fromMap(doc.data());
            } catch (e) {
              // Skip invalid doctor documents
              return null;
            }
          })
          .whereType<UserModel>()
          .where((doctor) {
            final name = doctor.displayName?.toLowerCase() ?? '';
            final email = doctor.email.toLowerCase();
            final searchQuery = query.trim().toLowerCase();
            return name.contains(searchQuery) || email.contains(searchQuery);
          })
          .toList();

      return doctors;
    } catch (e) {
      rethrow;
    }
  }

  // Search doctors by specialization
  Future<List<UserModel>> searchDoctorsBySpecialization(String specialization) async {
    try {
      if (specialization.trim().isEmpty) {
        return [];
      }

      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'doctor')
          .where('specialization', isEqualTo: specialization)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return UserModel.fromMap(doc.data());
            } catch (e) {
              // Skip invalid doctor documents
              return null;
            }
          })
          .whereType<UserModel>()
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get all doctors
  Future<List<UserModel>> getAllDoctors() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'doctor')
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return UserModel.fromMap(doc.data());
            } catch (e) {
              // Skip invalid doctor documents
              return null;
            }
          })
          .whereType<UserModel>()
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get doctor by ID
  Future<UserModel?> getDoctorById(String doctorId) async {
    try {
      final doc = await _firestore.collection('users').doc(doctorId).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['userType'] == 'doctor') {
          return UserModel.fromMap(data);
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get available doctors (with working hours set)
  Future<List<UserModel>> getAvailableDoctors() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'doctor')
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return UserModel.fromMap(doc.data());
            } catch (e) {
              // Skip invalid doctor documents
              return null;
            }
          })
          .whereType<UserModel>()
          .where((doctor) => doctor.workingHours != null && doctor.workingHours!.isNotEmpty)
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}

