import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../services/appointment_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/symptom_questionnaire_widget.dart';
import '../../services/doctor_service.dart';

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  return AppointmentService();
});

final doctorServiceProvider = Provider<DoctorService>((ref) {
  return DoctorService();
});

class AppointmentBookingScreen extends ConsumerStatefulWidget {
  final String doctorId;
  final bool isInstant;

  const AppointmentBookingScreen({
    super.key,
    required this.doctorId,
    this.isInstant = false,
  });

  @override
  ConsumerState<AppointmentBookingScreen> createState() =>
      _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState
    extends ConsumerState<AppointmentBookingScreen> {
  int _currentStep = 0; // 0 = questionnaire, 1 = date/time selection
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _notesController = TextEditingController();
  bool _isLoading = false;
  bool _checkingAvailability = false;
  String? _availabilityError;
  UserModel? _doctor;
  // Questionnaire data
  Map<String, dynamic>? _questionnaireData;

  @override
  void initState() {
    super.initState();
    _loadDoctor();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctor() async {
    try {
      final doctorService = ref.read(doctorServiceProvider);
      final doctor = await doctorService.getDoctorById(widget.doctorId);
      if (mounted) {
        setState(() {
          _doctor = doctor;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading doctor: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null; // Reset time when date changes
        _availabilityError = null;
      });
    }
  }

  Future<void> _selectTime() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _availabilityError = null;
      });
      await _checkAvailability();
    }
  }

  Future<void> _checkAvailability() async {
    if (_selectedDate == null || _selectedTime == null) return;

    setState(() {
      _checkingAvailability = true;
      _availabilityError = null;
    });

    try {
      final appointmentService = ref.read(appointmentServiceProvider);
      final dateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Check if date is in the past
      if (dateTime.isBefore(DateTime.now())) {
        setState(() {
          _availabilityError = 'Cannot book appointments in the past';
          _checkingAvailability = false;
        });
        return;
      }

      // Check doctor working hours if available
      if (_doctor?.workingHours != null) {
        final dayName = _getDayName(dateTime.weekday);
        final daySchedule = _doctor!.workingHours![dayName];
        
        if (daySchedule == null || daySchedule['enabled'] != true) {
          setState(() {
            _availabilityError = 'Doctor is not available on $dayName';
            _checkingAvailability = false;
          });
          return;
        }

        final startTime = _parseTime(daySchedule['start'] as String);
        final endTime = _parseTime(daySchedule['end'] as String);
        final selectedTimeOfDay = TimeOfDay(
          hour: _selectedTime!.hour,
          minute: _selectedTime!.minute,
        );

        if (!_isTimeInRange(selectedTimeOfDay, startTime, endTime)) {
          setState(() {
            _availabilityError =
                'Doctor is available ${daySchedule['start']} - ${daySchedule['end']} on $dayName';
            _checkingAvailability = false;
          });
          return;
        }
      }

      final isAvailable = await appointmentService.isDoctorAvailable(
        widget.doctorId,
        dateTime,
      );

      setState(() {
        _checkingAvailability = false;
        if (!isAvailable) {
          _availabilityError = 'Doctor is not available at this time. Please choose another time.';
        }
      });
    } catch (e) {
      setState(() {
        _checkingAvailability = false;
        _availabilityError = 'Error checking availability: ${e.toString()}';
      });
    }
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  bool _isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
  }

  Future<void> _bookAppointment() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date and time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_availabilityError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_availabilityError!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(authStateNotifierProvider).value;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final appointmentService = ref.read(appointmentServiceProvider);
      final dateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Double-check availability before booking
      final isAvailable = await appointmentService.isDoctorAvailable(
        widget.doctorId,
        dateTime,
      );

      if (!isAvailable) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor is no longer available at this time. Please choose another time.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final appointment = AppointmentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: currentUser.uid,
        doctorId: widget.doctorId,
        scheduledTime: dateTime,
        type: AppointmentType.scheduled,
        status: AppointmentStatus.scheduled,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        symptoms: _questionnaireData?['symptoms'] as List<String>?,
        severity: _questionnaireData?['severity'] as String?,
        duration: _questionnaireData?['duration'] as String?,
        aiRecommendation: _questionnaireData?['aiRecommendation'] as String?,
        recommendedSpecializations: _questionnaireData?['recommendedSpecializations'] as List<String>?,
        aiGeneratedConversation: _questionnaireData?['aiGeneratedConversation'] as String?,
        createdAt: DateTime.now(),
      );

      await appointmentService.createAppointment(appointment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          // Navigate to waiting room (will be implemented in later branch)
          // For now, just go back
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking appointment: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _onQuestionnaireComplete(Map<String, dynamic> data) {
    setState(() {
      _questionnaireData = data.isEmpty ? null : data;
      if (widget.isInstant) {
        // For instant consultation, book immediately after questionnaire
        _bookInstantAppointment();
      } else {
        // For scheduled, go to date/time selection
        _currentStep = 1;
      }
    });
  }

  Future<void> _bookInstantAppointment() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(authStateNotifierProvider).value;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final appointmentService = ref.read(appointmentServiceProvider);
      final appointment = AppointmentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: currentUser.uid,
        doctorId: widget.doctorId,
        scheduledTime: DateTime.now(),
        type: AppointmentType.instant,
        status: AppointmentStatus.scheduled, // Start as scheduled, doctor will start it
        symptoms: _questionnaireData?['symptoms'] as List<String>?,
        severity: _questionnaireData?['severity'] as String?,
        duration: _questionnaireData?['duration'] as String?,
        aiRecommendation: _questionnaireData?['aiRecommendation'] as String?,
        recommendedSpecializations: _questionnaireData?['recommendedSpecializations'] as List<String>?,
        aiGeneratedConversation: _questionnaireData?['aiGeneratedConversation'] as String?,
        createdAt: DateTime.now(),
      );

      await appointmentService.createAppointment(appointment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joining waiting room...'),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          // Navigate to waiting room (will be implemented in later branch)
          // For now, just go back
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting consultation: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        leading: _currentStep == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() => _currentStep = 0);
                },
              )
            : null,
      ),
      body: _currentStep == 0
          ? Padding(
              padding: const EdgeInsets.all(24.0),
              child: SymptomQuestionnaireWidget(
                onComplete: _onQuestionnaireComplete,
                showSkip: true,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Doctor Info Card
                  if (_doctor != null)
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF2196F3),
                              child: Text(
                                _doctor!.displayName?.substring(0, 1).toUpperCase() ?? 'D',
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
                                    _doctor!.displayName ?? 'Doctor',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_doctor!.specialization != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _doctor!.specialization!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
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
                  // Date Selection
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Date',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _selectedDate == null
                                  ? 'Choose Date'
                                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Time Selection
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Time',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _selectedDate == null ? null : _selectTime,
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              _selectedTime == null
                                  ? 'Choose Time'
                                  : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                          if (_checkingAvailability) ...[
                            const SizedBox(height: 12),
                            const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ],
                          if (_availabilityError != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 20, color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _availabilityError!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade700,
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
                  ),
                  const SizedBox(height: 16),
                  // Notes Field
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Additional Notes (Optional)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Any symptoms, concerns, or questions...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Book Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _availabilityError != null)
                          ? null
                          : _bookAppointment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Book Appointment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

