import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/appointment_model.dart';
import '../../services/stream_video_service.dart';
import '../../services/appointment_service.dart';
import '../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  return AppointmentService();
});

class VideoCallScreen extends ConsumerStatefulWidget {
  final String appointmentId;

  const VideoCallScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  Call? _call;
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      // Directly get appointment from service instead of using provider
      // This ensures we get fresh data regardless of provider state
      final appointmentService = ref.read(appointmentServiceProvider);
      
      // Wait for appointment to be in progress (with timeout)
      AppointmentModel? appointment;
      int attempts = 0;
      const maxAttempts = 20; // 10 seconds total (20 * 500ms)
      
      while (attempts < maxAttempts && mounted) {
        try {
          appointment = await appointmentService.getAppointmentById(widget.appointmentId);
          
          if (appointment != null && appointment.status == AppointmentStatus.inProgress) {
            break; // Found appointment in progress
          }
        } catch (e) {
          debugPrint('Error fetching appointment: $e');
        }
        
        // Wait 500ms before checking again
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }
      
      if (appointment == null) {
        setState(() {
          _errorMessage = 'Appointment not found';
        });
        return;
      }

      // Check if appointment is in progress
      if (appointment.status != AppointmentStatus.inProgress) {
        setState(() {
          _errorMessage = 'Appointment is not in progress. Please wait for the doctor to start the appointment.';
        });
        return;
      }
      
      // Now proceed with initialization
      final currentUser = ref.read(authStateNotifierProvider).value;
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'User not logged in';
        });
        return;
      }

      // Request camera and microphone permissions
      try {
        final cameraStatus = await Permission.camera.request();
        final microphoneStatus = await Permission.microphone.request();
        
        if (!cameraStatus.isGranted || !microphoneStatus.isGranted) {
          setState(() {
            _isJoining = false;
            _errorMessage = 'Camera and microphone permissions are required for video calls. Please grant permissions in settings.';
          });
          return;
        }
        debugPrint('Camera and microphone permissions granted');
      } catch (e) {
        debugPrint('Error requesting permissions: $e');
        setState(() {
          _isJoining = false;
          _errorMessage = 'Failed to request permissions: ${e.toString()}';
        });
        return;
      }

      // Initialize Stream Video if not already initialized
      try {
        debugPrint('About to call StreamVideoService.initialize...');
        await StreamVideoService.initialize(currentUser);
        debugPrint('Stream Video initialized successfully');
      } catch (e, stackTrace) {
        debugPrint('Stream Video initialization error: $e');
        debugPrint('Full error type: ${e.runtimeType}');
        debugPrint('Stack trace: $stackTrace');
        setState(() {
          _isJoining = false;
          _errorMessage = 'Failed to initialize video call: ${e.toString()}';
        });
        return;
      }

      // Create or get call
      setState(() {
        _isJoining = true;
        _errorMessage = null;
      });

      try {
        _call = await StreamVideoService.makeCallForAppointment(appointment);
        debugPrint('Call created: ${_call!.id}');
        
        // Get or create the call on the backend with timeout
        await _call!.getOrCreate().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Timeout: Call creation took too long');
          },
        );
        debugPrint('Call getOrCreate completed');
        
        // Join the call with timeout
        await _call!.join().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Timeout: Joining call took too long');
          },
        );
        debugPrint('Call join completed');
        
        // Wait a bit for call state to update
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          setState(() {
            _isJoining = false;
          });
        }
      } catch (e, stackTrace) {
        debugPrint('Error joining call: $e');
        debugPrint('Stack trace: $stackTrace');
        if (mounted) {
          setState(() {
            _isJoining = false;
            _errorMessage = 'Failed to join video call: ${e.toString()}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isJoining = false;
        _errorMessage = 'Error initializing call: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    // Leave call when screen is disposed
    if (_call != null) {
      _call!.leave();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentAsync = ref.watch(appointmentDetailsProvider(widget.appointmentId));

    return appointmentAsync.when(
      data: (appointment) {
        if (appointment == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Video Call')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Appointment not found'),
                ],
              ),
            ),
          );
        }

        // Check if appointment is in progress
        if (appointment.status != AppointmentStatus.inProgress) {
          return Scaffold(
            appBar: AppBar(title: const Text('Video Call')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.schedule, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'Appointment is not in progress',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please wait for the doctor to start the appointment.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Show error if any
        if (_errorMessage != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Video Call')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _initializeCall();
                      },
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Show loading while joining
        if (_isJoining || _call == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Video Call'),
              automaticallyImplyLeading: false,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Joining video call...'),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          );
        }

        // Show Stream call UI
        return Scaffold(
          body: StreamCallContainer(
            call: _call!,
          ),
        );
      },
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading appointment...'),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Video Call')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${error.toString()}'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(appointmentDetailsProvider(widget.appointmentId)),
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

