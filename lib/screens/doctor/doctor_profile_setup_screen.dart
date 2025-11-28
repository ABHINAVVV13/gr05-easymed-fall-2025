import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../constants/doctor_constants.dart';

class DoctorProfileSetupScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final UserModel? initialUser;

  const DoctorProfileSetupScreen({
    super.key,
    this.isEditing = false,
    this.initialUser,
  });

  @override
  ConsumerState<DoctorProfileSetupScreen> createState() =>
      _DoctorProfileSetupScreenState();
}

class _DoctorProfileSetupScreenState
    extends ConsumerState<DoctorProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clinicNameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _consultationFeeController = TextEditingController();

  bool _isLoading = false;
  String? _selectedSpecialization;
  final Map<String, Map<String, dynamic>> _workingHours = {
    for (final day in DoctorConstants.weekDays)
      day: {
        'enabled': false,
        'start': DoctorConstants.defaultStartTime,
        'end': DoctorConstants.defaultEndTime,
      },
  };

  // Use shared constants for specializations
  static const List<String> specializations = DoctorConstants.specializations;

  // Normalize specialization value to match dropdown options
  // Handles typos and case mismatches
  String? _normalizeSpecialization(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final normalized = value.trim();
    
    // Direct match
    if (specializations.contains(normalized)) {
      return normalized;
    }
    
    // Case-insensitive match
    for (final spec in specializations) {
      if (spec.toLowerCase() == normalized.toLowerCase()) {
        return spec;
      }
    }
    
    // Common typo fixes
    final typoMap = {
      'cardialogy': 'Cardiology',
      'cardiology': 'Cardiology',
      'dermatology': 'Dermatology',
      'pediatrics': 'Pediatrics',
      'orthopedics': 'Orthopedics',
      'neurology': 'Neurology',
      'general medicine': 'General Medicine',
      'general': 'General Medicine',
    };
    
    final lowerValue = normalized.toLowerCase();
    if (typoMap.containsKey(lowerValue)) {
      return typoMap[lowerValue];
    }
    
    // If no match found, return null (user will need to reselect)
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialUser != null) {
      final user = widget.initialUser!;
      _selectedSpecialization = _normalizeSpecialization(user.specialization);
      _clinicNameController.text = user.clinicName ?? '';
      _licenseNumberController.text = user.licenseNumber ?? '';
      if (user.consultationFee != null) {
        _consultationFeeController.text = user.consultationFee.toString();
      }
      if (user.workingHours != null) {
        user.workingHours!.forEach((day, value) {
          if (value is Map) {
            _workingHours[day] = {
              'enabled': value['enabled'] ?? false,
              'start': value['start'] ?? DoctorConstants.defaultStartTime,
              'end': value['end'] ?? DoctorConstants.defaultEndTime,
            };
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _clinicNameController.dispose();
    _licenseNumberController.dispose();
    _consultationFeeController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(
      BuildContext context, String day, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        final timeString =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (isStart) {
          _workingHours[day]!['start'] = timeString;
        } else {
          _workingHours[day]!['end'] = timeString;
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(authStateNotifierProvider).value;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Parse consultation fee
      double? consultationFee;
      if (_consultationFeeController.text.trim().isNotEmpty) {
        consultationFee = double.tryParse(_consultationFeeController.text.trim());
        if (consultationFee == null || consultationFee < 0) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid consultation fee'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Convert working hours to the format expected by UserModel
      final workingHoursMap = <String, dynamic>{};
      _workingHours.forEach((day, value) {
        if (value['enabled'] == true) {
          workingHoursMap[day] = {
            'enabled': true,
            'start': value['start'] as String,
            'end': value['end'] as String,
          };
        }
      });

      final updatedUser = currentUser.copyWith(
        specialization: _selectedSpecialization,
        clinicName: _clinicNameController.text.trim().isEmpty
            ? null
            : _clinicNameController.text.trim(),
        licenseNumber: _licenseNumberController.text.trim().isEmpty
            ? null
            : _licenseNumberController.text.trim(),
        consultationFee: consultationFee,
        workingHours: workingHoursMap.isEmpty ? null : workingHoursMap,
        updatedAt: DateTime.now(),
      );

      await ref.read(authStateNotifierProvider.notifier).updateUserData(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing
                ? 'Profile updated successfully!'
                : 'Profile created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (!widget.isEditing) {
          if (mounted) {
            context.go('/home');
          }
        } else {
          if (mounted) {
            context.pop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Complete Your Profile'),
          content: const Text(
            'Please complete your profile to use EasyMed. This information helps patients find and book appointments with you.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(authStateNotifierProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Profile' : 'Complete Your Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.isEditing) {
              context.pop();
            } else {
              _showExitConfirmationDialog();
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isEditing) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Complete your profile to start accepting appointments',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const Text(
                'Professional Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please provide your professional information to help patients find you.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              // Specialization dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedSpecialization != null && specializations.contains(_selectedSpecialization)
                    ? _selectedSpecialization
                    : null,
                decoration: InputDecoration(
                  labelText: 'Specialization *',
                  prefixIcon: const Icon(Icons.medical_services),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: _selectedSpecialization == null && widget.isEditing && widget.initialUser?.specialization != null
                      ? 'Previous value "${widget.initialUser!.specialization}" not recognized. Please reselect.'
                      : 'Select your medical specialization',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: specializations.map((specialization) {
                  return DropdownMenuItem(
                    value: specialization,
                    child: Text(specialization),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSpecialization = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your specialization';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Clinic name field
              TextFormField(
                controller: _clinicNameController,
                decoration: InputDecoration(
                  labelText: 'Clinic/Hospital Name',
                  prefixIcon: const Icon(Icons.local_hospital),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Optional',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),
              // License number field
              TextFormField(
                controller: _licenseNumberController,
                decoration: InputDecoration(
                  labelText: 'License Number *',
                  prefixIcon: const Icon(Icons.badge),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Your medical license number',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your license number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Consultation fee field
              TextFormField(
                controller: _consultationFeeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Consultation Fee',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Fee per consultation (optional)',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final fee = double.tryParse(value.trim());
                    if (fee == null || fee < 0) {
                      return 'Please enter a valid fee amount';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              // Working hours section
              const Text(
                'Working Hours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ..._workingHours.keys.map((day) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                day,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Switch(
                              value: _workingHours[day]!['enabled'] as bool,
                              onChanged: (value) {
                                setState(() {
                                  _workingHours[day]!['enabled'] = value;
                                });
                              },
                            ),
                          ],
                        ),
                        if (_workingHours[day]!['enabled'] as bool) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _selectTime(context, day, true),
                                  icon: const Icon(Icons.access_time, size: 18),
                                  label: Text(_workingHours[day]!['start'] as String),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('to'),
                              ),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _selectTime(context, day, false),
                                  icon: const Icon(Icons.access_time, size: 18),
                                  label: Text(_workingHours[day]!['end'] as String),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 40),
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
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
                      : Text(
                          widget.isEditing ? 'Update Profile' : 'Save & Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

