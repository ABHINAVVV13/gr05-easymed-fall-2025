import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String? instructions;

  Medication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      name: map['name'] as String,
      dosage: map['dosage'] as String,
      frequency: map['frequency'] as String,
      duration: map['duration'] as String,
      instructions: map['instructions'] as String?,
    );
  }
}

class PrescriptionModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String? appointmentId; // Optional link to appointment
  final List<Medication> medications;
  final String? diagnosis;
  final String? notes;
  final DateTime prescribedDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PrescriptionModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    this.appointmentId,
    required this.medications,
    this.diagnosis,
    this.notes,
    required this.prescribedDate,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'appointmentId': appointmentId,
      'medications': medications.map((m) => m.toMap()).toList(),
      'diagnosis': diagnosis,
      'notes': notes,
      'prescribedDate': Timestamp.fromDate(prescribedDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory PrescriptionModel.fromMap(Map<String, dynamic> map) {
    return PrescriptionModel(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      doctorId: map['doctorId'] as String,
      appointmentId: map['appointmentId'] as String?,
      medications: (map['medications'] as List)
          .map((m) => Medication.fromMap(m as Map<String, dynamic>))
          .toList(),
      diagnosis: map['diagnosis'] as String?,
      notes: map['notes'] as String?,
      prescribedDate: (map['prescribedDate'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  PrescriptionModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? appointmentId,
    List<Medication>? medications,
    String? diagnosis,
    String? notes,
    DateTime? prescribedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PrescriptionModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      appointmentId: appointmentId ?? this.appointmentId,
      medications: medications ?? this.medications,
      diagnosis: diagnosis ?? this.diagnosis,
      notes: notes ?? this.notes,
      prescribedDate: prescribedDate ?? this.prescribedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

