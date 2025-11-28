import 'package:cloud_firestore/cloud_firestore.dart';

class SymptomQuestionnaireModel {
  final String id;
  final String patientId;
  final List<String> symptoms;
  final String? severity; // mild, moderate, severe
  final String? duration; // how long symptoms have been present
  final Map<String, dynamic>? additionalInfo; // age, gender, existing conditions
  final String? aiRecommendation; // AI-generated doctor recommendation
  final List<String>? recommendedSpecializations; // Suggested doctor specializations
  final DateTime createdAt;

  SymptomQuestionnaireModel({
    required this.id,
    required this.patientId,
    required this.symptoms,
    this.severity,
    this.duration,
    this.additionalInfo,
    this.aiRecommendation,
    this.recommendedSpecializations,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'symptoms': symptoms,
      'severity': severity,
      'duration': duration,
      'additionalInfo': additionalInfo,
      'aiRecommendation': aiRecommendation,
      'recommendedSpecializations': recommendedSpecializations,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SymptomQuestionnaireModel.fromMap(Map<String, dynamic> map) {
    return SymptomQuestionnaireModel(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      symptoms: List<String>.from(map['symptoms'] as List),
      severity: map['severity'] as String?,
      duration: map['duration'] as String?,
      additionalInfo: map['additionalInfo'] as Map<String, dynamic>?,
      aiRecommendation: map['aiRecommendation'] as String?,
      recommendedSpecializations: map['recommendedSpecializations'] != null
          ? List<String>.from(map['recommendedSpecializations'] as List)
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

