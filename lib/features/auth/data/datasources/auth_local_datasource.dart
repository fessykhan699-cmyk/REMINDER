import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_session_model.dart';

class AuthLocalDatasource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        "276742242102-72vd1njot3c71hoobfpv146cajs3d7u7.apps.googleusercontent.com",
  );

  Future<AuthSessionModel?> currentSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    return AuthSessionModel(
      userId: user.uid,
      email: user.email ?? '',
      token: 'firebase-user',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      isEmailVerified: user.emailVerified,
    );
  }

  Future<AuthSessionModel> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw Exception('Email is required.');
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      return _sessionFromUser(credential.user!, normalizedEmail);
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'user-not-found' => 'No account found for this email.',
        'wrong-password' => 'Incorrect password.',
        'invalid-email' => 'Invalid email address.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many failed attempts. Try again later.',
        'invalid-credential' => 'Invalid credentials.',
        _ => 'Login failed: ${e.message ?? 'Unknown error.'}',
      };
      throw Exception(message);
    }
  }

  Future<AuthSessionModel> signUp({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw Exception('Email is required.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user!;
      
      // Trigger email verification for new account
      try {
        await user.sendEmailVerification();
      } catch (e) {
        debugPrint('Failed to send verification email: $e');
      }
      
      return _sessionFromUser(user, normalizedEmail);
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'email-already-in-use' => 'An account already exists for this email.',
        'invalid-email' => 'Invalid email address.',
        'operation-not-allowed' => 'Email/password accounts are not enabled.',
        'weak-password' => 'The password provided is too weak.',
        _ => 'Sign up failed: ${e.message ?? 'Unknown error.'}',
      };
      throw Exception(message);
    }
  }

  AuthSessionModel _sessionFromUser(User user, String fallbackEmail) {
    return AuthSessionModel(
      userId: user.uid,
      email: user.email ?? fallbackEmail,
      token: 'firebase-user',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      isEmailVerified: user.emailVerified,
    );
  }

  Future<AuthSessionModel> loginWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in cancelled by user.');
    }
    final auth = await googleUser.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw Exception('Google sign-in failed: no ID token.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    if (userCredential.user == null) {
      throw Exception('Google sign-in failed: no user returned.');
    }

    return _sessionFromUser(userCredential.user!, googleUser.email);
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
  
  Future<AuthSessionModel?> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    await user.reload();
    final updatedUser = _auth.currentUser;
    if (updatedUser == null) return null;
    
    return _sessionFromUser(updatedUser, updatedUser.email ?? '');
  }
  
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw Exception('Email is required.');
    }
    await _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'expired-action-code' => 'The reset link has expired.',
        'invalid-action-code' => 'The reset link is invalid.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' => 'User not found.',
        'weak-password' => 'The password provided is too weak.',
        _ => 'Password reset failed: ${e.message ?? 'Unknown error.'}',
      };
      throw Exception(message);
    }
  }

  Future<String> verifyPasswordResetCode(String code) async {
    try {
      return await _auth.verifyPasswordResetCode(code);
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'expired-action-code' => 'The reset link has expired.',
        'invalid-action-code' => 'The reset link is invalid.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' => 'User not found.',
        _ => 'Verification failed: ${e.message ?? 'Unknown error.'}',
      };
      throw Exception(message);
    }
  }

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  }
}
