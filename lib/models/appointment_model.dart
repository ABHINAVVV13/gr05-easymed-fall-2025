import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
}

enum AppointmentType {
  instant, // Join Now
  scheduled,
}

enum ConsultationType {
  video, // Video call consultation
  chat,  // Text chat consultation
}

class AppointmentModel {
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime scheduledTime;
  final AppointmentType type;
  final AppointmentStatus status;
  final ConsultationType consultationType; // video or chat
  final String? notes;
  final String? prescriptionId;
  // Questionnaire data
  final List<String>? symptoms;
  final String? severity;
  final String? duration;
  final String? aiRecommendation;
  final List<String>? recommendedSpecializations;
  final String? aiGeneratedConversation; // AI-generated medical conversation summary
  final DateTime createdAt;
  final DateTime? updatedAt;
  // Waiting room fields
  final DateTime? waitingRoomJoinedAt;
  final DateTime? waitingRoomLeftAt;

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.scheduledTime,
    required this.type,
    required this.status,
    this.consultationType = ConsultationType.video, // Default to video
    this.notes,
    this.prescriptionId,
    this.symptoms,
    this.severity,
    this.duration,
    this.aiRecommendation,
    this.recommendedSpecializations,
    this.aiGeneratedConversation,
    required this.createdAt,
    this.updatedAt,
    this.waitingRoomJoinedAt,
    this.waitingRoomLeftAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'type': type.name,
      'status': status.name,
      'consultationType': consultationType.name,
      'notes': notes,
      'prescriptionId': prescriptionId,
      'symptoms': symptoms,
      'severity': severity,
      'duration': duration,
      'aiRecommendation': aiRecommendation,
      'recommendedSpecializations': recommendedSpecializations,
      'aiGeneratedConversation': aiGeneratedConversation,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'waitingRoomJoinedAt': waitingRoomJoinedAt != null ? Timestamp.fromDate(waitingRoomJoinedAt!) : null,
      'waitingRoomLeftAt': waitingRoomLeftAt != null ? Timestamp.fromDate(waitingRoomLeftAt!) : null,
    };
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      doctorId: map['doctorId'] as String,
      scheduledTime: (map['scheduledTime'] as Timestamp).toDate(),
      type: AppointmentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AppointmentType.scheduled,
      ),
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AppointmentStatus.scheduled,
      ),
      consultationType: map['consultationType'] != null
          ? ConsultationType.values.firstWhere(
              (e) => e.name == map['consultationType'],
              orElse: () => ConsultationType.video,
            )
          : ConsultationType.video,
      notes: map['notes'] as String?,
      prescriptionId: map['prescriptionId'] as String?,
      symptoms: map['symptoms'] != null
          ? List<String>.from(map['symptoms'] as List)
          : null,
      severity: map['severity'] as String?,
      duration: map['duration'] as String?,
      aiRecommendation: map['aiRecommendation'] as String?,
      recommendedSpecializations: map['recommendedSpecializations'] != null
          ? List<String>.from(map['recommendedSpecializations'] as List)
          : null,
      aiGeneratedConversation: map['aiGeneratedConversation'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      waitingRoomJoinedAt: map['waitingRoomJoinedAt'] != null
          ? (map['waitingRoomJoinedAt'] as Timestamp).toDate()
          : null,
      waitingRoomLeftAt: map['waitingRoomLeftAt'] != null
          ? (map['waitingRoomLeftAt'] as Timestamp).toDate()
          : null,
    );
  }

  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    DateTime? scheduledTime,
    AppointmentType? type,
    AppointmentStatus? status,
    ConsultationType? consultationType,
    String? notes,
    String? prescriptionId,
    List<String>? symptoms,
    String? severity,
    String? duration,
    String? aiRecommendation,
    List<String>? recommendedSpecializations,
    String? aiGeneratedConversation,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? waitingRoomJoinedAt,
    DateTime? waitingRoomLeftAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      type: type ?? this.type,
      status: status ?? this.status,
      consultationType: consultationType ?? this.consultationType,
      notes: notes ?? this.notes,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      symptoms: symptoms ?? this.symptoms,
      severity: severity ?? this.severity,
      duration: duration ?? this.duration,
      aiRecommendation: aiRecommendation ?? this.aiRecommendation,
      recommendedSpecializations: recommendedSpecializations ?? this.recommendedSpecializations,
      aiGeneratedConversation: aiGeneratedConversation ?? this.aiGeneratedConversation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      waitingRoomJoinedAt: waitingRoomJoinedAt ?? this.waitingRoomJoinedAt,
      waitingRoomLeftAt: waitingRoomLeftAt ?? this.waitingRoomLeftAt,
    );
  }
}

