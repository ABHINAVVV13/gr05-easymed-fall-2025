import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../providers/auth_provider.dart';

final aiServiceProvider = Provider<AIService>((ref) => AIService());

class SymptomQuestionnaireWidget extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>) onComplete;
  final bool showSkip;

  const SymptomQuestionnaireWidget({
    super.key,
    required this.onComplete,
    this.showSkip = false,
  });

  @override
  ConsumerState<SymptomQuestionnaireWidget> createState() =>
      _SymptomQuestionnaireWidgetState();
}

class _SymptomQuestionnaireWidgetState
    extends ConsumerState<SymptomQuestionnaireWidget> {
  final _symptomController = TextEditingController();
  final List<String> _symptoms = [];
  String? _selectedSeverity;
  String? _selectedDuration;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _aiResult;
  String? _aiConversation;

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  void _addSymptom() {
    final symptom = _symptomController.text.trim();
    if (symptom.isNotEmpty && !_symptoms.contains(symptom)) {
      setState(() {
        _symptoms.add(symptom);
        _symptomController.clear();
      });
    }
  }

  void _removeSymptom(String symptom) {
    setState(() {
      _symptoms.remove(symptom);
    });
  }

  Future<void> _analyzeSymptoms() async {
    if (_symptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one symptom'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _aiResult = null;
      _aiConversation = null;
    });

    try {
      final currentUser = ref.read(authStateNotifierProvider).value;
      final aiService = ref.read(aiServiceProvider);

      // Analyze symptoms
      final result = await aiService.analyzeSymptoms(
        symptoms: _symptoms,
        severity: _selectedSeverity,
        duration: _selectedDuration,
        patientInfo: currentUser,
      );

      // Generate medical conversation
      final conversation = await aiService.generateMedicalConversation(
        symptoms: _symptoms,
        severity: _selectedSeverity,
        duration: _selectedDuration,
        patientInfo: currentUser,
      );

      if (mounted) {
        setState(() {
          _aiResult = result;
          _aiConversation = conversation;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing symptoms: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _proceed() {
    if (_symptoms.isEmpty || _aiResult == null || _aiConversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the symptom questionnaire first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onComplete({
      'symptoms': _symptoms,
      'severity': _selectedSeverity,
      'duration': _selectedDuration,
      'aiRecommendation': _aiResult!['recommendation'] as String?,
      'recommendedSpecializations': _aiResult!['specializations'] as List<String>?,
      'aiGeneratedConversation': _aiConversation,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.medical_information,
                    size: 48,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Symptom Questionnaire',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Help us understand your symptoms to prepare for your consultation',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Symptoms Input
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Symptoms',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _symptomController,
                          decoration: InputDecoration(
                            hintText: 'Enter a symptom (e.g., chest pain)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          onSubmitted: (_) => _addSymptom(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addSymptom,
                        icon: const Icon(Icons.add_circle),
                        color: const Color(0xFF2196F3),
                        iconSize: 32,
                      ),
                    ],
                  ),
                  if (_symptoms.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _symptoms.map((symptom) {
                        return Chip(
                          label: Text(symptom),
                          onDeleted: () => _removeSymptom(symptom),
                          deleteIcon: const Icon(Icons.close, size: 18),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Severity Selection
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Severity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSeverity,
                    decoration: InputDecoration(
                      hintText: 'Select severity (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'mild', child: Text('Mild')),
                      DropdownMenuItem(
                          value: 'moderate', child: Text('Moderate')),
                      DropdownMenuItem(value: 'severe', child: Text('Severe')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedSeverity = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Duration Selection
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Duration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDuration,
                    decoration: InputDecoration(
                      hintText: 'How long? (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'less than a day',
                          child: Text('Less than a day')),
                      DropdownMenuItem(
                          value: '1-3 days', child: Text('1-3 days')),
                      DropdownMenuItem(
                          value: '4-7 days', child: Text('4-7 days')),
                      DropdownMenuItem(
                          value: 'more than a week',
                          child: Text('More than a week')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedDuration = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Analyze Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeSymptoms,
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.psychology),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Symptoms'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          // AI Results
          if (_aiResult != null && _aiConversation != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Analysis Complete',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _aiResult!['recommendation'] as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _proceed,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue to Booking'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
          if (widget.showSkip) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => widget.onComplete({}),
              child: const Text('Skip Questionnaire'),
            ),
          ],
        ],
      ),
    );
  }
}

