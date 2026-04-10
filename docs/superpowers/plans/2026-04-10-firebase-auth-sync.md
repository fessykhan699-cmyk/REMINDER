# Firebase Auth Stream Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Subscribe to `FirebaseAuth.authStateChanges()` in `AuthController` so the app reacts to mid-session sign-outs (remote revocation, password change, account deletion) with a message and redirect to login.

**Architecture:** A `StreamSubscription<User?>` is added to `AuthController`. It starts in `build()`, is cancelled in `ref.onDispose()`, and delegates to a private `_onFirebaseAuthStateChanged(User?)` handler. The handler ignores events during `initializing` or `isSubmitting` states to prevent race conditions with the existing startup and login/logout flows.

**Tech Stack:** Flutter, Riverpod (`Notifier`), `firebase_auth` (`FirebaseAuth.authStateChanges()`), `dart:async` (`StreamSubscription`)

---

### Task 1: Add stream subscription to AuthController

**Files:**
- Modify: `lib/features/auth/presentation/controllers/auth_controller.dart`

- [ ] **Step 1: Add the import for `dart:async` and `firebase_auth`**

At the top of `auth_controller.dart`, add:

```dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
```

- [ ] **Step 2: Add the `_authStateSubscription` field to `AuthController`**

Inside `class AuthController extends Notifier<AuthViewState>`, add the field after `bool _isBootstrapped = false;`:

```dart
StreamSubscription<User?>? _authStateSubscription;
```

- [ ] **Step 3: Start the stream subscription in `build()`**

Replace the existing `build()` method:

```dart
@override
AuthViewState build() {
  if (!_isBootstrapped) {
    _isBootstrapped = true;
    Future<void>(initialize);
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _onFirebaseAuthStateChanged,
      onError: (Object error) {
        debugPrint('Firebase auth stream error: $error');
      },
    );
    ref.onDispose(() {
      _authStateSubscription?.cancel();
      _authStateSubscription = null;
    });
  }
  return AuthViewState.initial();
}
```

- [ ] **Step 4: Add the `_onFirebaseAuthStateChanged` handler**

Add this private method to `AuthController` after `build()`:

```dart
void _onFirebaseAuthStateChanged(User? user) {
  final current = state;

  // Ignore during startup and active auth operations — those flows manage state themselves
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
    state = state.copyWith(
      status: AuthStatus.authenticated,
      session: AuthSession(
        userId: user.uid,
        email: user.email ?? '',
        token: 'firebase-user',
        createdAt: user.metadata.creationTime ?? DateTime.now(),
      ),
      clearError: true,
    );
  }
}
```

- [ ] **Step 5: Add `debugPrint` import if not already present**

Check that `package:flutter/foundation.dart` is imported (it provides `debugPrint`). The existing file already imports Riverpod but not Flutter foundation. Add:

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 6: Run the app and verify no compile errors**

```bash
flutter run
```

Expected: App launches normally, no compile errors.

- [ ] **Step 7: Verify stream fires correctly — manual test**

While the app is running and you are logged in:
1. Go to Firebase Console → Authentication → find your test user
2. Click the user → "Revoke sessions" (or change their password)
3. Within a few seconds the app should navigate to the login screen
4. The login screen should show: `'Your session has expired. Please sign in again.'`

- [ ] **Step 8: Verify no double-state during login — manual test**

1. Log out normally via the app
2. Log back in
3. Confirm the app navigates to dashboard without showing the expiry message
4. Confirm there are no duplicate state updates (no flicker)

- [ ] **Step 9: Commit**

```bash
git add lib/features/auth/presentation/controllers/auth_controller.dart
git commit -m "feat: subscribe to Firebase auth state changes in AuthController

Handles mid-session sign-outs (remote revocation, password change,
account deletion) by redirecting to login with an expiry message.
Ignores stream events during initializing and isSubmitting states
to prevent race conditions with startup and login/logout flows.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- ✅ Subscribe to `authStateChanges()` in `AuthController.build()`
- ✅ Cancel via `ref.onDispose()`
- ✅ Ignore during `initializing` status
- ✅ Ignore during `isSubmitting`
- ✅ Firebase emits null + authenticated → unauthenticated + expiry message
- ✅ Firebase emits user + unauthenticated → authenticated + clear error
- ✅ Firebase emits user + authenticated → ignored (handled by existing condition check)
- ✅ Stream errors caught and logged, do not change auth state
- ✅ Router redirect already handles unauthenticated → login (no router changes needed)

**Placeholder scan:** None found.

**Type consistency:** `AuthSession`, `AuthStatus`, `AuthViewState.copyWith` parameters all match existing definitions in `auth_session.dart` and `auth_controller.dart`.
