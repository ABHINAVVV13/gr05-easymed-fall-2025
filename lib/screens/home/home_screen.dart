import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EasyMed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authStateNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: authState.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text('No user data available'),
            );
          }

          // Show different UI based on user type
          if (user.userType == UserType.patient) {
            return _buildPatientHome(context, ref, user);
          } else if (user.userType == UserType.doctor) {
            return _buildDoctorHome(context, ref, user);
          } else {
            return _buildDefaultHome(user);
          }
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: ${error.toString()}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientHome(BuildContext context, WidgetRef ref, user) {
    final isProfileComplete = user.age != null || user.gender != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2196F3).withValues(alpha: 0.1),
                    const Color(0xFF2196F3).withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              (user.displayName ?? 'P').substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName ?? 'Patient',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isProfileComplete) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Complete your profile to get started',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                try {
                                  context.push('/patient-profile');
                                } catch (e) {
                                  // Fallback if route not found
                                  context.go('/patient-profile');
                                }
                              },
                              child: const Text('Complete Now'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Medical Information Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Medical Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          try {
                            context.push('/patient-profile?edit=true');
                          } catch (e) {
                            // Fallback if route not found
                            context.go('/patient-profile?edit=true');
                          }
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2196F3),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const SizedBox(height: 8),
                  // Age
                  if (user.age != null)
                    _buildInfoRow(Icons.calendar_today, 'Age', '${user.age} years'),
                  // Gender
                  if (user.gender != null)
                    _buildInfoRow(Icons.person_outline, 'Gender', user.gender!),
                  // Allergies
                  if (user.allergies != null && user.allergies!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning, size: 20, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Allergies',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: user.allergies!.map((allergy) {
                                  return Chip(
                                    label: Text(allergy),
                                    labelStyle: const TextStyle(fontSize: 12),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Past Conditions
                  if (user.pastConditions != null &&
                      user.pastConditions!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.medical_services,
                            size: 20, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Past Conditions',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: user.pastConditions!.map((condition) {
                                  return Chip(
                                    label: Text(condition),
                                    labelStyle: const TextStyle(fontSize: 12),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (user.age == null &&
                      user.gender == null &&
                      (user.allergies == null || user.allergies!.isEmpty) &&
                      (user.pastConditions == null ||
                          user.pastConditions!.isEmpty))
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'No medical information added yet.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildActionCard(
                context,
                Icons.search,
                'Find Doctor',
                Colors.blue,
                () {
                  try {
                    context.push('/doctor-search');
                  } catch (e) {
                    context.go('/doctor-search');
                  }
                },
              ),
              _buildActionCard(
                context,
                Icons.calendar_today,
                'Appointments',
                Colors.green,
                () {
                  try {
                    context.push('/patient-appointments');
                  } catch (e) {
                    context.go('/patient-appointments');
                  }
                },
              ),
              _buildActionCard(
                context,
                Icons.folder,
                'Medical Reports',
                Colors.orange,
                () {
                  try {
                    context.push('/medical-reports');
                  } catch (e) {
                    context.go('/medical-reports');
                  }
                },
              ),
              _buildActionCard(
                context,
                Icons.medication,
                'Prescriptions',
                Colors.purple,
                () {
                  try {
                    context.push('/patient-prescriptions');
                  } catch (e) {
                    context.go('/patient-prescriptions');
                  }
                },
              ),
              _buildActionCard(
                context,
                Icons.payment,
                'Pending Payments',
                Colors.orange,
                () {
                  try {
                    context.push('/pending-payments');
                  } catch (e) {
                    context.go('/pending-payments');
                  }
                },
              ),
              _buildActionCard(
                context,
                Icons.hearing,
                'Stethoscope',
                Colors.red,
                () {
                  try {
                    context.push('/patient-stethoscope');
                  } catch (e) {
                    context.go('/patient-stethoscope');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDefaultHome(user) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Welcome to EasyMed!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Logged in as: ${user.email}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'User Type: ${user.userType.toString().split('.').last.toUpperCase()}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (user.displayName != null) ...[
              const SizedBox(height: 8),
              Text('Name: ${user.displayName}', style: const TextStyle(fontSize: 16)),
            ],
            const SizedBox(height: 32),
            const Text(
              'Authentication is complete!',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.05),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorHome(BuildContext context, WidgetRef ref, user) {
    final isProfileComplete = user.specialization != null &&
        user.specialization!.isNotEmpty &&
        user.licenseNumber != null &&
        user.licenseNumber!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2196F3).withValues(alpha: 0.1),
                    const Color(0xFF2196F3).withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.medical_services,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName ?? 'Doctor',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isProfileComplete) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Complete your profile to start accepting appointments',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                try {
                                  context.push('/doctor-profile');
                                } catch (e) {
                                  context.go('/doctor-profile');
                                }
                              },
                              child: const Text('Complete Now'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Professional Information Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Professional Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          try {
                            context.push('/doctor-profile?edit=true');
                          } catch (e) {
                            context.go('/doctor-profile?edit=true');
                          }
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2196F3),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const SizedBox(height: 8),
                  // Specialization
                  if (user.specialization != null)
                    _buildInfoRow(
                      Icons.medical_services,
                      'Specialization',
                      user.specialization!,
                    ),
                  // Clinic Name
                  if (user.clinicName != null)
                    _buildInfoRow(
                      Icons.local_hospital,
                      'Clinic',
                      user.clinicName!,
                    ),
                  // License Number
                  if (user.licenseNumber != null)
                    _buildInfoRow(
                      Icons.badge,
                      'License Number',
                      user.licenseNumber!,
                    ),
                  // Consultation Fee
                  if (user.consultationFee != null)
                    _buildInfoRow(
                      Icons.attach_money,
                      'Consultation Fee',
                      '\$${user.consultationFee!.toStringAsFixed(2)}',
                    ),
                  // Working Hours
                  if (user.workingHours != null && user.workingHours!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time, size: 20, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Working Hours',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              ...user.workingHours!.entries.map((entry) {
                                if (entry.value is Map &&
                                    entry.value['enabled'] == true) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '${entry.key}: ${entry.value['start']} - ${entry.value['end']}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (user.specialization == null &&
                      user.clinicName == null &&
                      user.licenseNumber == null &&
                      user.consultationFee == null &&
                      (user.workingHours == null || user.workingHours!.isEmpty))
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'No professional information added yet.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildActionCard(
                context,
                Icons.calendar_today,
                'Appointments',
                Colors.blue,
                () {
                  try {
                    context.push('/doctor-appointments');
                  } catch (e) {
                    context.go('/doctor-appointments');
                  }
                },
              ),
              _buildActionCard(
                context,
                Icons.people,
                'My Patients',
                Colors.green,
                () {
                  try {
                    context.push('/doctor-patients');
                  } catch (e) {
                    context.go('/doctor-patients');
                  }
                },
              ),
              _buildActionCard(
                context,
                Icons.hearing,
                'View Stethoscope',
                Colors.red,
                () {
                  try {
                    context.push('/doctor-stethoscope');
                  } catch (e) {
                    context.go('/doctor-stethoscope');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

