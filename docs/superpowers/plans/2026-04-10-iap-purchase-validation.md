# IAP Purchase Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden client-side IAP validation so only confirmed paid purchases grant Pro, Pro is never stripped by unreliable query results, and confirmed cancellations correctly revoke Pro.

**Architecture:** Three targeted fixes across two service files and one controller: (1) `PlayBillingService.syncOwnedProState()` gets an explicit allowlist replacing the current denylist, (2) `SubscriptionController.build()` is changed to only upgrade (never downgrade) from the sync result, (3) `PlayBillingController._handleCancelledPurchase()` is extended to revoke Pro when a confirmed cancellation arrives for a currently-Pro user.

**Tech Stack:** Flutter, Riverpod (`AsyncNotifier`), `in_app_purchase`, `in_app_purchase_android`, Hive

---

### Task 1: Exclude `pending` purchases from Pro grant in `syncOwnedProState()`

**Files:**
- Modify: `lib/features/subscription/data/services/play_billing_service.dart`

- [ ] **Step 1: Replace the denylist status filter with an explicit allowlist**

Open `lib/features/subscription/data/services/play_billing_service.dart`.

Find the `syncOwnedProState()` method (lines 104–132). The inner loop currently reads:

```dart
if (purchase.status == PurchaseStatus.error ||
    purchase.status == PurchaseStatus.canceled) {
  continue;
}

return true;
```

Replace those lines with:

```dart
if (purchase.status != PurchaseStatus.purchased &&
    purchase.status != PurchaseStatus.restored) {
  continue;
}

return true;
```

The full updated method looks like this:

```dart
Future<bool?> syncOwnedProState() async {
  final available = await isAvailable();
  if (!available) {
    return null;
  }

  final addition = _billingClient
      .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
  final response = await addition.queryPastPurchases();
  final error = response.error;
  if (error != null) {
    throw StateError(error.message);
  }

  for (final purchase in response.pastPurchases) {
    if (!isProProduct(purchase.productID)) {
      continue;
    }

    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      continue;
    }

    return true;
  }

  return false;
}
```

- [ ] **Step 2: Run `flutter analyze` on the file**

```bash
flutter analyze lib/features/subscription/data/services/play_billing_service.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/subscription/data/services/play_billing_service.dart
git commit -m "$(cat <<'EOF'
fix: only grant Pro from purchased/restored status in syncOwnedProState

Previously, pending purchases (payment not yet settled) passed through
the denylist filter and returned true, granting Pro before money cleared.
Now uses an explicit allowlist: only purchased and restored count.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Remove auto-downgrade from `SubscriptionController.build()`

**Files:**
- Modify: `lib/features/subscription/presentation/controllers/subscription_controller.dart`

- [ ] **Step 1: Change sync to upgrade-only**

Open `lib/features/subscription/presentation/controllers/subscription_controller.dart`.

Find `SubscriptionController.build()` (lines 31–47). The current sync block reads:

```dart
try {
  final syncedIsPro = await ref
      .read(playBillingServiceProvider)
      .syncOwnedProState();
  if (syncedIsPro == null || syncedIsPro == localState.isPro) {
    return localState;
  }

  return datasource.savePlan(isPro: syncedIsPro);
} catch (_) {
  return localState;
}
```

Replace with:

```dart
try {
  final syncedIsPro = await ref
      .read(playBillingServiceProvider)
      .syncOwnedProState();
  // Only upgrade (free → pro). Never downgrade from sync — queryPastPurchases
  // can return an empty list when Play Store is offline, which is not a
  // confirmed cancellation. Downgrades happen via the purchase stream only.
  if (syncedIsPro != true) {
    return localState;
  }
  if (localState.isPro) {
    return localState;
  }
  return datasource.savePlan(isPro: true);
} catch (_) {
  return localState;
}
```

- [ ] **Step 2: Run `flutter analyze` on the file**

```bash
flutter analyze lib/features/subscription/presentation/controllers/subscription_controller.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/subscription/presentation/controllers/subscription_controller.dart
git commit -m "$(cat <<'EOF'
fix: never auto-downgrade Pro from sync query result

