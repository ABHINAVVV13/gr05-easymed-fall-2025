import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/prescription_model.dart';
import '../../services/prescription_service.dart';
import '../../providers/auth_provider.dart';

final prescriptionServiceProvider =
    Provider<PrescriptionService>((ref) => PrescriptionService());

final patientPrescriptionsProvider = StreamProvider<List<PrescriptionModel>>((ref) {
  final currentUser = ref.watch(authStateNotifierProvider).value;
  if (currentUser == null) {
    return Stream.value([]);
  }
  final prescriptionService = ref.read(prescriptionServiceProvider);
  return prescriptionService.getPatientPrescriptionsStream(currentUser.uid);
});

class PatientPrescriptionsScreen extends ConsumerWidget {
  const PatientPrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionsAsync = ref.watch(patientPrescriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Prescriptions'),
      ),
      body: prescriptionsAsync.when(
        data: (prescriptions) {
          if (prescriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medication_liquid,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No prescriptions yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your prescriptions will appear here after consultations',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(patientPrescriptionsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prescriptions.length,
              itemBuilder: (context, index) {
                final prescription = prescriptions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: InkWell(
                    onTap: () {
                      context.push('/prescription-details/${prescription.id}');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.purple.shade100,
                                child: Icon(
                                  Icons.medication,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${prescription.medications.length} ${prescription.medications.length == 1 ? 'Medication' : 'Medications'}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Prescribed: ${_formatDate(prescription.prescribedDate)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                          if (prescription.diagnosis != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Diagnosis: ${prescription.diagnosis}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: prescription.medications
                                .take(3)
                                .map((med) => Chip(
                                      label: Text(
                                        med.name,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ))
                                .toList(),
                          ),
                          if (prescription.medications.length > 3)
                            Text(
                              '+ ${prescription.medications.length - 3} more',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
                onPressed: () => ref.refresh(patientPrescriptionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

