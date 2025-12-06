import 'package:cloud_firestore/cloud_firestore.dart';

class StethoscopeModel {
  final String id;
  final String patientId;
  final String? doctorId; // Doctor who can view this recording
  final String audioUrl; // Firebase Storage URL
  final String fileName;
  final String? microphoneName; // Name of microphone used for recording
  final DateTime recordedAt;
  final DateTime? uploadedAt; // For uploaded files
  final String? notes; // Patient notes
  final String? doctorNotes; // Doctor's analysis notes
  final int durationSeconds; // Duration in seconds

  StethoscopeModel({
    required this.id,
    required this.patientId,
    this.doctorId,
    required this.audioUrl,
    required this.fileName,
    this.microphoneName,
    required this.recordedAt,
    this.uploadedAt,
    this.notes,
    this.doctorNotes,
    required this.durationSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'audioUrl': audioUrl,
      'fileName': fileName,
      'microphoneName': microphoneName,
      'recordedAt': Timestamp.fromDate(recordedAt),
      'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : null,
      'notes': notes,
      'doctorNotes': doctorNotes,
      'durationSeconds': durationSeconds,
    };
  }

  factory StethoscopeModel.fromMap(Map<String, dynamic> map) {
    return StethoscopeModel(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      doctorId: map['doctorId'] as String?,
      audioUrl: map['audioUrl'] as String,
      fileName: map['fileName'] as String,
      microphoneName: map['microphoneName'] as String?,
      recordedAt: (map['recordedAt'] as Timestamp).toDate(),
      uploadedAt: map['uploadedAt'] != null
          ? (map['uploadedAt'] as Timestamp).toDate()
          : null,
      notes: map['notes'] as String?,
      doctorNotes: map['doctorNotes'] as String?,
      durationSeconds: map['durationSeconds'] as int? ?? 0,
    );
  }

  StethoscopeModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? audioUrl,
    String? fileName,
    String? microphoneName,
    DateTime? recordedAt,
    DateTime? uploadedAt,
    String? notes,
    String? doctorNotes,
    int? durationSeconds,
  }) {
    return StethoscopeModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      audioUrl: audioUrl ?? this.audioUrl,
      fileName: fileName ?? this.fileName,
      microphoneName: microphoneName ?? this.microphoneName,
      recordedAt: recordedAt ?? this.recordedAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      notes: notes ?? this.notes,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

