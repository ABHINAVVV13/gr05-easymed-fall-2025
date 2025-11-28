import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video/stream_video.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart' as app_models;
import '../models/appointment_model.dart';

class StreamVideoService {
  static StreamVideo? _client;
  static bool _isInitialized = false;

  /// Initialize Stream Video client with user
  static Future<void> initialize(app_models.UserModel user) async {
    if (_isInitialized && _client != null) {
      return; // Already initialized
    }

    try {
      final apiKey = dotenv.env['STREAM_API_KEY'];
      if (apiKey == null) {
        throw Exception('STREAM_API_KEY not found in .env file');
      }

      // Generate user token (in production, this should come from your backend)
      // For now, we'll create a basic user token
      final streamUser = User.regular(
        userId: user.uid,
        role: user.userType == app_models.UserType.doctor ? 'admin' : 'user',
        name: user.displayName ?? (user.userType == app_models.UserType.patient ? 'Patient' : 'Doctor'),
      );

      // In production, get token from your backend API
      // For now, we'll need to generate it server-side or use a placeholder
      // You'll need to implement token generation on your backend
      final userToken = await _generateUserToken(user.uid);

      _client = StreamVideo(
        apiKey,
        user: streamUser,
        userToken: userToken,
      );

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize Stream Video: $e');
    }
  }

  /// Generate user token using Firebase Cloud Function
  static Future<String> _generateUserToken(String userId) async {
    try {
      final functions = FirebaseFunctions.instance;
      
      debugPrint('Calling generateStreamToken Cloud Function for user: $userId');
      
      // Call the Cloud Function to generate Stream token with timeout
      final result = await functions.httpsCallable('generateStreamToken').call({
        'userId': userId,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: Token generation took too long. Make sure the Cloud Function is deployed.');
        },
      );

      final data = result.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      
      if (token == null) {
        throw Exception('No token returned from Cloud Function. Response: ${data.toString()}');
      }
      
      debugPrint('Token generated successfully');
      return token;
    } catch (e) {
      debugPrint('Error generating Stream token: $e');
      throw Exception('Failed to generate Stream token: $e');
    }
  }

  /// Get Stream Video client instance
  static StreamVideo get instance {
    if (_client == null) {
      throw Exception('Stream Video not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Create or get a call for an appointment
  static Call makeCallForAppointment(AppointmentModel appointment) {
    if (_client == null) {
      throw Exception('Stream Video not initialized. Call initialize() first.');
    }

    // Generate unique call ID from appointment ID
    final callId = 'appointment-${appointment.id}';

    // Create call - use default call type
    final call = _client!.makeCall(
      callType: StreamCallType.defaultType(),
      id: callId,
    );

    return call;
  }

  /// Disconnect Stream Video client
  static Future<void> disconnect() async {
    if (_client != null) {
      await _client!.disconnect();
      _client = null;
      _isInitialized = false;
    }
  }
}

