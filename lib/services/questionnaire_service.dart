import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/symptom_questionnaire_model.dart';

class QuestionnaireService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save questionnaire response
  Future<SymptomQuestionnaireModel> saveQuestionnaire(
    SymptomQuestionnaireModel questionnaire,
  ) async {
    try {
      await _firestore
          .collection('questionnaires')
          .doc(questionnaire.id)
          .set(questionnaire.toMap());
      return questionnaire;
    } catch (e) {
      rethrow;
    }
  }

  // Get patient's questionnaire history
  Stream<List<SymptomQuestionnaireModel>> getPatientQuestionnairesStream(
    String patientId,
  ) {
    return _firestore
        .collection('questionnaires')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SymptomQuestionnaireModel.fromMap(doc.data()))
            .toList());
  }

  // Get questionnaire by ID
  Future<SymptomQuestionnaireModel?> getQuestionnaireById(String id) async {
    try {
      final doc = await _firestore.collection('questionnaires').doc(id).get();
      if (doc.exists) {
        return SymptomQuestionnaireModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}

