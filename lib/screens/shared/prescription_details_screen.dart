import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/prescription_model.dart';
import '../../services/prescription_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/doctor_service.dart';

final prescriptionServiceProvider =
    Provider<PrescriptionService>((ref) => PrescriptionService());

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final doctorServiceProvider = Provider<DoctorService>((ref) {
  return DoctorService();
});

final prescriptionDetailsProvider =
    StreamProvider.family<PrescriptionModel?, String>((ref, prescriptionId) {
  final prescriptionService = ref.read(prescriptionServiceProvider);
  return prescriptionService.getPrescriptionStreamById(prescriptionId);
});

class PrescriptionDetailsScreen extends ConsumerWidget {
  final String prescriptionId;

  const PrescriptionDetailsScreen({
    super.key,
    required this.prescriptionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionAsync = ref.watch(prescriptionDetailsProvider(prescriptionId));
    final currentUser = ref.watch(authStateNotifierProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription Details'),
      ),
      body: prescriptionAsync.when(
        data: (prescription) {
          if (prescription == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Prescription not found'),
                ],
              ),
            );
          }

          final isPatient = currentUser?.userType == UserType.patient;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.purple.shade100,
                          child: Icon(
                            Icons.medication,
                            size: 32,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Prescription',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Prescribed: ${_formatDate(prescription.prescribedDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Diagnosis
                if (prescription.diagnosis != null) ...[
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.medical_information,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Diagnosis',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            prescription.diagnosis!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Medications
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.medication_liquid,
                              color: Colors.purple.shade700,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Medications',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...prescription.medications.asMap().entries.map((entry) {
                          final index = entry.key;
                          final medication = entry.value;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: Colors.purple.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.purple.shade200,
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          medication.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildMedicationInfo(
                                    Icons.science,
                                    'Dosage',
                                    medication.dosage,
                                  ),
                                  _buildMedicationInfo(
                                    Icons.schedule,
                                    'Frequency',
                                    medication.frequency,
                                  ),
                                  _buildMedicationInfo(
                                    Icons.calendar_today,
                                    'Duration',
                                    medication.duration,
                                  ),
                                  if (medication.instructions != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 16,
                                            color: Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              medication.instructions!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Notes
                if (prescription.notes != null && prescription.notes!.isNotEmpty) ...[
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Additional Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            prescription.notes!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Doctor/Patient Info
                FutureBuilder<UserModel?>(
                  future: isPatient
                      ? ref.read(doctorServiceProvider).getDoctorById(prescription.doctorId)
                      : ref.read(authServiceProvider).getUserData(prescription.patientId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }

                    final user = snapshot.data;
                    if (user == null) {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPatient ? 'Prescribed By' : 'Patient',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFF2196F3),
                                  child: Text(
                                    user.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.displayName ?? 'User',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isPatient && user.specialization != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          user.specialization!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(prescriptionDetailsProvider(prescriptionId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

