import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../data/auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  onboardingNeeded
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    FirebaseAuth.instance,
    GoogleSignIn(),
    ref.watch(dioProvider),
  );
});

final authStatusProvider =
    StateNotifierProvider<AuthStatusNotifier, AuthStatus>((ref) {
  return AuthStatusNotifier(ref);
});

class AuthStatusNotifier extends StateNotifier<AuthStatus> {
  final Ref _ref;

  AuthStatusNotifier(this._ref) : super(AuthStatus.initial) {
    _init();
  }

  Future<void> _init() async {
    final repo = _ref.read(authRepositoryProvider);
    if (repo.currentUser == null) {
      state = AuthStatus.unauthenticated;
      return;
    }
    await _checkBackend();
  }

  Future<void> _checkBackend() async {
    state = AuthStatus.loading;
    try {
      final repo = _ref.read(authRepositoryProvider);
      final data = await repo.verifyWithBackend();
      if (data['onboarding_done'] == true) {
        state = AuthStatus.authenticated;
      } else {
        state = AuthStatus.onboardingNeeded;
      }
    } catch (_) {
      // If backend is unreachable but Firebase user exists, default to
      // onboardingNeeded so the user isn't kicked back to the login screen.
      final repo = _ref.read(authRepositoryProvider);
      if (repo.currentUser != null) {
        state = AuthStatus.onboardingNeeded;
      } else {
        state = AuthStatus.unauthenticated;
      }
    }
  }

  Future<void> onLoginSuccess() => _checkBackend();

  Future<void> signInWithApple() async {
    state = AuthStatus.loading;
    try {
      final repo = _ref.read(authRepositoryProvider);
      await repo.signInWithApple();
      await _checkBackend();
    } catch (e) {
      state = AuthStatus.unauthenticated;
      rethrow;
    }
  }

  /// Deletes the user account: backend → Firebase → prefs → sign-out.
  /// Returns `null` on success or an error message string on failure.
  Future<String?> deleteAccount() async {
    try {
      // 1. Backend cascade-delete
      final api = _ref.read(apiClientProvider);
      await api.deleteMe();
    } catch (_) {
      // Best-effort — continue with local cleanup
    }

    try {
      // 2. Delete Firebase user
      await FirebaseAuth.instance.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'requires-recent-login';
      }
      // Other Firebase errors — still proceed with sign-out
    }

    try {
      // 3. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    // 4. Sign out
    await _ref.read(authRepositoryProvider).signOut();
    state = AuthStatus.unauthenticated;
    return null;
  }

  void devBypass() {
    state = AuthStatus.onboardingNeeded;
  }

  void setAuthenticated() {
    state = AuthStatus.authenticated;
  }

  void logout() {
    _ref.read(authRepositoryProvider).signOut();
    state = AuthStatus.unauthenticated;
  }
}
