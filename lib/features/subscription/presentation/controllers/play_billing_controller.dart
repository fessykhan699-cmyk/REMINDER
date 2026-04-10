import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../data/services/play_billing_service.dart';
import 'subscription_controller.dart';

final playBillingControllerProvider =
    AsyncNotifierProvider<PlayBillingController, PlayBillingState>(
      PlayBillingController.new,
    );

enum PlayBillingFeedbackType {
  purchaseSuccess,
  purchaseCancelled,
  restoreSuccess,
  restoreNotFound,
  restoreFailed,
}

class PlayBillingFeedback {
  const PlayBillingFeedback({
    required this.id,
    required this.type,
    required this.message,
  });

  final int id;
  final PlayBillingFeedbackType type;
  final String message;
}

class PlayBillingState {
  const PlayBillingState({
    required this.storeAvailable,
    this.monthlyProduct,
    this.yearlyProduct,
    this.monthlyProductNotFound = false,
    this.yearlyProductNotFound = false,
    this.errorMessage,
    this.isPurchasePending = false,
    this.isRestoring = false,
    this.feedback,
  });

  const PlayBillingState.initial() : this(storeAvailable: false);

  static const Object _sentinel = Object();

  final bool storeAvailable;
  final ProductDetails? monthlyProduct;
  final ProductDetails? yearlyProduct;
  final bool monthlyProductNotFound;
  final bool yearlyProductNotFound;
  final String? errorMessage;
  final bool isPurchasePending;
  final bool isRestoring;
  final PlayBillingFeedback? feedback;

  bool get canPurchase => (canPurchaseMonthly || canPurchaseYearly);

  bool get canPurchaseMonthly =>
      storeAvailable &&
      monthlyProduct != null &&
      !isPurchasePending &&
      !isRestoring;

  bool get canPurchaseYearly =>
      storeAvailable &&
      yearlyProduct != null &&
      !isPurchasePending &&
      !isRestoring;

  bool get canRestore => storeAvailable && !isPurchasePending && !isRestoring;

  PlayBillingState copyWith({
    bool? storeAvailable,
    ProductDetails? monthlyProduct,
    ProductDetails? yearlyProduct,
    bool? monthlyProductNotFound,
    bool? yearlyProductNotFound,
    Object? errorMessage = _sentinel,
    bool? isPurchasePending,
    bool? isRestoring,
    Object? feedback = _sentinel,
  }) {
    return PlayBillingState(
      storeAvailable: storeAvailable ?? this.storeAvailable,
      monthlyProduct: monthlyProduct ?? this.monthlyProduct,
      yearlyProduct: yearlyProduct ?? this.yearlyProduct,
      monthlyProductNotFound:
          monthlyProductNotFound ?? this.monthlyProductNotFound,
      yearlyProductNotFound:
          yearlyProductNotFound ?? this.yearlyProductNotFound,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      isPurchasePending: isPurchasePending ?? this.isPurchasePending,
      isRestoring: isRestoring ?? this.isRestoring,
      feedback: identical(feedback, _sentinel)
          ? this.feedback
          : feedback as PlayBillingFeedback?,
    );
  }
}

enum _BillingAction { none, purchase, restore }

