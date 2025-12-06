import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import '../models/payment_model.dart';
import '../models/appointment_model.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  /// Initialize Stripe with publishable key
  static Future<void> initializeStripe() async {
    String publishableKey = '';
    
    // Priority 1: Try dotenv first (local dev with .env file) - most common case
    if (dotenv.isInitialized) {
      publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
      if (publishableKey.isNotEmpty) {
        debugPrint('✓ Stripe key loaded from .env file (length: ${publishableKey.length})');
      } else {
        debugPrint('⚠ .env file loaded but STRIPE_PUBLISHABLE_KEY is empty');
      }
    } else {
      debugPrint('⚠ dotenv not initialized - .env file may not be accessible');
    }
    
    // Priority 2: Try --dart-define (CI/CD builds) - only if dotenv didn't work
    if (publishableKey.isEmpty) {
      publishableKey = const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
      if (publishableKey.isNotEmpty) {
        debugPrint('✓ Stripe key loaded from --dart-define (CI/CD) (length: ${publishableKey.length})');
      }
    }
    
    // Priority 3: Fall back to system environment variable (local dev fallback)
    if (publishableKey.isEmpty) {
      publishableKey = Platform.environment['STRIPE_PUBLISHABLE_KEY'] ?? '';
      if (publishableKey.isNotEmpty) {
        debugPrint('✓ Stripe key loaded from system environment (length: ${publishableKey.length})');
      }
    }
    
    if (publishableKey.isEmpty) {
      debugPrint('✗ STRIPE_PUBLISHABLE_KEY not found in any source');
      debugPrint('  - dotenv.isInitialized: ${dotenv.isInitialized}');
      debugPrint('  - --dart-define: empty');
      debugPrint('  - Platform.environment: ${Platform.environment.containsKey('STRIPE_PUBLISHABLE_KEY')}');
      throw Exception('STRIPE_PUBLISHABLE_KEY not found. For local dev: ensure .env file exists in project root with STRIPE_PUBLISHABLE_KEY=pk_test_... For CI/CD: set as GitHub secret.');
    }
    
    debugPrint('Setting Stripe publishable key (length: ${publishableKey.length})');
    
    // Set publishable key - this is all that's needed for initialization
    Stripe.publishableKey = publishableKey;
    
    // For Android, merchant identifier is optional but can be set
    if (Platform.isIOS) {
      Stripe.merchantIdentifier = 'merchant.com.easymed';
    }
    
    debugPrint('✓ Stripe initialized successfully');
  }

  /// Create a payment intent for an appointment using Stripe
  Future<PaymentModel> createPayment({
    required String appointmentId,
    required String patientId,
    required String doctorId,
    required double amount,
  }) async {
    try {
      final paymentId = _firestore.collection('payments').doc().id;
      
      // Call Cloud Function to create Stripe Payment Intent
      debugPrint('Creating Stripe Payment Intent for amount: \$${amount.toStringAsFixed(2)}');
      final result = await _functions.httpsCallable('createPaymentIntent').call({
        'amount': amount,
        'appointmentId': appointmentId,
        'currency': 'usd',
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: Payment intent creation took too long');
        },
      );

      final data = result.data as Map<String, dynamic>;
      final clientSecret = data['clientSecret'] as String;
      final paymentIntentId = data['paymentIntentId'] as String;

      // Create payment document with Stripe info
      final payment = PaymentModel(
        id: paymentId,
        appointmentId: appointmentId,
        patientId: patientId,
        doctorId: doctorId,
        amount: amount,
        status: PaymentStatus.pending,
        stripePaymentIntentId: paymentIntentId,
        stripeClientSecret: clientSecret,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('payments')
          .doc(paymentId)
          .set(payment.toMap());

      debugPrint('Payment created with Stripe Payment Intent: $paymentIntentId');
      return payment;
    } catch (e) {
      debugPrint('Error creating payment: $e');
      throw Exception('Failed to create payment: $e');
    }
  }

  /// Get payment for an appointment
  Future<PaymentModel?> getPaymentByAppointment(String appointmentId) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final data = snapshot.docs.first.data();
      // Ensure the document has the required fields
      if (data.isEmpty) {
        return null;
      }
      
      return PaymentModel.fromMap(data);
    } catch (e) {
      debugPrint('Error getting payment: $e');
      // Return null instead of throwing - payment might not exist yet
      return null;
    }
  }

  /// Get all pending payments for a patient
  Stream<List<PaymentModel>> getPendingPaymentsStream(String patientId) {
    return _firestore
        .collection('payments')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: PaymentStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromMap(doc.data()))
            .toList());
  }

  /// Process payment with Stripe using Payment Sheet
  Future<void> processPaymentWithStripe({
    required String paymentId,
    required String clientSecret,
  }) async {
    try {
      debugPrint('Processing payment with Stripe...');
      
      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'EasyMed',
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();
      
      debugPrint('Payment confirmed by Stripe');
      
      // Confirm payment with Cloud Function
      await _functions.httpsCallable('confirmPayment').call({
        'paymentIntentId': await _getPaymentIntentId(paymentId),
        'paymentId': paymentId,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: Payment confirmation took too long');
        },
      );

      debugPrint('Payment confirmed successfully');
    } on StripeException catch (e) {
      debugPrint('Stripe payment error: ${e.error.code} - ${e.error.message}');
      
      // Update payment status to failed
      await _firestore.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.failed.name,
        'failureReason': e.error.message ?? e.error.code.toString(),
      });
      
      // Extract user-friendly error message
      String userMessage;
      if (e.error.code == FailureCode.Canceled) {
        userMessage = 'Payment was canceled';
      } else if (e.error.localizedMessage != null) {
        userMessage = e.error.localizedMessage!;
      } else if (e.error.message != null) {
        userMessage = e.error.message!;
      } else {
        userMessage = 'Payment failed. Please try again.';
      }
      
      throw Exception(userMessage);
    } catch (e) {
      debugPrint('Payment error: $e');
      
      // Update payment status to failed
      await _firestore.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.failed.name,
        'failureReason': e.toString(),
      });
      
      throw Exception('Payment failed. Please try again.');
    }
  }

  /// Get payment intent ID from payment document
  Future<String> _getPaymentIntentId(String paymentId) async {
    final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
    final paymentData = paymentDoc.data();
    final paymentIntentId = paymentData?['stripePaymentIntentId'] as String?;
    
    if (paymentIntentId == null) {
      throw Exception('Payment Intent ID not found');
    }
    
    return paymentIntentId;
  }

  /// Update payment status
  Future<void> updatePaymentStatus(String paymentId, PaymentStatus status) async {
    try {
      await _firestore.collection('payments').doc(paymentId).update({
        'status': status.name,
        if (status == PaymentStatus.completed) 'completedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update payment status: $e');
    }
  }

  /// Mark payment as completed (simulating successful Stripe payment)
  Future<void> markPaymentAsCompleted(String paymentId) async {
    try {
      await _firestore.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.completed.name,
        'completedAt': Timestamp.now(),
      });

      // Update appointment payment status
      final payment = await _firestore.collection('payments').doc(paymentId).get();
      final appointmentId = payment.data()?['appointmentId'] as String;
      
      if (appointmentId != null) {
        await _firestore.collection('appointments').doc(appointmentId).update({
          'isPaid': true,
          'paymentId': paymentId,
        });
      }
    } catch (e) {
      throw Exception('Failed to mark payment as completed: $e');
    }
  }
}

