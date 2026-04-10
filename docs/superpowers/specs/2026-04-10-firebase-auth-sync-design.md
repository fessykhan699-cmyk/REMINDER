# Firebase Auth Stream Sync — Design Spec

**Date:** 2026-04-10  
**Status:** Approved

## Problem

`AuthController` checks Firebase Auth once at startup via `initialize()`. If Firebase revokes the session after startup (password changed, account deleted, token expired on another device), the app never finds out. The user continues using the app in an unauthenticated state, which causes silent failures on any Firebase-backed operation.

## Goal

Keep the app's auth state continuously in sync with Firebase Auth state changes for the lifetime of the app session — without breaking the existing login, logout, or initialization flows.

## Approach

Subscribe to `FirebaseAuth.authStateChanges()` inside `AuthController.build()`. The stream runs after initialization and handles mid-session state changes only.

## Architecture

### Single file changed: `auth_controller.dart`

No new files, no new providers, no router changes.

### Stream subscription lifecycle

- Started in `AuthController.build()` after scheduling `initialize()`
- Cancelled via `ref.onDispose()` when the notifier is destroyed
- Stored as `StreamSubscription<User?>` on the controller

### Stream event handling rules

| Condition | Action |
|-----------|--------|
| `status == initializing` | Ignore — startup flow handles this |
| `isSubmitting == true` | Ignore — active login/logout is handling state |
| Firebase emits `null` (sign-out) and `status == authenticated` | Set `unauthenticated`, clear session, set error message |
| Firebase emits a `User` and `status == unauthenticated` | Restore session silently, set `authenticated`, clear error |
| Firebase emits a `User` and `status == authenticated` | Ignore — already correct state |

### Session expiry message

`'Your session has expired. Please sign in again.'`

Displayed via existing `errorMessage` field on `AuthViewState`. The router already redirects to login when `status == unauthenticated` — the message appears on the login screen.

## Data Flow

```
FirebaseAuth.authStateChanges()
    │
    ▼
AuthController._onFirebaseAuthStateChanged(User? user)
    │
    ├── status == initializing OR isSubmitting → skip
    │
    ├── user == null AND status == authenticated
    │       → state: unauthenticated, session: null, errorMessage: expiry message
    │
    └── user != null AND status == unauthenticated
            → state: authenticated, session: AuthSession from user, clearError
```

## Error Handling

- Stream errors are caught and logged via `debugPrint`. They do not change auth state — a stream error is not the same as a sign-out.
- If `initialize()` and the stream fire close together at startup, the `initializing` guard on the stream handler prevents a race condition.

## Out of Scope

- Router changes — existing redirect logic handles `unauthenticated` state already
- Login/signup screens — no changes
- Token refresh — Firebase SDK handles silently; stream only fires on actual user changes
