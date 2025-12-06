import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

class PaymentModel {
  final String id;
  final String appointmentId;
  final String patientId;
  final String doctorId;
  final double amount;
  final PaymentStatus status;
  final String? stripePaymentIntentId;
  final String? stripeClientSecret;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? failureReason;

  PaymentModel({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.doctorId,
    required this.amount,
    required this.status,
    this.stripePaymentIntentId,
    this.stripeClientSecret,
    required this.createdAt,
    this.completedAt,
    this.failureReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'patientId': patientId,
      'doctorId': doctorId,
      'amount': amount,
      'status': status.name,
      'stripePaymentIntentId': stripePaymentIntentId,
      'stripeClientSecret': stripeClientSecret,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'failureReason': failureReason,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as String,
      appointmentId: map['appointmentId'] as String,
      patientId: map['patientId'] as String,
      doctorId: map['doctorId'] as String,
      amount: (map['amount'] as num).toDouble(),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PaymentStatus.pending,
      ),
      stripePaymentIntentId: map['stripePaymentIntentId'] as String?,
      stripeClientSecret: map['stripeClientSecret'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      failureReason: map['failureReason'] as String?,
    );
  }

  PaymentModel copyWith({
    String? id,
    String? appointmentId,
    String? patientId,
    String? doctorId,
    double? amount,
    PaymentStatus? status,
    String? stripePaymentIntentId,
    String? stripeClientSecret,
    DateTime? createdAt,
    DateTime? completedAt,
    String? failureReason,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      stripeClientSecret: stripeClientSecret ?? this.stripeClientSecret,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      failureReason: failureReason ?? this.failureReason,
    );
  }
}