class PlayBillingController extends AsyncNotifier<PlayBillingState> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  _BillingAction _currentAction = _BillingAction.none;
  int _feedbackCounter = 0;

  @override
  Future<PlayBillingState> build() async {
    _purchaseSubscription ??= ref
        .read(playBillingServiceProvider)
        .purchaseStream
        .listen((purchases) async {
          await _handlePurchaseUpdates(purchases);
        }, onError: _handlePurchaseStreamError);

    ref.onDispose(() async {
      await _purchaseSubscription?.cancel();
      _purchaseSubscription = null;
    });

    try {
      final catalog = await ref.read(playBillingServiceProvider).loadCatalog();
      return PlayBillingState(
        storeAvailable: catalog.storeAvailable,
        monthlyProduct: catalog.monthlyProduct,
        yearlyProduct: catalog.yearlyProduct,
        monthlyProductNotFound: catalog.monthlyProductNotFound,
        yearlyProductNotFound: catalog.yearlyProductNotFound,
        errorMessage: catalog.errorMessage,
      );
    } catch (_) {
      return const PlayBillingState(
        storeAvailable: false,
        errorMessage: 'Unable to connect to Google Play Billing right now.',
      );
    }
  }

  Future<void> purchaseMonthlyPro() async {
    final current = state.valueOrNull;
    if (current == null || !current.canPurchaseMonthly) {
      return;
    }

    await _purchasePro(current.monthlyProduct!, fallbackState: current);
  }

  Future<void> purchaseYearlyPro() async {
    final current = state.valueOrNull;
    if (current == null || !current.canPurchaseYearly) {
      return;
    }

    await _purchasePro(current.yearlyProduct!, fallbackState: current);
  }

  Future<void> _purchasePro(
    ProductDetails product, {
    required PlayBillingState fallbackState,
  }) async {
    _currentAction = _BillingAction.purchase;
    state = AsyncValue.data(
      fallbackState.copyWith(isPurchasePending: true, feedback: null),
    );

    try {
      final started = await ref
          .read(playBillingServiceProvider)
          .purchase(product);
      if (!started) {
        _currentAction = _BillingAction.none;
        _emitFeedback(
          state.valueOrNull ?? fallbackState,
          type: PlayBillingFeedbackType.purchaseCancelled,
          message: 'Purchase cancelled',
          isPurchasePending: false,
        );
      }
    } catch (_) {
      _currentAction = _BillingAction.none;
      _emitFeedback(
        state.valueOrNull ?? fallbackState,
        type: PlayBillingFeedbackType.purchaseCancelled,
        message: 'Purchase cancelled',
        isPurchasePending: false,
      );
    }
  }

  Future<void> restorePurchases() async {
    final current = state.valueOrNull;
    if (current == null || !current.canRestore) {
      return;
    }

    _currentAction = _BillingAction.restore;
    state = AsyncValue.data(
      current.copyWith(isRestoring: true, feedback: null),
    );

    try {
      await ref.read(playBillingServiceProvider).restorePurchases();
      final restoredIsPro = await _syncPlanFromStore();
      _currentAction = _BillingAction.none;

      final latest = state.valueOrNull ?? current;
      if (restoredIsPro == true) {
        _emitFeedback(
          latest,
          type: PlayBillingFeedbackType.restoreSuccess,
          message: 'Purchases restored.',
          isRestoring: false,
        );
        return;
      }

      _emitFeedback(
        latest,
        type: PlayBillingFeedbackType.restoreNotFound,
        message: 'No purchases to restore.',
        isRestoring: false,
      );
    } catch (_) {
      _currentAction = _BillingAction.none;
      _emitFeedback(
        state.valueOrNull ?? current,
        type: PlayBillingFeedbackType.restoreFailed,
        message: 'Unable to restore purchases right now.',
        isRestoring: false,
      );
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!PlayBillingService.isProProduct(purchase.productID)) {
        continue;
      }

      try {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            final current = state.valueOrNull;
            if (current != null) {
              state = AsyncValue.data(
                current.copyWith(isPurchasePending: true, feedback: null),
              );
            }
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await _handleSuccessfulPurchase(purchase);
          case PurchaseStatus.error:
            _handleErrorPurchase();
          case PurchaseStatus.canceled:
            await _handleCancelledPurchase();
        }
      } finally {
        if (purchase.pendingCompletePurchase) {
          await ref.read(playBillingServiceProvider).completePurchase(purchase);
        }
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    await _persistPlan(isPro: true);

    final current = state.valueOrNull ?? const PlayBillingState.initial();
    final next = current.copyWith(isPurchasePending: false, isRestoring: false);

    if (_currentAction == _BillingAction.purchase) {
      _currentAction = _BillingAction.none;
      _emitFeedback(
        next,
        type: PlayBillingFeedbackType.purchaseSuccess,
        message: 'Invoice Flow Pro is now active.',
      );
      return;
    }

    state = AsyncValue.data(next);
  }

  // Transient billing error — not a confirmed cancellation; do not revoke Pro.
  void _handleErrorPurchase() {
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

  // Explicit user cancellation — reliable downgrade signal; revoke Pro.
  Future<void> _handleCancelledPurchase() async {
    final current = state.valueOrNull;
    if (current == null) {
      _currentAction = _BillingAction.none;
      return;
    }

    final action = _currentAction;
    _currentAction = _BillingAction.none;

    // User explicitly cancelled — revoke Pro if the user currently has it.
    final subscriptionState =
        ref.read(subscriptionControllerProvider).valueOrNull;
    if (subscriptionState?.isPro == true) {
      await _persistPlan(isPro: false);
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

  void _handlePurchaseStreamError(Object error, StackTrace stackTrace) {
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

    if (action == _BillingAction.restore) {
      _emitFeedback(
        current,
        type: PlayBillingFeedbackType.restoreFailed,
        message: 'Unable to restore purchases right now.',
        isRestoring: false,
      );
      return;
    }

    state = AsyncValue.data(
      current.copyWith(isPurchasePending: false, isRestoring: false),
    );
  }

  Future<bool?> _syncPlanFromStore() async {
    final syncedIsPro = await ref
        .read(playBillingServiceProvider)
        .syncOwnedProState();
    if (syncedIsPro == null) {
      return null;
    }

    await _persistPlan(isPro: syncedIsPro);
    return syncedIsPro;
  }

  Future<void> _persistPlan({required bool isPro}) async {
    await ref.read(subscriptionLocalDatasourceProvider).savePlan(isPro: isPro);
    ref.invalidate(subscriptionControllerProvider);
  }

  void _emitFeedback(
    PlayBillingState base, {
    required PlayBillingFeedbackType type,
    required String message,
    bool? isPurchasePending,
    bool? isRestoring,
  }) {
    _feedbackCounter += 1;
    state = AsyncValue.data(
      base.copyWith(
        isPurchasePending: isPurchasePending,
        isRestoring: isRestoring,
        feedback: PlayBillingFeedback(
          id: _feedbackCounter,
          type: type,
          message: message,
        ),
      ),
    );
  }
}
