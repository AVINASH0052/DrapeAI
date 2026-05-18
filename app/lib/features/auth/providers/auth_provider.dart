import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
