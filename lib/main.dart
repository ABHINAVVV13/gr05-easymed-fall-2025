import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rxdart/rxdart.dart';

final messageStreamController = BehaviorSubject<RemoteMessage>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  print('Message data: ${message.data}');
  print('Message notification: ${message.notification?.title}');
  print('Message notification: ${message.notification?.body}');
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables (optional - file may not exist in CI/CD)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env file not found - this is OK in CI/CD where secrets are injected via environment variables
    // In production, environment variables should be set directly, not via .env file
    debugPrint('Warning: .env file not found. Using environment variables directly.');
  }
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // notifications: request permission function
  final messaging = FirebaseMessaging.instance;

  final settings = await messaging.requestPermission(
  alert: true,
  announcement: false,
  badge: true,
  carPlay: false,
  criticalAlert: false,
  provisional: false,
  sound: true,
  );
  // force it for testing
  print('Permission granted: ${settings.authorizationStatus}');
  

  String? token = await messaging.getToken();
  // force it for testing
  print('Registration Token=$token');

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  if (true) {
    print('Handling a foreground message: ${message.messageId}');
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification?.title}');
    print('Message notification: ${message.notification?.body}');
  }

  messageStreamController.sink.add(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('App opened from notification: ${message.messageId}');
    messageStreamController.sink.add(message);
  });

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print('App launched from notification: ${initialMessage.messageId}');
    messageStreamController.sink.add(initialMessage);
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const topic = 'app_promotion';
  await messaging.subscribeToTopic(topic);
  
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
