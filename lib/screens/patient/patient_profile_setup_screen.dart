import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

// Constants for validation and UI
class _PatientProfileConstants {
  static const int minAge = 0;
  static const int maxAge = 150;
  static const int snackbarDurationSeconds = 2;
  static const int errorSnackbarDurationSeconds = 4;
  static const int navigationDelayMs = 500;
}

class PatientProfileSetupScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final UserModel? initialUser;

  const PatientProfileSetupScreen({
    super.key,
    this.isEditing = false,
    this.initialUser,
  });

  @override
  ConsumerState<PatientProfileSetupScreen> createState() =>
      _PatientProfileSetupScreenState();
}

class _PatientProfileSetupScreenState
    extends ConsumerState<PatientProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _allergyController = TextEditingController();
  final _conditionController = TextEditingController();

  String? _selectedGender;
  List<String> _allergies = [];
  List<String> _pastConditions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialUser != null) {
      final user = widget.initialUser!;
      if (user.age != null) {
        _ageController.text = user.age.toString();
      }
      _selectedGender = user.gender;
      _allergies = List<String>.from(user.allergies ?? []);
      _pastConditions = List<String>.from(user.pastConditions ?? []);
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _allergyController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  void _addAllergy() {
    final allergy = _allergyController.text.trim();
    if (allergy.isEmpty) {
      return;
    }
    
    // Normalize allergy text (capitalize first letter)
    final normalizedAllergy = allergy.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    if (!_allergies.contains(normalizedAllergy)) {
      setState(() {
        _allergies.add(normalizedAllergy);
        _allergyController.clear();
      });
      FocusScope.of(context).unfocus();
    } else {
      // Show feedback if allergy already exists
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This allergy has already been added'),
          duration: const Duration(seconds: _PatientProfileConstants.snackbarDurationSeconds),
        ),
      );
    }
  }

  void _removeAllergy(String allergy) {
    setState(() {
      _allergies.remove(allergy);
    });
  }

  void _addCondition() {
    final condition = _conditionController.text.trim();
    if (condition.isEmpty) {
      return;
    }
    
    // Normalize condition text (capitalize first letter)
    final normalizedCondition = condition.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    
    if (!_pastConditions.contains(normalizedCondition)) {
      setState(() {
        _pastConditions.add(normalizedCondition);
        _conditionController.clear();
      });
      FocusScope.of(context).unfocus();
    } else {
      // Show feedback if condition already exists
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This condition has already been added'),
          duration: const Duration(seconds: _PatientProfileConstants.snackbarDurationSeconds),
        ),
      );
    }
  }

  void _removeCondition(String condition) {
    setState(() {
      _pastConditions.remove(condition);
    });
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

      // Parse age - make it optional
      int? age;
      if (_ageController.text.trim().isNotEmpty) {
        age = int.tryParse(_ageController.text.trim());
        if (age == null || 
            age < _PatientProfileConstants.minAge || 
            age > _PatientProfileConstants.maxAge) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please enter a valid age (${_PatientProfileConstants.minAge}-${_PatientProfileConstants.maxAge})',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final updatedUser = currentUser.copyWith(
        age: age,
        gender: _selectedGender,
        allergies: _allergies.isEmpty ? null : _allergies,
        pastConditions: _pastConditions.isEmpty ? null : _pastConditions,
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

        // Wait a moment for the snackbar to show
        await Future.delayed(
          const Duration(milliseconds: _PatientProfileConstants.navigationDelayMs),
        );

        if (!widget.isEditing) {
          // First time setup - navigate to home
          if (mounted) {
            context.go('/home');
          }
        } else {
          // Editing - go back
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
            duration: const Duration(
              seconds: _PatientProfileConstants.errorSnackbarDurationSeconds,
            ),
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
            'Please complete your profile to use EasyMed. This information helps doctors provide better care.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Sign out if they really want to leave
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
              // For first time setup, show confirmation dialog
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
                          'Complete your profile to get started with EasyMed',
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
                'Medical Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please provide your medical information to help doctors provide better care.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              // Age field
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Age',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Optional',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final age = int.tryParse(value);
                    if (age == null || 
                        age < _PatientProfileConstants.minAge || 
                        age > _PatientProfileConstants.maxAge) {
                      return 'Please enter a valid age (${_PatientProfileConstants.minAge}-${_PatientProfileConstants.maxAge})';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Gender selection
              const Text(
                'Gender',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Male'),
                      selected: _selectedGender == 'Male',
                      onSelected: (selected) {
                        setState(() => _selectedGender = selected ? 'Male' : null);
                      },
                      selectedColor: const Color(0xFF2196F3).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Female'),
                      selected: _selectedGender == 'Female',
                      onSelected: (selected) {
                        setState(() => _selectedGender = selected ? 'Female' : null);
                      },
                      selectedColor: const Color(0xFF2196F3).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Other'),
                      selected: _selectedGender == 'Other',
                      onSelected: (selected) {
                        setState(() => _selectedGender = selected ? 'Other' : null);
                      },
                      selectedColor: const Color(0xFF2196F3).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF2196F3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Allergies section
              const Text(
                'Allergies',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _allergyController,
                      decoration: InputDecoration(
                        labelText: 'Add an allergy',
                        prefixIcon: const Icon(Icons.warning),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        helperText: 'e.g., Penicillin, Peanuts',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onFieldSubmitted: (_) => _addAllergy(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: _addAllergy,
                    color: Theme.of(context).primaryColor,
                    iconSize: 40,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_allergies.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allergies.map((allergy) {
                    return Chip(
                      label: Text(allergy),
                      onDeleted: () => _removeAllergy(allergy),
                      deleteIcon: const Icon(Icons.close, size: 18),
                    );
                  }).toList(),
                ),
              ] else ...[
                const Text(
                  'No allergies added',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Past conditions section
              const Text(
                'Past Medical Conditions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _conditionController,
                      decoration: InputDecoration(
                        labelText: 'Add a condition',
                        prefixIcon: const Icon(Icons.medical_services),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        helperText: 'e.g., Diabetes, Hypertension',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onFieldSubmitted: (_) => _addCondition(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: _addCondition,
                    color: Theme.of(context).primaryColor,
                    iconSize: 40,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_pastConditions.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _pastConditions.map((condition) {
                    return Chip(
                      label: Text(condition),
                      onDeleted: () => _removeCondition(condition),
                      deleteIcon: const Icon(Icons.close, size: 18),
                    );
                  }).toList(),
                ),
              ] else ...[
                const Text(
                  'No conditions added',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
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

