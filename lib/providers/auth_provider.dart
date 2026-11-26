import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../core/config/app_config.dart';

// Service provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(appConfigProvider)));

// Authentication state stream provider (listens directly to Firebase Auth changes)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// User profile data provider (fetches user profile from Firestore when authenticated)
final userDetailsProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider).value;
  if (authState != null) {
    return ref.watch(authServiceProvider).getUserDetails(authState.uid);
  }
  return null;
});

// App Authentication State class to manage the UI states easily
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.data(null));

  // Sync state from external auth stream, but ignore the initial loading event.
  void updateFromAuthState(AsyncValue<User?> next) {
    if (next.isLoading) return;
    state = next;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authService.signInWithEmailAndPassword(email, password);
      state = AsyncValue.data(credential.user);
    } catch (e, stackTrace) {
      final formatted = _formatError(e);
      debugPrint('Auth login error (${e.runtimeType}): $formatted');
      state = AsyncValue.error(formatted, stackTrace);
    }
  }

  Future<void> register({required String name, required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authService.registerWithEmailAndPassword(
        name: name,
        email: email,
        password: password,
      );
      state = AsyncValue.data(credential.user);
    } catch (e, stackTrace) {
      final formatted = _formatError(e);
      debugPrint('Auth register error (${e.runtimeType}): $formatted');
      state = AsyncValue.error(formatted, stackTrace);
    }
  }

  String _formatError(Object? error) {
    if (error is String) return error;
    if (error is FirebaseAuthException) {
      return error.message ?? error.code;
    }
    if (error is Exception) return error.toString();
    return 'An unknown authentication error occurred.';
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }
}

// Global UI Authentication controller provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final notifier = AuthNotifier(authService);
  
  // Keep notifier in sync with Firebase state changes
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    notifier.updateFromAuthState(next);
  });
  
  return notifier;
});
