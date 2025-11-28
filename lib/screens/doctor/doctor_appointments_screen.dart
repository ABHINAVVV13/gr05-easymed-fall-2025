import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  return AppointmentService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final doctorAppointmentsProvider = StreamProvider<List<AppointmentModel>>((ref) {
  final currentUser = ref.watch(authStateNotifierProvider).value;
  if (currentUser == null) {
    return Stream.value([]);
  }
  
  final appointmentService = ref.read(appointmentServiceProvider);
  return appointmentService.getDoctorAppointmentsStream(currentUser.uid);
});

class DoctorAppointmentsScreen extends ConsumerWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(doctorAppointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final currentUser = ref.watch(authStateNotifierProvider).value;
              if (currentUser == null) return const SizedBox.shrink();
              
              return StreamBuilder<List<AppointmentModel>>(
                stream: ref.read(appointmentServiceProvider).getWaitingPatientsStream(currentUser.uid),
                builder: (context, snapshot) {
                  final waitingCount = snapshot.data?.length ?? 0;
                  return IconButton(
                    icon: Stack(
                      children: [
                        const Icon(Icons.meeting_room),
                        if (waitingCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                waitingCount > 9 ? '9+' : '$waitingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () {
                      context.push('/doctor-waiting-room');
                    },
                    tooltip: 'Waiting Room',
                  );
                },
              );
            },
          ),
        ],
      ),
      body: appointmentsAsync.when(
        data: (appointments) {
          if (appointments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No appointments yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Patients will be able to book appointments with you',
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

          // Separate upcoming and past appointments
          final now = DateTime.now();
          final upcoming = appointments
              .where((apt) => apt.scheduledTime.isAfter(now) && apt.status != AppointmentStatus.cancelled)
              .toList()
            ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
          
          final past = appointments
              .where((apt) => apt.scheduledTime.isBefore(now) || apt.status == AppointmentStatus.cancelled)
              .toList()
            ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));

          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(doctorAppointmentsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (upcoming.isNotEmpty) ...[
                  Row(
                    children: [
                      const Text(
                        'Upcoming',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.refresh,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Live',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...upcoming.map((appointment) => _AppointmentCard(
                    appointment: appointment,
                    onTap: () => context.push('/appointment-details/${appointment.id}'),
                  )),
                  const SizedBox(height: 24),
                ],
                if (past.isNotEmpty) ...[
                  const Text(
                    'Past',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...past.map((appointment) => _AppointmentCard(
                    appointment: appointment,
                    onTap: () => context.push('/appointment-details/${appointment.id}'),
                  )),
                ],
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
              Text(
                'Error loading appointments: ${error.toString()}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(doctorAppointmentsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  final AppointmentModel appointment;
  final VoidCallback onTap;

  const _AppointmentCard({
    required this.appointment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<UserModel?>(
      future: _getPatient(ref, appointment.patientId),
      builder: (context, snapshot) {
        final patient = snapshot.data;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF2196F3),
                        child: Text(
                          patient?.displayName?.substring(0, 1).toUpperCase() ?? 'P',
                          style: const TextStyle(
                            fontSize: 18,
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
                              patient?.displayName ?? 'Patient',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (patient?.age != null || patient?.gender != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (patient!.age != null) 'Age: ${patient.age}',
                                  if (patient.gender != null) patient.gender!,
                                ].join(', '),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _StatusChip(status: appointment.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(appointment.scheduledTime),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(appointment.scheduledTime),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<UserModel?> _getPatient(WidgetRef ref, String patientId) async {
    try {
      final authService = ref.read(authServiceProvider);
      return await authService.getUserData(patientId);
    } catch (e) {
      return null;
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointmentDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (appointmentDate == today) {
      return 'Today';
    } else if (appointmentDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
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

class _StatusChip extends StatelessWidget {
  final AppointmentStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case AppointmentStatus.scheduled:
        color = Colors.blue;
        label = 'Scheduled';
        break;
      case AppointmentStatus.inProgress:
        color = Colors.orange;
        label = 'In Progress';
        break;
      case AppointmentStatus.completed:
        color = Colors.green;
        label = 'Completed';
        break;
      case AppointmentStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

