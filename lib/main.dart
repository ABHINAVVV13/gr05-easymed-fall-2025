import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'dart:io';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/payment_service.dart';
import 'services/notification_service.dart' show NotificationService, firebaseMessagingBackgroundHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables - only for local development
  // In CI/CD, environment variables are set directly by GitHub Actions
  // Note: On Android, .env file must be in project root, but working directory may differ
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✓ .env file loaded (local development)');
  } catch (e) {
    // .env file not found - this is OK, will use --dart-define or system env
    // This happens in CI/CD or if .env is not accessible from app's working directory
    debugPrint('ℹ .env file not accessible: ${e.toString()}');
    debugPrint('ℹ Will use --dart-define (CI/CD) or system environment variables');
  }
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Stripe
  try {
    await PaymentService.initializeStripe();
    debugPrint('✓ Stripe initialized');
  } catch (e) {
    debugPrint('⚠ Stripe initialization failed: $e');
  }
  
  // Initialize Firebase Messaging
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    final notificationService = NotificationService();
    await notificationService.initialize();
    debugPrint('✓ Notifications initialized');
    
    // Get and log FCM token for debugging
    final token = await notificationService.messaging.getToken();
    if (token != null) {
      debugPrint('✓ FCM Token obtained: ${token.substring(0, 20)}...');
    } else {
      debugPrint('⚠ FCM Token is null - notifications may not work');
    }
  } catch (e) {
    debugPrint('⚠ Notification initialization failed: $e');
    debugPrint('⚠ Stack trace: ${StackTrace.current}');
  }
  
  runApp(
    const ProviderScope(
      child: MainApp(),
    ),
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'EasyMed',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        useMaterial3: true,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
