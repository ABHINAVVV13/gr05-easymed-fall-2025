import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  return AppointmentService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Provider to get waiting patients for current doctor
final waitingPatientsProvider = StreamProvider<List<AppointmentModel>>((ref) {
  final currentUser = ref.watch(authStateNotifierProvider).value;
  if (currentUser == null || currentUser.userType != UserType.doctor) {
    return Stream.value([]);
  }
  
  final appointmentService = ref.read(appointmentServiceProvider);
  return appointmentService.getWaitingPatientsStream(currentUser.uid);
});

class DoctorWaitingRoomScreen extends ConsumerWidget {
  const DoctorWaitingRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateNotifierProvider).value;
    
    if (currentUser == null || currentUser.userType != UserType.doctor) {
      return Scaffold(
        appBar: AppBar(title: const Text('Waiting Room')),
        body: const Center(
          child: Text('Access denied. Doctor account required.'),
        ),
      );
    }

    final waitingPatientsAsync = ref.watch(waitingPatientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(waitingPatientsProvider);
            },
          ),
        ],
      ),
      body: waitingPatientsAsync.when(
        data: (waitingPatients) {
          if (waitingPatients.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No patients waiting',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Patients will appear here when they join the waiting room',
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
              ref.invalidate(waitingPatientsProvider);
              await ref.read(waitingPatientsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: waitingPatients.length,
              itemBuilder: (context, index) {
                final appointment = waitingPatients[index];
                return _WaitingPatientCard(
                  appointment: appointment,
                  queuePosition: index + 1,
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
                onPressed: () => ref.invalidate(waitingPatientsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingPatientCard extends ConsumerWidget {
  final AppointmentModel appointment;
  final int queuePosition;

  const _WaitingPatientCard({
    required this.appointment,
    required this.queuePosition,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waitTime = appointment.waitingRoomJoinedAt != null
        ? DateTime.now().difference(appointment.waitingRoomJoinedAt!).inMinutes
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Queue position badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: queuePosition == 1 ? Colors.green.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        queuePosition == 1 ? Icons.next_plan : Icons.queue,
                        size: 16,
                        color: queuePosition == 1 ? Colors.green.shade700 : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Position #$queuePosition',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: queuePosition == 1 ? Colors.green.shade700 : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Wait time
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${waitTime}m',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Patient info
            FutureBuilder<UserModel?>(
              future: ref.read(authServiceProvider).getUserData(appointment.patientId),
              builder: (context, snapshot) {
                final patient = snapshot.data;
                return Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          (patient?.displayName ?? 'P').substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient?.displayName ?? 'Patient',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            appointment.type == AppointmentType.instant
                                ? 'Instant Consultation'
                                : _formatDateTime(appointment.scheduledTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            // Symptoms preview (if available)
            if (appointment.symptoms != null && appointment.symptoms!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.medical_services, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Symptoms',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: appointment.symptoms!.take(3).map((symptom) {
                        return Chip(
                          label: Text(
                            symptom,
                            style: const TextStyle(fontSize: 11),
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                    if (appointment.symptoms!.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+${appointment.symptoms!.length - 3} more',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/appointment-details/${appointment.id}');
                    },
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _startAppointment(context, ref, appointment),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startAppointment(BuildContext context, WidgetRef ref, AppointmentModel appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Appointment?'),
        content: const Text('This will notify the patient and begin the consultation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final appointmentService = ref.read(appointmentServiceProvider);
      await appointmentService.updateAppointmentStatus(appointment.id, AppointmentStatus.inProgress);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment started! Patient has been notified.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Wait a moment for the status update to propagate
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Navigate to video call screen
        if (context.mounted) {
          // TODO: Navigate to video call when implemented
          // context.push('/video-call/${appointment.id}');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting appointment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointmentDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (appointmentDate == today) {
      return 'Today at ${_formatTime(dateTime)}';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}

