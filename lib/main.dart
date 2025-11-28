import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
// TODO: Uncomment when router is implemented in Branch 4
// import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
    // TODO: Uncomment when router is implemented in Branch 4
    // final router = ref.watch(routerProvider);
    
    // return MaterialApp.router(
    //   title: 'EasyMed',
    //   theme: ThemeData(
    //     colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
    //     useMaterial3: true,
    //   ),
    //   routerConfig: router,
    //   debugShowCheckedModeBanner: false,
    // );

    // Temporary placeholder until router is implemented
    return MaterialApp(
      title: 'EasyMed',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.medical_services, size: 64, color: Color(0xFF2196F3)),
              SizedBox(height: 16),
              Text(
                'EasyMed',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Foundation setup complete',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