queryPastPurchases() can return an empty list when Play Store is
temporarily offline. Treating that as 'no subscription' was stripping
Pro from paying users. Sync now only upgrades (free→pro); downgrades
happen exclusively via confirmed purchase stream cancellation events.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Revoke Pro on confirmed stream cancellation in `PlayBillingController`

**Files:**
- Modify: `lib/features/subscription/presentation/controllers/play_billing_controller.dart`

- [ ] **Step 1: Extend `_handleCancelledPurchase()` to revoke Pro**

Open `lib/features/subscription/presentation/controllers/play_billing_controller.dart`.

Find `_handleCancelledPurchase()` (lines 291–314). The current method reads:

```dart
void _handleCancelledPurchase() {
  final current = state.valueOrNull;
  if (current == null) {
    _currentAction = _BillingAction.none;
    return;
  }

  final action = _currentAction;
  _currentAction = _BillingAction.none;

  if (action == _BillingAction.purchase) {
    _emitFeedback(
      current,
      type: PlayBillingFeedbackType.purchaseCancelled,
      message: 'Purchase cancelled',
      isPurchasePending: false,
    );
    return;
  }

  state = AsyncValue.data(
    current.copyWith(isPurchasePending: false, isRestoring: false),
  );
}
```

Replace with:

```dart
void _handleCancelledPurchase() {
  final current = state.valueOrNull;
  if (current == null) {
    _currentAction = _BillingAction.none;
    return;
  }

  final action = _currentAction;
  _currentAction = _BillingAction.none;

  // A confirmed cancellation/error from the purchase stream is the only
  // reliable downgrade signal. Revoke Pro if the user currently has it.
  final subscriptionState =
      ref.read(subscriptionControllerProvider).valueOrNull;
  if (subscriptionState?.isPro == true) {
    _persistPlan(isPro: false);
  }

  if (action == _BillingAction.purchase) {
    _emitFeedback(
      current,
      type: PlayBillingFeedbackType.purchaseCancelled,
      message: 'Purchase cancelled',
      isPurchasePending: false,
    );
    return;
  }

  state = AsyncValue.data(
    current.copyWith(isPurchasePending: false, isRestoring: false),
  );
}
```

Note: `_handleCancelledPurchase()` is only called from within `_handlePurchaseUpdates()`, which already filters by `isProProduct(purchase.productID)` — so this code only runs for Pro products.

- [ ] **Step 2: Run `flutter analyze` on the file**

```bash
flutter analyze lib/features/subscription/presentation/controllers/play_billing_controller.dart
```

Expected: no issues.

- [ ] **Step 3: Run full app analyze**

```bash
flutter analyze
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/subscription/presentation/controllers/play_billing_controller.dart
git commit -m "$(cat <<'EOF'
fix: revoke Pro on confirmed purchase stream cancellation

_handleCancelledPurchase now calls _persistPlan(isPro: false) when the
user is currently Pro and a confirmed canceled/error event arrives from
the purchase stream. This is the only reliable downgrade signal.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- ✅ Fix 1: Exclude `pending` from Pro grant — Task 1 replaces denylist with allowlist in `syncOwnedProState()`
- ✅ Fix 2: Remove auto-downgrade — Task 2 changes `SubscriptionController.build()` to upgrade-only
- ✅ Fix 3: Revoke Pro on confirmed stream cancellation — Task 3 extends `_handleCancelledPurchase()`

**Placeholder scan:** None found. All code is complete.

**Type consistency:**
- `_persistPlan(isPro: false)` — defined at line 363 of `play_billing_controller.dart`, called in Task 3 — consistent
- `subscriptionControllerProvider` — imported in `play_billing_controller.dart` via `subscription_controller.dart` import already present — consistent
- `PurchaseStatus.purchased`, `PurchaseStatus.restored` — both exist in `in_app_purchase` package — consistent
