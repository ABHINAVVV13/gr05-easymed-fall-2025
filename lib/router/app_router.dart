import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
// TODO: Uncomment screens as they are implemented in later branches
// import '../screens/home/home_screen.dart';
import '../screens/patient/patient_profile_setup_screen.dart';
import '../screens/patient/doctor_search_screen.dart';
import '../screens/patient/doctor_details_screen.dart';
import '../screens/patient/symptom_questionnaire_screen.dart';
// import '../screens/patient/appointment_booking_screen.dart';
// import '../screens/patient/patient_appointments_screen.dart';
import '../screens/doctor/doctor_profile_setup_screen.dart';
// import '../screens/doctor/doctor_appointments_screen.dart';
// import '../screens/shared/appointment_details_screen.dart';
import '../screens/patient/medical_reports_screen.dart';
import '../screens/shared/report_details_screen.dart';
import '../screens/doctor/create_prescription_screen.dart';
import '../screens/patient/patient_prescriptions_screen.dart';
import '../screens/shared/prescription_details_screen.dart';
// import '../screens/doctor/doctor_patients_screen.dart';
// import '../screens/patient/patient_waiting_room_screen.dart';
// import '../screens/doctor/doctor_waiting_room_screen.dart';
// import '../screens/shared/video_call_screen.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      try {
        // Don't redirect while loading
        if (authState.isLoading) {
          return null;
        }

        final currentPath = state.uri.path;
        final isLoggedIn = authState.value != null;
        final isOnAuthScreen = currentPath == '/login' || 
                              currentPath == '/signup';

        // NEVER redirect if there's an error on auth screens
        if (authState.hasError && isOnAuthScreen) {
          return null; // Stay on current screen to show error
        }

        // Define routes that don't require authentication
        final publicRoutes = [
          '/login',
          '/signup',
          '/patient-profile',
          '/doctor-profile',
        ];
        
        // Define routes that don't require profile completion
        final routesWithoutProfileCheck = [
          '/doctor-search',
          '/doctor-details',
          '/symptom-questionnaire',
          '/book-appointment',
          '/doctor-patients',
          '/patient-waiting-room',
          '/doctor-waiting-room',
          '/video-call',
        ];
        
        // Check if current path matches routes without profile check
        final isOnRouteWithoutProfileCheck = routesWithoutProfileCheck.any(
          (route) => currentPath.startsWith(route),
        );

        // Redirect unauthenticated users away from protected routes
        // But allow booking routes (they'll check auth in the screen itself)
        final isOnBookingRoute = currentPath.startsWith('/book-appointment');
        if (!isLoggedIn && !isOnAuthScreen && !publicRoutes.contains(currentPath) && !isOnBookingRoute) {
          return '/login';
        }

        // Only redirect authenticated users away from auth screens
        if (isLoggedIn && isOnAuthScreen) {
          final user = authState.value;
          // Check if user needs to complete profile
          if (user != null) {
            if (user.userType == UserType.patient &&
                !_isPatientProfileComplete(user) &&
                currentPath != '/patient-profile') {
              return '/patient-profile';
            }
            if (user.userType == UserType.doctor &&
                !_isDoctorProfileComplete(user) &&
                currentPath != '/doctor-profile') {
              return '/doctor-profile';
            }
          }
          return '/home';
        }

        // Check if user needs to complete profile on other routes
        // But skip this check for routes that don't require profile completion
        if (isLoggedIn && !isOnAuthScreen && !isOnRouteWithoutProfileCheck) {
          final user = authState.value;
          if (user != null) {
            if (user.userType == UserType.patient &&
                !_isPatientProfileComplete(user) &&
                currentPath != '/patient-profile') {
              return '/patient-profile';
            }
            if (user.userType == UserType.doctor &&
                !_isDoctorProfileComplete(user) &&
                currentPath != '/doctor-profile') {
              return '/doctor-profile';
            }
          }
        }

        return null;
      } catch (e) {
        // Catch any errors during redirect to prevent GoRouter exceptions
        // Just stay on current screen
        return null;
      }
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      // TODO: Home screen will be implemented in later branch
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) {
          // Temporary placeholder until HomeScreen is implemented
          return Scaffold(
            appBar: AppBar(title: const Text('EasyMed')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services, size: 64, color: Color(0xFF2196F3)),
                  SizedBox(height: 16),
                  Text('Home Screen', style: TextStyle(fontSize: 24)),
                  SizedBox(height: 8),
                  Text('Will be implemented in later branch', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
      // TODO: Uncomment routes as screens are implemented
      // Patient routes
      GoRoute(
        path: '/patient-profile',
        name: 'patient-profile',
        builder: (context, state) {
          final isEditing = state.uri.queryParameters['edit'] == 'true';
          final user = authState.value;
          return PatientProfileSetupScreen(
            isEditing: isEditing,
            initialUser: user,
          );
        },
      ),
      GoRoute(
        path: '/doctor-search',
        name: 'doctor-search',
        builder: (context, state) => const DoctorSearchScreen(),
      ),
      GoRoute(
        path: '/doctor-details/:doctorId',
        name: 'doctor-details',
        builder: (context, state) {
          final doctorId = state.pathParameters['doctorId']!;
          return DoctorDetailsScreen(doctorId: doctorId);
        },
      ),
      GoRoute(
        path: '/symptom-questionnaire',
        name: 'symptom-questionnaire',
        builder: (context, state) => const SymptomQuestionnaireScreen(),
      ),
      // GoRoute(
      //   path: '/book-appointment/:doctorId',
      //   name: 'book-appointment',
      //   builder: (context, state) {
      //     final doctorId = state.pathParameters['doctorId']!;
      //     final isInstant = state.uri.queryParameters['instant'] == 'true';
      //     if (doctorId.isEmpty) {
      //       return const HomeScreen();
      //     }
      //     return AppointmentBookingScreen(doctorId: doctorId, isInstant: isInstant);
      //   },
      // ),
      // GoRoute(
      //   path: '/patient-appointments',
      //   name: 'patient-appointments',
      //   builder: (context, state) => const PatientAppointmentsScreen(),
      // ),
      GoRoute(
        path: '/medical-reports',
        name: 'medical-reports',
        builder: (context, state) => const MedicalReportsScreen(),
      ),
      GoRoute(
        path: '/patient-prescriptions',
        name: 'patient-prescriptions',
        builder: (context, state) => const PatientPrescriptionsScreen(),
      ),
      // GoRoute(
      //   path: '/patient-waiting-room/:appointmentId',
      //   name: 'patient-waiting-room',
      //   builder: (context, state) {
      //     final appointmentId = state.pathParameters['appointmentId']!;
      //     return PatientWaitingRoomScreen(appointmentId: appointmentId);
      //   },
      // ),
      // Doctor routes
      GoRoute(
        path: '/doctor-profile',
        name: 'doctor-profile',
        builder: (context, state) {
          final isEditing = state.uri.queryParameters['edit'] == 'true';
          final user = authState.value;
          return DoctorProfileSetupScreen(
            isEditing: isEditing,
            initialUser: user,
          );
        },
      ),
      // GoRoute(
      //   path: '/doctor-appointments',
      //   name: 'doctor-appointments',
      //   builder: (context, state) => const DoctorAppointmentsScreen(),
      // ),
      // GoRoute(
      //   path: '/doctor-patients',
      //   name: 'doctor-patients',
      //   builder: (context, state) => const DoctorPatientsScreen(),
      // ),
      // GoRoute(
      //   path: '/doctor-waiting-room',
      //   name: 'doctor-waiting-room',
      //   builder: (context, state) => const DoctorWaitingRoomScreen(),
      // ),
      GoRoute(
        path: '/create-prescription',
        name: 'create-prescription',
        builder: (context, state) {
          final appointmentId = state.uri.queryParameters['appointmentId'];
          final patientId = state.uri.queryParameters['patientId'];
          return CreatePrescriptionScreen(
            appointmentId: appointmentId,
            patientId: patientId,
          );
        },
      ),
      // Shared routes
      // GoRoute(
      //   path: '/appointment-details/:appointmentId',
      //   name: 'appointment-details',
      //   builder: (context, state) {
      //     final appointmentId = state.pathParameters['appointmentId']!;
      //     return AppointmentDetailsScreen(appointmentId: appointmentId);
      //   },
      // ),
      GoRoute(
        path: '/report-details/:reportId',
        name: 'report-details',
        builder: (context, state) {
          final reportId = state.pathParameters['reportId']!;
          return ReportDetailsScreen(reportId: reportId);
        },
      ),
      GoRoute(
        path: '/prescription-details/:prescriptionId',
        name: 'prescription-details',
        builder: (context, state) {
          final prescriptionId = state.pathParameters['prescriptionId']!;
          return PrescriptionDetailsScreen(prescriptionId: prescriptionId);
        },
      ),
      // GoRoute(
      //   path: '/video-call/:appointmentId',
      //   name: 'video-call',
      //   builder: (context, state) {
      //     final appointmentId = state.pathParameters['appointmentId']!;
      //     return VideoCallScreen(appointmentId: appointmentId);
      //   },
      // ),
    ],
    errorBuilder: (context, state) {
      // Fallback error page
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Route not found: ${state.uri}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    },
  );
});

// Helper function to check if patient profile is complete
bool _isPatientProfileComplete(UserModel user) {
  // Profile is considered complete if at least age or gender is set
  // Allergies and past conditions are optional
  return user.age != null || user.gender != null;
}

// Helper function to check if doctor profile is complete
bool _isDoctorProfileComplete(UserModel user) {
  // Profile is considered complete if specialization and license number are set
  return user.specialization != null &&
      user.specialization!.isNotEmpty &&
      user.licenseNumber != null &&
      user.licenseNumber!.isNotEmpty;
}

