import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Current Firebase user stream
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current user data from Firestore
final userDataProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }
      
      final authService = ref.read(authServiceProvider);
      return Stream.fromFuture(authService.getUserData(user.uid));
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// Authentication state provider (combines Firebase auth and user data)
final authStateNotifierProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthStateNotifier(ref);
});

class AuthStateNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final Ref _ref;
  final AuthService _authService;
  bool _isManualError = false; // Track if we set an error manually

  AuthStateNotifier(this._ref)
      : _authService = _ref.read(authServiceProvider),
super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // Listen to auth state changes
    _ref.listen(authStateProvider, (previous, next) {
      // Don't override manually set errors (like email-already-in-use)
      if (_isManualError && state.hasError) {
        return; // Keep the manual error state
      }
      
      next.when(
        data: (user) async {
          if (user == null) {
            _isManualError = false; // Clear flag when user logs out
            state = const AsyncValue.data(null);
          } else {
            try {
              _isManualError = false; // Clear flag on successful auth
              final userData = await _authService.getUserData(user.uid);
              state = AsyncValue.data(userData);
              
              // Save FCM token for the logged-in user
              try {
                final notificationService = NotificationService();
                // Wait a bit for token to be ready, then try to get it
                await Future.delayed(const Duration(milliseconds: 500));
                var token = notificationService.fcmToken;
                if (token == null) {
                  // Try to get token directly
                  token = await notificationService.messaging.getToken();
                }
                if (token != null) {
                  await notificationService.saveFcmTokenForUser(user.uid, token);
                  debugPrint('✓ FCM token saved for user ${user.uid}');
                } else {
                  debugPrint('⚠ FCM token is null for user ${user.uid}');
                }
              } catch (e) {
                // Don't fail auth if token save fails
                debugPrint('Error saving FCM token: $e');
              }
            } catch (e, stackTrace) {
              state = AsyncValue.error(e, stackTrace);
            }
          }
        },
        loading: () {
          // Only set loading if we don't have a manual error
          if (!_isManualError || !state.hasError) {
            state = const AsyncValue.loading();
          }
        },
        error: (error, stackTrace) {
          // Only set error from stream if we don't have a manual error
          if (!_isManualError || !state.hasError) {
            state = AsyncValue.error(error, stackTrace);
          }
        },
      );
    });
  }

  // Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    required UserType userType,
    String? displayName,
  }) async {
    try {
      _isManualError = false; // Clear flag before starting
      state = const AsyncValue.loading();
      // Email check is done in UI - this just creates the account
      final userCredential = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        userType: userType,
        displayName: displayName,
      );
      
      // After signup, manually fetch and set user data to ensure state is updated
      if (userCredential?.user != null) {
        try {
          // Wait a moment for Firestore to be ready
          await Future.delayed(const Duration(milliseconds: 300));
          final userData = await _authService.getUserData(userCredential!.user!.uid);
          if (userData != null) {
            state = AsyncValue.data(userData);
          } else {
            // If user data not found, wait a bit more and try again
            await Future.delayed(const Duration(milliseconds: 500));
            final retryUserData = await _authService.getUserData(userCredential.user!.uid);
            state = AsyncValue.data(retryUserData);
          }
        } catch (e) {
          // If getting user data fails, still set the auth user
          // The stream listener will handle it
          state = const AsyncValue.loading();
        }
      }
      // State will also be updated automatically via stream listener as backup
    } catch (e, stackTrace) {
      // Don't set error state for email-already-in-use - UI handles it
      // This prevents router from seeing error state and causing redirect issues
      if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
        // Don't set error state - let UI handle it
        state = const AsyncValue.data(null); // Reset to null state
        rethrow; // Still rethrow so UI can catch it
      } else {
        // Set error state for other errors
        state = AsyncValue.error(e, stackTrace);
        rethrow;
      }
    }
  }

  // Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      state = const AsyncValue.loading();
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // State will be updated automatically via stream listener
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      state = const AsyncValue.loading();
      await _authService.signInWithGoogle();
      // State will be updated automatically via stream listener
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      rethrow;
    }
  }

  // Update user data
  Future<void> updateUserData(UserModel userModel) async {
    try {
      await _authService.updateUserData(userModel);
      // Refresh user data
      final user = _authService.currentUser;
      if (user != null) {
        final updatedUserData = await _authService.getUserData(user.uid);
        state = AsyncValue.data(updatedUserData);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }
}

