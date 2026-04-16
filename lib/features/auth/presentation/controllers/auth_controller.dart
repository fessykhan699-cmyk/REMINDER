import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/auth_local_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../../../data/providers/firestore_sync_provider.dart';

class AuthViewState {
  const AuthViewState({
    required this.status,
    required this.session,
    required this.onboardingCompleted,
    required this.isSubmitting,
    required this.errorMessage,
  });

  factory AuthViewState.initial() {
    return const AuthViewState(
      status: AuthStatus.initializing,
      session: null,
      onboardingCompleted: false,
      isSubmitting: false,
      errorMessage: null,
    );
  }

  final AuthStatus status;
  final AuthSession? session;
  final bool onboardingCompleted;
  final bool isSubmitting;
  final String? errorMessage;

  AuthViewState copyWith({
    AuthStatus? status,
    AuthSession? session,
    bool clearSession = false,
    bool? onboardingCompleted,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthViewState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final authLocalDatasourceProvider = Provider<AuthLocalDatasource>(
  (ref) => AuthLocalDatasource(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authLocalDatasourceProvider)),
);

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider<LogoutUseCase>(
  (ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);

final authControllerProvider = NotifierProvider<AuthController, AuthViewState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthViewState> {
  bool _disposed = false;

  @override
  AuthViewState build() {
    _disposed = false;
    final subscription = FirebaseAuth.instance.authStateChanges().listen(
      _onFirebaseAuthStateChanged,
      onError: (Object error) {
        debugPrint('Firebase auth stream error: $error');
      },
    );
    ref.onDispose(() {
      _disposed = true;
      subscription.cancel();
    });
    Future.microtask(initialize);
    return AuthViewState.initial();
  }

  void _onFirebaseAuthStateChanged(User? user) async {
    final current = state;

    // Local persistence is authoritative during startup. The first Firebase stream
    // event is intentionally ignored while initializing — initialize() reads the
    // persisted session and sets final state. After that, this stream monitors
    // for mid-session changes only.
    if (current.status == AuthStatus.initializing || current.isSubmitting) {
      return;
    }

    if (user == null && current.status == AuthStatus.authenticated) {
      // Remote sign-out: session revoked, password changed, account deleted
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        errorMessage: 'Your session has expired. Please sign in again.',
      );
      return;
    }

    if (user != null && current.status == AuthStatus.unauthenticated) {
      // Session silently restored (e.g. token refresh edge case)
      final String? idToken;
      try {
        idToken = await user.getIdToken();
      } catch (e) {
        debugPrint('Failed to fetch Firebase ID token: $e');
        return;
      }
      if (_disposed) return;
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: AuthSession(
          userId: user.uid,
          email: user.email ?? '',
          token: idToken ?? 'firebase-user',
          createdAt: user.metadata.creationTime ?? DateTime.now(),
        ),
        clearError: true,
      );
    }
  }

  Future<void> initialize() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final onboardingCompleted = await repository.isOnboardingCompleted();
      final session = await repository.currentSession();

      state = state.copyWith(
        onboardingCompleted: onboardingCompleted,
        session: session,
        status: session == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
        isSubmitting: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Failed to initialize session: $error',
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final session = await ref
          .read(loginUseCaseProvider)
          .call(email: email, password: password);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
        isSubmitting: false,
        clearError: true,
      );
      _triggerCloudRestore(session.userId);
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isSubmitting: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> loginWithGoogle() async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final datasource = ref.read(authLocalDatasourceProvider);
      final session = await datasource.loginWithGoogle();

      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
        isSubmitting: false,
        clearError: true,
      );
      _triggerCloudRestore(session.userId);
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isSubmitting: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      await ref.read(logoutUseCaseProvider).call();

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        isSubmitting: false,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> completeOnboarding() async {
    try {
      await ref.read(authRepositoryProvider).markOnboardingComplete();

      state = state.copyWith(onboardingCompleted: true);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  /// Triggers a cloud restore in the background after successful login.
  /// Only runs if Hive is empty (first install or new device).
  /// Does not await — runs fire-and-forget to avoid blocking login UX.
  void _triggerCloudRestore(String userId) {
    ref.read(firestoreSyncServiceProvider).restoreAllFromCloud(userId).catchError(
      (Object e) {
        debugPrint('[AuthController] cloud restore error: $e');
        return null;
      },
    );
  }
}
