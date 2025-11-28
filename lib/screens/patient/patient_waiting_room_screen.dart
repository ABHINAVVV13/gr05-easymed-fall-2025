import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../services/appointment_service.dart';
import '../../services/doctor_service.dart';
import 'package:intl/intl.dart';

final doctorServiceProvider = Provider<DoctorService>((ref) {
  return DoctorService();
});

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  return AppointmentService();
});

final appointmentDetailsProvider = StreamProvider.family<AppointmentModel?, String>((ref, appointmentId) {
  return FirebaseFirestore.instance
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

class PatientWaitingRoomScreen extends ConsumerStatefulWidget {
  final String appointmentId;

  const PatientWaitingRoomScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  ConsumerState<PatientWaitingRoomScreen> createState() => _PatientWaitingRoomScreenState();
}

class _PatientWaitingRoomScreenState extends ConsumerState<PatientWaitingRoomScreen> {
  DateTime? _joinedAt;
  bool _hasLeft = false;
  bool _hasNavigatedToCall = false;

  @override
  void initState() {
    super.initState();
    _joinWaitingRoom();
  }

  Future<void> _joinWaitingRoom() async {
    try {
      final appointmentService = ref.read(appointmentServiceProvider);
      final appointment = await appointmentService.getAppointmentById(widget.appointmentId);
      
      if (appointment != null && appointment.waitingRoomJoinedAt == null) {
        await appointmentService.joinWaitingRoom(widget.appointmentId);
        setState(() {
          _joinedAt = DateTime.now();
        });
      } else if (appointment != null && appointment.waitingRoomJoinedAt != null) {
        setState(() {
          _joinedAt = appointment.waitingRoomJoinedAt;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining waiting room: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveWaitingRoom() async {
    try {
      final appointmentService = ref.read(appointmentServiceProvider);
      await appointmentService.leaveWaitingRoom(widget.appointmentId);
      setState(() {
        _hasLeft = true;
      });
      
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving waiting room: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentAsync = ref.watch(appointmentDetailsProvider(widget.appointmentId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave Waiting Room?'),
            content: const Text('Are you sure you want to leave the waiting room? You can rejoin later.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Leave'),
              ),
            ],
          ),
        );

        if (shouldLeave == true) {
          await _leaveWaitingRoom();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Waiting Room'),
          automaticallyImplyLeading: false,
        ),
        body: appointmentAsync.when(
          data: (appointment) {
            if (appointment == null) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text('Appointment not found'),
                  ],
                ),
              );
            }

            // If appointment status changed to inProgress, navigate to video call
            if (appointment.status == AppointmentStatus.inProgress && !_hasNavigatedToCall) {
              _hasNavigatedToCall = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  // TODO: Navigate to video call when implemented
                  // context.push('/video-call/${appointment.id}');
                }
              });
            }

            // If patient left waiting room, show message
            if (_hasLeft || appointment.waitingRoomLeftAt != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text(
                      'You have left the waiting room',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }

            return _buildWaitingRoomContent(context, appointment);
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
                  onPressed: () => ref.invalidate(appointmentDetailsProvider(widget.appointmentId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingRoomContent(BuildContext context, AppointmentModel appointment) {
    final waitTime = _joinedAt != null 
        ? DateTime.now().difference(_joinedAt!).inMinutes 
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Waiting animation
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty,
              size: 64,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 32),
          // Status text
          const Text(
            'Waiting for Doctor',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while the doctor prepares',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          // Wait time
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.access_time, size: 32, color: Colors.blue),
                  const SizedBox(height: 12),
                  Text(
                    'Wait Time',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$waitTime ${waitTime == 1 ? 'minute' : 'minutes'}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Appointment details
          FutureBuilder<UserModel?>(
            future: ref.read(doctorServiceProvider).getDoctorById(appointment.doctorId),
            builder: (context, snapshot) {
              final doctor = snapshot.data;
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Appointment Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (doctor != null) ...[
                        _buildDetailRow(Icons.person, 'Doctor', doctor.displayName ?? 'Doctor'),
                        const SizedBox(height: 12),
                      ],
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Date',
                        _formatDate(appointment.scheduledTime),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.access_time,
                        'Time',
                        _formatTime(appointment.scheduledTime),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.category,
                        'Type',
                        appointment.type == AppointmentType.instant ? 'Instant Consultation' : 'Scheduled',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          // Leave button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _leaveWaitingRoom,
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Leave Waiting Room'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final appointmentDate = DateTime(date.year, date.month, date.day);

    if (appointmentDate == today) {
      return 'Today';
    } else if (appointmentDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
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

