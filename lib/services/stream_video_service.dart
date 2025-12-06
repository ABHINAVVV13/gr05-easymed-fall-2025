import 'dart:io';
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
      debugPrint('Step 1: Getting API key...');
      String apiKey = '';
      
      // Priority 1: Try --dart-define (CI/CD builds)
      apiKey = const String.fromEnvironment('STREAM_API_KEY');
      if (apiKey.isNotEmpty) {
        debugPrint('Step 1: API key from --dart-define (CI/CD), length: ${apiKey.length}');
      }
      
      // Priority 2: Try dotenv (local dev with .env file)
      if (apiKey.isEmpty && dotenv.isInitialized) {
        apiKey = dotenv.env['STREAM_API_KEY'] ?? '';
        if (apiKey.isNotEmpty) {
          debugPrint('Step 1: API key from dotenv (.env file), length: ${apiKey.length}');
        }
      }
      
      // Priority 3: Fall back to system environment variable (local dev fallback)
      if (apiKey.isEmpty) {
        apiKey = Platform.environment['STREAM_API_KEY'] ?? '';
        if (apiKey.isNotEmpty) {
          debugPrint('Step 1: API key from environment variable (local fallback), length: ${apiKey.length}');
        }
      }
      
      if (apiKey.isEmpty) {
        throw Exception('STREAM_API_KEY not found. For local dev: check .env file. For CI/CD: set as GitHub secret and use --dart-define.');
      }
      debugPrint('Step 1: ✓ API key found (length: ${apiKey.length})');

      debugPrint('Step 2: Creating Stream user object...');
      // Generate user token (in production, this should come from your backend)
      final streamUser = User.regular(
        userId: user.uid,
        role: user.userType == app_models.UserType.doctor ? 'admin' : 'user',
        name: user.displayName ?? (user.userType == app_models.UserType.patient ? 'Patient' : 'Doctor'),
      );
      debugPrint('Step 2: Stream user created: ${streamUser.id}');

      debugPrint('Step 3: Generating user token...');
      // Generate user token from Firebase Cloud Function
      final userToken = await _generateUserToken(user.uid);
      debugPrint('Step 3: User token generated');

      debugPrint('Step 4: Creating StreamVideo instance...');
      _client = StreamVideo(
        apiKey,
        user: streamUser,
        userToken: userToken,
      );
      debugPrint('Step 4: StreamVideo instance created successfully');

      debugPrint('Step 5: Marking as initialized...');
      _isInitialized = true;
      debugPrint('Step 5: StreamVideoService initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('ERROR in StreamVideoService.initialize at step above');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      debugPrint('Stack trace: $stackTrace');
      _client = null;
      _isInitialized = false;
      // Re-throw the original error without wrapping
      rethrow;
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
  static Future<Call> makeCallForAppointment(AppointmentModel appointment) async {
    if (_client == null) {
      throw Exception('Stream Video not initialized. Call initialize() first.');
    }

    // Ensure client is connected before making call
    try {
      // Try to connect if not already connected
      await _client!.connect();
      // Small delay to ensure connection is established
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('Note: Client may already be connected: $e');
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
