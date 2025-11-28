import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType {
  patient,
  doctor,
  admin,
}

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final UserType userType;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Patient-specific fields
  final int? age;
  final String? gender;
  final List<String>? allergies;
  final List<String>? pastConditions;
  
  // Doctor-specific fields
  final String? specialization;
  final String? clinicName;
  final String? licenseNumber;
  final bool? isVerified;
  final double? consultationFee;
  final Map<String, dynamic>? workingHours;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    required this.userType,
    required this.createdAt,
    this.updatedAt,
    this.age,
    this.gender,
    this.allergies,
    this.pastConditions,
    this.specialization,
    this.clinicName,
    this.licenseNumber,
    this.isVerified,
    this.consultationFee,
    this.workingHours,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'userType': userType.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'age': age,
      'gender': gender,
      'allergies': allergies,
      'pastConditions': pastConditions,
      'specialization': specialization,
      'clinicName': clinicName,
      'licenseNumber': licenseNumber,
      'isVerified': isVerified,
      'consultationFee': consultationFee,
      'workingHours': workingHours,
    };
  }

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Handle userType - it might be a string or already a UserType enum
    UserType userType;
    final userTypeValue = map['userType'];
    if (userTypeValue is UserType) {
      userType = userTypeValue;
    } else if (userTypeValue is String) {
      userType = UserType.values.firstWhere(
        (e) => e.name == userTypeValue,
        orElse: () => UserType.patient,
      );
    } else {
      userType = UserType.patient; // Default fallback
    }

    return UserModel(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      userType: userType,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      allergies: map['allergies'] != null
          ? List<String>.from(map['allergies'])
          : null,
      pastConditions: map['pastConditions'] != null
          ? List<String>.from(map['pastConditions'])
          : null,
      specialization: map['specialization'] as String?,
      clinicName: map['clinicName'] as String?,
      licenseNumber: map['licenseNumber'] as String?,
      isVerified: map['isVerified'] as bool?,
      consultationFee: map['consultationFee'] != null
          ? (map['consultationFee'] as num).toDouble()
          : null,
      workingHours: map['workingHours'] as Map<String, dynamic>?,
    );
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserType? userType,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? age,
    String? gender,
    List<String>? allergies,
    List<String>? pastConditions,
    String? specialization,
    String? clinicName,
    String? licenseNumber,
    bool? isVerified,
    double? consultationFee,
    Map<String, dynamic>? workingHours,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      userType: userType ?? this.userType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      allergies: allergies ?? this.allergies,
      pastConditions: pastConditions ?? this.pastConditions,
      specialization: specialization ?? this.specialization,
      clinicName: clinicName ?? this.clinicName,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      isVerified: isVerified ?? this.isVerified,
      consultationFee: consultationFee ?? this.consultationFee,
      workingHours: workingHours ?? this.workingHours,
    );
  }
}

