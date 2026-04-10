# IAP Purchase Validation — Design Spec

**Date:** 2026-04-10  
**Status:** Approved

## Problem

The current client-side IAP validation has three issues:

1. **`syncOwnedProState()` grants Pro from `pending` purchases** — a payment not yet settled is treated as successful, giving Pro access before money has cleared.
2. **`SubscriptionController.build()` auto-downgrades on empty/unreliable query results** — `queryPastPurchases()` can return an empty list when Play Store is slow or offline; treating that as "no subscription" strips Pro from paying users.
3. **No stream-based downgrade path** — subscription cancellations delivered via the `purchaseStream` are silently ignored (`canceled`/`error` events only clear pending UI state, they don't revoke Pro).

## Goal

Harden client-side IAP validation so that:
- Only confirmed paid purchases (`purchased` or `restored` status) grant Pro
- Pro is never stripped by a network-unreliable query result
- Confirmed cancellations from the purchase stream correctly revoke Pro

## Architecture

### Files changed

| File | Change |
|------|--------|
| `lib/features/subscription/data/services/play_billing_service.dart` | Exclude `pending` from positive match in `syncOwnedProState()` |
| `lib/features/subscription/presentation/controllers/subscription_controller.dart` | Remove auto-downgrade; sync only upgrades |
| `lib/features/subscription/presentation/controllers/play_billing_controller.dart` | Revoke Pro on confirmed `canceled`/`error` stream event for a Pro user |

### Fix 1 — Exclude `pending` from Pro grant (`PlayBillingService.syncOwnedProState`)

Replace the current status filter (excludes only `error` and `canceled`) with an explicit allowlist: only `PurchaseStatus.purchased` and `PurchaseStatus.restored` return `true`.

```dart
// Before: excludes error + canceled (pending passes through)
if (purchase.status == PurchaseStatus.error ||
    purchase.status == PurchaseStatus.canceled) {
  continue;
}
return true;

// After: explicit allowlist
if (purchase.status != PurchaseStatus.purchased &&
    purchase.status != PurchaseStatus.restored) {
  continue;
}
return true;
```

### Fix 2 — Remove auto-downgrade (`SubscriptionController.build`)

`syncOwnedProState()` is unreliable as a downgrade signal — it may return `false` from an empty list when Play Store is temporarily unavailable. Sync should only upgrade (free → pro), never downgrade (pro → free).

```dart
// Before: syncs both directions
if (syncedIsPro == null || syncedIsPro == localState.isPro) {
  return localState;
}
return datasource.savePlan(isPro: syncedIsPro); // can downgrade

// After: only upgrade
if (syncedIsPro != true) {
  return localState; // keep local state; never downgrade from sync
}
if (localState.isPro) {
  return localState; // already pro, no change needed
}
return datasource.savePlan(isPro: true); // upgrade only
```

### Fix 3 — Revoke Pro on confirmed stream cancellation (`PlayBillingController._handleCancelledPurchase`)

When the purchase stream delivers `canceled` or `error` for a Pro product AND the user is currently Pro, revoke the plan. This is the only reliable downgrade signal.

The existing `_handleCancelledPurchase()` only clears UI state (pending/restoring flags). Extend it to also call `_persistPlan(isPro: false)` when the current subscription state is Pro.

```dart
void _handleCancelledPurchase() {
  // ... existing UI state cleanup ...

  // If user is currently Pro, a confirmed cancellation revokes it
  final subscriptionState = ref.read(subscriptionControllerProvider).valueOrNull;
  if (subscriptionState?.isPro == true) {
    _persistPlan(isPro: false); // fire-and-forget; UI will update via invalidate
  }
}
```

Note: `_handleCancelledPurchase` is only called for Pro products (the loop in `_handlePurchaseUpdates` filters by `isProProduct`), so no product-ID check is needed here.

## Data Flow

```
purchaseStream → canceled/error for Pro product
  → _handleCancelledPurchase()
  → subscriptionState.isPro == true?
      → yes: _persistPlan(isPro: false) → Hive + invalidate subscriptionController
      → no:  clear UI flags only (existing behaviour)

App startup → SubscriptionController.build()
  → syncOwnedProState()
      → pending purchase → skip (not paid)
      → purchased/restored → return true → savePlan(isPro: true)
      → empty/error result → return false/null → keep localState (no downgrade)
```

## Edge Cases

| Case | Behaviour |
|------|-----------|
| Payment pending, app restarts | `syncOwnedProState` skips pending → stays Free until payment clears |
| Play Store offline at startup | `syncOwnedProState` returns null → local state preserved |
| Subscription cancelled in Play Store | Next app session: `purchaseStream` delivers `canceled` → Pro revoked |
| User was Free, sync returns false | No change (already Free, fix 2 guard hits `syncedIsPro != true`) |
| User was Pro, sync returns false (offline) | No change (fix 2: sync never downgrades) |
| User was Pro, subscription genuinely lapsed | `purchaseStream` cancellation event → revoked via fix 3 |

## Out of Scope

- Server-side receipt validation (Cloud Function) — requires Firebase Blaze plan + service account setup
- iOS App Store validation — app is Android-only
- Subscription expiry polling — stream events are sufficient
