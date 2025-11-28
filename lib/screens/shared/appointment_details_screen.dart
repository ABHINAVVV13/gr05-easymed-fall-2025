import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../services/doctor_service.dart';
import '../../providers/auth_provider.dart';

final _firestore = FirebaseFirestore.instance;

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  return AppointmentService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final doctorServiceProvider = Provider<DoctorService>((ref) {
  return DoctorService();
});

final appointmentDetailsProvider = StreamProvider.family<AppointmentModel?, String>((ref, appointmentId) {
  return _firestore
      .collection('appointments')
      .doc(appointmentId)
      .snapshots()
      .map((doc) {
        if (doc.exists && doc.data() != null) {
          return AppointmentModel.fromMap(doc.data()!);
        }
        return null;
      });
});

class AppointmentDetailsScreen extends ConsumerWidget {
  final String appointmentId;

  const AppointmentDetailsScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentAsync = ref.watch(appointmentDetailsProvider(appointmentId));
    final currentUser = ref.watch(authStateNotifierProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
      ),
      body: appointmentAsync.when(
        data: (appointment) {
          if (appointment == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Appointment not found'),
                ],
              ),
            );
          }

          final isPatient = currentUser?.userType == UserType.patient;
          final isDoctor = currentUser?.userType == UserType.doctor;
          final canCancel = isPatient && 
                           appointment.status == AppointmentStatus.scheduled &&
                           appointment.scheduledTime.isAfter(DateTime.now());
          final canComplete = isDoctor && 
                             (appointment.status == AppointmentStatus.scheduled || appointment.status == AppointmentStatus.inProgress) &&
                             appointment.doctorId == currentUser?.uid;
          final canStart = isDoctor && 
                          appointment.status == AppointmentStatus.scheduled &&
                          appointment.doctorId == currentUser?.uid;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(appointment.status),
                          color: _getStatusColor(appointment.status),
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Status',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getStatusLabel(appointment.status),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(appointment.status),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Appointment Info
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Appointment Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Date',
                          _formatDate(appointment.scheduledTime),
                        ),
                        _buildInfoRow(
                          Icons.access_time,
                          'Time',
                          _formatTime(appointment.scheduledTime),
                        ),
                        _buildInfoRow(
                          Icons.category,
                          'Type',
                          appointment.type == AppointmentType.instant ? 'Instant' : 'Scheduled',
                        ),
                        // Questionnaire Data (for doctors)
                        if (isDoctor && appointment.symptoms != null && appointment.symptoms!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'Patient Symptoms',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: appointment.symptoms!.map((symptom) {
                              return Chip(
                                label: Text(symptom),
                                backgroundColor: Colors.blue.shade50,
                              );
                            }).toList(),
                          ),
                          if (appointment.severity != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.warning,
                              'Severity',
                              appointment.severity!.toUpperCase(),
                            ),
                          ],
                          if (appointment.duration != null) ...[
                            _buildInfoRow(
                              Icons.access_time,
                              'Duration',
                              appointment.duration!,
                            ),
                          ],
                          if (appointment.aiRecommendation != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.psychology,
                                        color: Colors.blue.shade700,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'AI Recommendation',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    appointment.aiRecommendation!,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (appointment.aiGeneratedConversation != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.medical_information,
                                        color: Colors.green.shade700,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'AI Generated Medical Summary',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    appointment.aiGeneratedConversation!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        // Notes
                        if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'Additional Notes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              appointment.notes!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // User Info (Doctor for patients, Patient for doctors)
                FutureBuilder<UserModel?>(
                  future: isPatient
                      ? ref.read(doctorServiceProvider).getDoctorById(appointment.doctorId)
                      : ref.read(authServiceProvider).getUserData(appointment.patientId),
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
                      // Show basic info even if user data can't be loaded
                      return Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPatient ? 'Doctor' : 'Patient',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isPatient 
                                    ? 'Doctor ID: ${appointment.doctorId}'
                                    : 'Patient ID: ${appointment.patientId}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (snapshot.hasError) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Unable to load full profile',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPatient ? 'Doctor' : 'Patient',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: const Color(0xFF2196F3),
                                  child: Text(
                                    user.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
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
                                      if (isDoctor && user.age != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Age: ${user.age}',
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
                const SizedBox(height: 24),
                // Join Video Call button (for in-progress appointments)
                if (appointment.status == AppointmentStatus.inProgress) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Navigate to video call when implemented
                        // context.push('/video-call/${appointment.id}');
                      },
                      icon: const Icon(Icons.video_call),
                      label: const Text('Join Video Call'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Join Waiting Room button (for patients with scheduled appointments)
                if (isPatient && 
                    appointment.status == AppointmentStatus.scheduled &&
                    appointment.waitingRoomJoinedAt == null &&
                    appointment.waitingRoomLeftAt == null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Navigate to waiting room when implemented
                        // context.push('/patient-waiting-room/${appointment.id}');
                      },
                      icon: const Icon(Icons.meeting_room),
                      label: const Text('Join Waiting Room'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Action Buttons
                if (canCancel || canStart || canComplete) ...[
                  if (canCancel)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelAppointment(context, ref, appointment),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel Appointment'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  if (canStart) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(context, ref, appointment, AppointmentStatus.inProgress),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Appointment'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                  if (canComplete) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(context, ref, appointment, AppointmentStatus.completed),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Mark as Completed'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                  // Create Prescription button (for doctors on completed/inProgress appointments)
                  if (isDoctor &&
                      appointment.doctorId == currentUser?.uid &&
                      (appointment.status == AppointmentStatus.inProgress ||
                          appointment.status == AppointmentStatus.completed)) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context.push('/create-prescription?appointmentId=${appointment.id}');
                        },
                        icon: const Icon(Icons.medication),
                        label: const Text('Create Prescription'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF2196F3)),
                          foregroundColor: const Color(0xFF2196F3),
                        ),
                      ),
                    ),
                  ],
                  // View Prescription button (if prescription exists)
                  if (appointment.prescriptionId != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push('/prescription-details/${appointment.prescriptionId}');
                        },
                        icon: const Icon(Icons.medication),
                        label: const Text('View Prescription'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.purple,
                        ),
                      ),
                    ),
                  ],
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
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(appointmentDetailsProvider(appointmentId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
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
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  IconData _getStatusIcon(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return Icons.calendar_today;
      case AppointmentStatus.inProgress:
        return Icons.play_circle;
      case AppointmentStatus.completed:
        return Icons.check_circle;
      case AppointmentStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return Colors.blue;
      case AppointmentStatus.inProgress:
        return Colors.orange;
      case AppointmentStatus.completed:
        return Colors.green;
      case AppointmentStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return 'Scheduled';
      case AppointmentStatus.inProgress:
        return 'In Progress';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _cancelAppointment(BuildContext context, WidgetRef ref, AppointmentModel appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final appointmentService = ref.read(appointmentServiceProvider);
      await appointmentService.cancelAppointment(appointment.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Streams will auto-update, no need to invalidate
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling appointment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, AppointmentModel appointment, AppointmentStatus newStatus) async {
    try {
      final appointmentService = ref.read(appointmentServiceProvider);
      await appointmentService.updateAppointmentStatus(appointment.id, newStatus);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment ${newStatus == AppointmentStatus.inProgress ? 'started' : 'completed'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Streams will auto-update, no need to invalidate
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating appointment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

