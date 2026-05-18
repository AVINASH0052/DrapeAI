import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final Dio _dio;

  AuthRepository(this._auth, this._googleSignIn, this._dio);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> getIdToken() async => _auth.currentUser?.getIdToken();

  Future<String> sendOtp(String phoneNumber) async {
    final completer = Completer<String>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
        if (!completer.isCompleted) completer.complete('');
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(e.message ?? 'Phone verification failed'));
        }
      },
      codeSent: (id, _) {
        if (!completer.isCompleted) completer.complete(id);
      },
      codeAutoRetrievalTimeout: (id) {
        if (!completer.isCompleted) completer.complete(id);
      },
    );
    return completer.future;
  }

  Future<User> verifyOtp(String verificationId, String otp) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  Future<User> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  Future<Map<String, dynamic>> verifyWithBackend() async {
    final response = await _dio.post('/auth/verify');
    return response.data as Map<String, dynamic>;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
