import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType {
  labResult,
  xRay,
  mri,
  ctScan,
  ultrasound,
  prescription,
  other,
}

class MedicalReportModel {
  final String id;
  final String patientId;
  final String? doctorId; // Doctor who uploaded/reviewed the report
  final String title;
  final ReportType type;
  final String? description;
  final String fileUrl; // Firebase Storage URL
  final String fileName;
  final DateTime reportDate;
  final DateTime uploadedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; // Doctor ID who reviewed

  MedicalReportModel({
    required this.id,
    required this.patientId,
    this.doctorId,
    required this.title,
    required this.type,
    this.description,
    required this.fileUrl,
    required this.fileName,
    required this.reportDate,
    required this.uploadedAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'title': title,
      'type': type.name,
      'description': description,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'reportDate': Timestamp.fromDate(reportDate),
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
    };
  }

  factory MedicalReportModel.fromMap(Map<String, dynamic> map) {
    return MedicalReportModel(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      doctorId: map['doctorId'] as String?,
      title: map['title'] as String,
      type: ReportType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ReportType.other,
      ),
      description: map['description'] as String?,
      fileUrl: map['fileUrl'] as String,
      fileName: map['fileName'] as String,
      reportDate: (map['reportDate'] as Timestamp).toDate(),
      uploadedAt: (map['uploadedAt'] as Timestamp).toDate(),
      reviewedAt: map['reviewedAt'] != null
          ? (map['reviewedAt'] as Timestamp).toDate()
          : null,
      reviewedBy: map['reviewedBy'] as String?,
    );
  }

  MedicalReportModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? title,
    ReportType? type,
    String? description,
    String? fileUrl,
    String? fileName,
    DateTime? reportDate,
    DateTime? uploadedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return MedicalReportModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      title: title ?? this.title,
      type: type ?? this.type,
      description: description ?? this.description,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      reportDate: reportDate ?? this.reportDate,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }
}

