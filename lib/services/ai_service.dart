import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/symptom_questionnaire_model.dart';
import '../models/user_model.dart';

class AIService {
  // For now, using a simple rule-based system
  // In production, integrate with OpenAI/Claude API
  
  Future<Map<String, dynamic>> analyzeSymptoms({
    required List<String> symptoms,
    String? severity,
    String? duration,
    UserModel? patientInfo,
  }) async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(seconds: 2));

      // Rule-based recommendation system
      // In production, replace with actual AI API call
      final recommendation = _generateRecommendation(
        symptoms: symptoms,
        severity: severity,
        duration: duration,
        patientInfo: patientInfo,
      );

      return {
        'recommendation': recommendation['text'],
        'specializations': recommendation['specializations'],
        'urgency': recommendation['urgency'],
      };
    } catch (e) {
      rethrow;
    }
  }

  // Rule-based symptom analysis (replace with AI in production)
  Map<String, dynamic> _generateRecommendation({
    required List<String> symptoms,
    String? severity,
    String? duration,
    UserModel? patientInfo,
  }) {
    final symptomsLower = symptoms.map((s) => s.toLowerCase()).toList();
    final List<String> specializations = [];
    String urgency = 'normal';
    String text = '';

    // Analyze symptoms and recommend specializations
    if (symptomsLower.any((s) => s.contains('chest') || s.contains('heart') || s.contains('breath'))) {
      specializations.add('Cardiology');
      if (symptomsLower.any((s) => s.contains('pain') || s.contains('pressure'))) {
        urgency = 'high';
        text = 'Chest-related symptoms detected. Consider consulting a cardiologist, especially if you experience chest pain or pressure.';
      }
    }

    if (symptomsLower.any((s) => s.contains('skin') || s.contains('rash') || s.contains('itch'))) {
      specializations.add('Dermatology');
      text += ' Skin-related symptoms suggest a dermatology consultation.';
    }

    if (symptomsLower.any((s) => s.contains('child') || s.contains('baby') || s.contains('pediatric'))) {
      specializations.add('Pediatrics');
      text += ' Pediatric care recommended for child-related concerns.';
    }

    if (symptomsLower.any((s) => s.contains('bone') || s.contains('joint') || s.contains('fracture') || s.contains('sprain'))) {
      specializations.add('Orthopedics');
      text += ' Bone or joint issues may require orthopedic consultation.';
    }

    if (symptomsLower.any((s) => s.contains('headache') || s.contains('migraine') || s.contains('seizure') || s.contains('neurological'))) {
      specializations.add('Neurology');
      if (symptomsLower.any((s) => s.contains('severe') || s.contains('sudden'))) {
        urgency = 'high';
      }
      text += ' Neurological symptoms detected. Consider consulting a neurologist.';
    }

    // Default to General Medicine if no specific match
    if (specializations.isEmpty) {
      specializations.add('General Medicine');
      text = 'Based on your symptoms, we recommend consulting with a general medicine doctor who can provide comprehensive care and refer you to specialists if needed.';
    }

    // Adjust urgency based on severity and duration
    if (severity == 'severe' || duration == 'more than a week') {
      urgency = 'high';
    } else if (severity == 'moderate') {
      urgency = 'medium';
    }

    return {
      'text': text.isEmpty 
          ? 'Based on your symptoms, we recommend consulting with a ${specializations.first} specialist.'
          : text,
      'specializations': specializations,
      'urgency': urgency,
    };
  }

  // Generate AI medical conversation summary from questionnaire
  Future<String> generateMedicalConversation({
    required List<String> symptoms,
    String? severity,
    String? duration,
    UserModel? patientInfo,
  }) async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(seconds: 1));

      // Generate conversation summary
      final symptomList = symptoms.join(', ');
      final ageInfo = patientInfo?.age != null ? 'Age: ${patientInfo!.age} years. ' : '';
      final genderInfo = patientInfo?.gender != null ? 'Gender: ${patientInfo!.gender}. ' : '';
      final severityInfo = severity != null ? 'Severity: $severity. ' : '';
      final durationInfo = duration != null ? 'Duration: $duration. ' : '';
      
      final conversation = '''
Patient Consultation Summary

Chief Complaint: $symptomList

Patient Information: $ageInfo$genderInfo

Symptom Details:
- Severity: ${severity ?? 'Not specified'}
- Duration: ${duration ?? 'Not specified'}

Clinical Presentation:
The patient presents with ${symptoms.length} ${symptoms.length == 1 ? 'symptom' : 'symptoms'}: $symptomList. 
${severityInfo.isNotEmpty ? 'The symptoms are reported as $severity. ' : ''}
${durationInfo.isNotEmpty ? 'Symptoms have been present for $duration. ' : ''}

Assessment:
Based on the reported symptoms, this consultation requires attention from a healthcare provider. 
The patient should be evaluated to determine the underlying cause and appropriate treatment plan.

Recommendations:
- Conduct a thorough physical examination
- Review patient's medical history and any relevant medical reports
- Consider diagnostic tests if indicated
- Provide appropriate treatment based on findings
''';

      return conversation.trim();
    } catch (e) {
      rethrow;
    }
  }

  // Future: Integrate with OpenAI/Claude API
  /*
  Future<Map<String, dynamic>> _callAIService({
    required List<String> symptoms,
    String? severity,
    String? duration,
    UserModel? patientInfo,
  }) async {
    final apiKey = 'YOUR_API_KEY';
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    
    final prompt = '''
    As a medical assistant, analyze these symptoms and recommend appropriate medical care:
    Symptoms: ${symptoms.join(', ')}
    Severity: ${severity ?? 'not specified'}
    Duration: ${duration ?? 'not specified'}
    Patient Age: ${patientInfo?.age ?? 'not specified'}
    Patient Gender: ${patientInfo?.gender ?? 'not specified'}
    
    Provide:
    1. Recommended doctor specialization(s)
    2. Urgency level (low/medium/high)
    3. Brief explanation
    ''';
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {'role': 'system', 'content': 'You are a medical assistant that provides general health guidance.'},
          {'role': 'user', 'content': prompt},
        ],
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Parse AI response and return recommendations
      return _parseAIResponse(data);
    } else {
      throw Exception('AI service error: ${response.statusCode}');
    }
  }
  */
}

