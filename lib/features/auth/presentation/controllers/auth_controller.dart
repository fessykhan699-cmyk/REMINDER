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
import '../../domain/usecases/sign_up_usecase.dart';
import '../../../../data/providers/firestore_sync_provider.dart';
import '../../../../data/services/workspace/workspace_provider.dart';
import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../../dashboard/presentation/controllers/dashboard_controller.dart';
import '../../../expenses/presentation/controllers/expenses_controller.dart';
import '../../../invoices/presentation/controllers/invoices_controller.dart';

class AuthViewState {
  const AuthViewState({
    required this.status,
    required this.session,
    required this.onboardingCompleted,
    required this.isSubmitting,
    required this.errorMessage,
    required this.reauthInProgress,
  });

  factory AuthViewState.initial() {
    return const AuthViewState(
      status: AuthStatus.initializing,
      session: null,
      onboardingCompleted: false,
      isSubmitting: false,
      errorMessage: null,
      reauthInProgress: false,
    );
  }

  final AuthStatus status;
  final AuthSession? session;
  final bool onboardingCompleted;
  final bool isSubmitting;
  final String? errorMessage;
  final bool reauthInProgress;

  AuthViewState copyWith({
    AuthStatus? status,
    AuthSession? session,
    bool clearSession = false,
    bool? onboardingCompleted,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool? reauthInProgress,
  }) {
    return AuthViewState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      reauthInProgress: reauthInProgress ?? this.reauthInProgress,
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

final signUpUseCaseProvider = Provider<SignUpUseCase>(
  (ref) => SignUpUseCase(ref.watch(authRepositoryProvider)),
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
      await _clearWorkspaceOwner();
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
      final workspaceOwnerId = await _resolveAndActivateWorkspaceOwner(
        user.uid,
      );
      if (_disposed) return;
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: AuthSession(
          userId: user.uid,
          email: user.email ?? '',
          token: idToken ?? 'firebase-user',
          createdAt: user.metadata.creationTime ?? DateTime.now(),
          isEmailVerified: user.emailVerified,
        ),
        clearError: true,
      );
      await _triggerCloudRestore(workspaceOwnerId);
    }
  }

  Future<void> initialize() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final onboardingCompleted = await repository.isOnboardingCompleted();
      final session = await repository.currentSession();
      String? workspaceOwnerId;
      if (session != null) {
        workspaceOwnerId = await _resolveAndActivateWorkspaceOwner(
          session.userId,
        );
      } else {
        await _clearWorkspaceOwner();
      }

      if (_disposed) return;

      state = state.copyWith(
        onboardingCompleted: onboardingCompleted,
        session: session,
        status: session == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
        isSubmitting: false,
        clearError: true,
      );
      if (workspaceOwnerId != null) {
        await _triggerCloudRestore(workspaceOwnerId);
      }
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

      final workspaceOwnerId = await _resolveAndActivateWorkspaceOwner(
        session.userId,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
        isSubmitting: false,
        clearError: true,
      );
      await _triggerCloudRestore(workspaceOwnerId);
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isSubmitting: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email: email);
      state = state.copyWith(isSubmitting: false);
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref.read(authRepositoryProvider).confirmPasswordReset(
            code: code,
            newPassword: newPassword,
          );
      state = state.copyWith(isSubmitting: false);
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<String?> verifyPasswordResetCode(String code) async {
    try {
      return await ref.read(authRepositoryProvider).verifyPasswordResetCode(code);
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final session = await ref
          .read(signUpUseCaseProvider)
          .call(email: email, password: password);

      final workspaceOwnerId = await _resolveAndActivateWorkspaceOwner(
        session.userId,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
        isSubmitting: false,
        clearError: true,
      );
      await _triggerCloudRestore(workspaceOwnerId);
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

      final workspaceOwnerId = await _resolveAndActivateWorkspaceOwner(
        session.userId,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: session,
        isSubmitting: false,
        clearError: true,
      );
      await _triggerCloudRestore(workspaceOwnerId);
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isSubmitting: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> reauthenticateWithGoogle() async {
    state = state.copyWith(reauthInProgress: true);
    try {
      final datasource = ref.read(authLocalDatasourceProvider);
      await datasource.reauthenticateWithGoogle();
    } finally {
      state = state.copyWith(reauthInProgress: false);
    }
  }

  Future<void> reauthenticateWithPassword(String password) async {
    state = state.copyWith(reauthInProgress: true);
    try {
      final datasource = ref.read(authLocalDatasourceProvider);
      await datasource.reauthenticateWithPassword(password);
    } finally {
      state = state.copyWith(reauthInProgress: false);
    }
  }

  Future<void> logout() async {
    ref.read(firestoreSyncServiceProvider).clearSession();
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      await ref.read(logoutUseCaseProvider).call();
      await _clearWorkspaceOwner();

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

  Future<void> deleteAccount(String userId) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref.read(firestoreSyncServiceProvider).deleteAccount(userId);
      await _clearWorkspaceOwner();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        isSubmitting: false,
      );
    } catch (e) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
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

  Future<void> reloadUser() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final session = await ref.read(authRepositoryProvider).reloadUser();
      if (_disposed) return;
      state = state.copyWith(session: session, isSubmitting: false);
    } catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  /// Triggers a cloud restore after successful login.
  /// Awaited — ensures Firestore data is merged into Hive before callers proceed.
  Future<void> _triggerCloudRestore(String ownerId) async {
    try {
      await ref
          .read(firestoreSyncServiceProvider)
          .restoreAllFromCloud(ownerId);
    } catch (e) {
      debugPrint('[AuthController] cloud restore error: $e');
    }
    ref.invalidate(invoicesControllerProvider);
    ref.invalidate(clientsControllerProvider);
    ref.invalidate(dashboardControllerProvider);
    ref.invalidate(expensesControllerProvider);
  }

  Future<String> _resolveAndActivateWorkspaceOwner(String userId) async {
    try {
      final resolvedOwnerId = await ref
          .read(workspaceServiceProvider)
          .resolveWorkspaceOwner(userId);
      final ownerId = resolvedOwnerId ?? userId;
      ref.read(workspaceOwnerIdStateProvider.notifier).state = ownerId;
      await WorkspaceOwnerStorage.save(ownerId);
      if (ownerId == userId) {
        await ref.read(workspaceServiceProvider).createWorkspace(userId);
      }
      return ownerId;
    } catch (e, st) {
      debugPrint('[AuthController] workspace owner resolve failed: $e\n$st');
      ref.read(workspaceOwnerIdStateProvider.notifier).state = userId;
      await WorkspaceOwnerStorage.save(userId);
      return userId;
    }
  }

  Future<void> _clearWorkspaceOwner() async {
    ref.read(workspaceOwnerIdStateProvider.notifier).state = null;
    await WorkspaceOwnerStorage.clear();
  }
}
