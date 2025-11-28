import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import 'doctor_search_screen.dart';

final doctorDetailsProvider = FutureProvider.family<UserModel?, String>((ref, doctorId) async {
  final doctorService = ref.read(doctorServiceProvider);
  return await doctorService.getDoctorById(doctorId);
});

class DoctorDetailsScreen extends ConsumerWidget {
  final String doctorId;

  const DoctorDetailsScreen({
    super.key,
    required this.doctorId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsync = ref.watch(doctorDetailsProvider(doctorId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
      ),
      body: doctorAsync.when(
        data: (doctor) {
          if (doctor == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Doctor not found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor Header Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF2196F3),
                          child: Text(
                            doctor.displayName?.substring(0, 1).toUpperCase() ?? 'D',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctor.displayName ?? 'Doctor',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (doctor.specialization != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  doctor.specialization!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                              if (doctor.isVerified == true) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified,
                                          size: 16, color: Colors.green.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Verified Doctor',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Professional Information
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Professional Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 16),
                        if (doctor.clinicName != null)
                          _buildInfoRow(
                            Icons.local_hospital,
                            'Clinic/Hospital',
                            doctor.clinicName!,
                          ),
                        if (doctor.licenseNumber != null)
                          _buildInfoRow(
                            Icons.badge,
                            'License Number',
                            doctor.licenseNumber!,
                          ),
                        if (doctor.consultationFee != null)
                          _buildInfoRow(
                            Icons.attach_money,
                            'Consultation Fee',
                            '\$${doctor.consultationFee!.toStringAsFixed(2)} per visit',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Working Hours
                if (doctor.workingHours != null && doctor.workingHours!.isNotEmpty)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Working Hours',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          const SizedBox(height: 16),
                          ...doctor.workingHours!.entries.map((entry) {
                            if (entry.value is Map &&
                                entry.value['enabled'] == true) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${entry.value['start']} - ${entry.value['end']}',
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      try {
                        context.push('/book-appointment/${doctor.uid}');
                      } catch (e) {
                        context.go('/book-appointment/${doctor.uid}');
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Book Appointment'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to instant consultation with questionnaire
                      context.push('/book-appointment/${doctor.uid}?instant=true');
                    },
                    icon: const Icon(Icons.video_call),
                    label: const Text('Join Now (Instant Consultation)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading doctor: ${error.toString()}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

