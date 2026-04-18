import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../data/services/billing_service.dart';
import '../../domain/entities/subscription_state.dart';
import '../../domain/services/billing_service_interface.dart';
import 'subscription_controller.dart';

final billingControllerProvider =
    AsyncNotifierProvider<BillingController, BillingState>(
      BillingController.new,
    );

enum BillingFeedbackType {
  purchaseSuccess,
  purchaseCancelled,
  restoreSuccess,
  restoreNotFound,
  restoreFailed,
}

class BillingFeedback {
  const BillingFeedback({
    required this.id,
    required this.type,
    required this.message,
  });

  final int id;
  final BillingFeedbackType type;
  final String message;
}

class BillingState {
  const BillingState({
    required this.storeAvailable,
    this.monthlyProduct,
    this.yearlyProduct,
    this.businessProduct,
    this.monthlyProductNotFound = false,
    this.yearlyProductNotFound = false,
    this.businessProductNotFound = false,
    this.errorMessage,
    this.isPurchasePending = false,
    this.isRestoring = false,
    this.feedback,
  });

  const BillingState.initial() : this(storeAvailable: false);

  static const Object _sentinel = Object();

  final bool storeAvailable;
  final ProductDetails? monthlyProduct;
  final ProductDetails? yearlyProduct;
  final ProductDetails? businessProduct;
  final bool monthlyProductNotFound;
  final bool yearlyProductNotFound;
  final bool businessProductNotFound;
  final String? errorMessage;
  final bool isPurchasePending;
  final bool isRestoring;
  final BillingFeedback? feedback;

  bool get canPurchase =>
      (canPurchaseMonthly || canPurchaseYearly || canPurchaseBusiness);

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

  bool get canPurchaseBusiness =>
      storeAvailable &&
      businessProduct != null &&
      !isPurchasePending &&
      !isRestoring;

  bool get canRestore => storeAvailable && !isPurchasePending && !isRestoring;

  BillingState copyWith({
    bool? storeAvailable,
    ProductDetails? monthlyProduct,
    ProductDetails? yearlyProduct,
    ProductDetails? businessProduct,
    bool? monthlyProductNotFound,
    bool? yearlyProductNotFound,
    bool? businessProductNotFound,
    Object? errorMessage = _sentinel,
    bool? isPurchasePending,
    bool? isRestoring,
    Object? feedback = _sentinel,
  }) {
    return BillingState(
      storeAvailable: storeAvailable ?? this.storeAvailable,
      monthlyProduct: monthlyProduct ?? this.monthlyProduct,
      yearlyProduct: yearlyProduct ?? this.yearlyProduct,
      businessProduct: businessProduct ?? this.businessProduct,
      monthlyProductNotFound:
          monthlyProductNotFound ?? this.monthlyProductNotFound,
      yearlyProductNotFound:
          yearlyProductNotFound ?? this.yearlyProductNotFound,
      businessProductNotFound:
          businessProductNotFound ?? this.businessProductNotFound,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      isPurchasePending: isPurchasePending ?? this.isPurchasePending,
      isRestoring: isRestoring ?? this.isRestoring,
      feedback: identical(feedback, _sentinel)
          ? this.feedback
          : feedback as BillingFeedback?,
    );
  }
}

enum _BillingAction { none, purchase, restore }

class BillingController extends AsyncNotifier<BillingState> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  _BillingAction _currentAction = _BillingAction.none;
  int _feedbackCounter = 0;

  @override
  Future<BillingState> build() async {
    final billingService = ref.read(billingServiceProvider);

    _purchaseSubscription ??= billingService.purchaseStream.listen((
      purchases,
    ) async {
      await _handlePurchaseUpdates(purchases);
    }, onError: _handlePurchaseStreamError);

    ref.onDispose(() async {
      await _purchaseSubscription?.cancel();
      _purchaseSubscription = null;
    });

    try {
      final available = await billingService.isAvailable();
      if (!available) {
        return const BillingState(
          storeAvailable: false,
          errorMessage: 'Store is currently unavailable.',
        );
      }

      final products = await billingService.loadProducts(
        BillingServiceInterface.allProductIds,
      );

      ProductDetails? monthly;
      ProductDetails? yearly;
      ProductDetails? business;
      bool monthlyNotFound = true;
      bool yearlyNotFound = true;
      bool businessNotFound = true;

      for (final p in products) {
        if (p.id == BillingServiceInterface.androidProMonthlyId ||
            p.id == BillingServiceInterface.iosProId) {
          monthly = p;
          monthlyNotFound = false;
        }
        if (p.id == BillingServiceInterface.androidProYearlyId) {
          yearly = p;
          yearlyNotFound = false;
        }
        if (BillingServiceInterface.isBusinessProduct(p.id)) {
          business ??= p;
          businessNotFound = false;
        }
      }

      return BillingState(
        storeAvailable: true,
        monthlyProduct: monthly,
        yearlyProduct: yearly,
        businessProduct: business,
        monthlyProductNotFound: monthlyNotFound,
        yearlyProductNotFound:
            yearlyNotFound &&
            BillingServiceInterface.allProductIds.contains(
              BillingServiceInterface.androidProYearlyId,
            ),
        businessProductNotFound: businessNotFound,
      );
    } catch (e) {
      return BillingState(
        storeAvailable: false,
        errorMessage: 'Unable to connect to the store right now: $e',
      );
    }
  }

  Future<void> purchaseMonthlyPro() async {
    final current = state.valueOrNull;
    if (current == null || !current.canPurchaseMonthly) return;
    await _purchasePro(current.monthlyProduct!, fallbackState: current);
  }

  Future<void> purchaseYearlyPro() async {
    final current = state.valueOrNull;
    if (current == null || !current.canPurchaseYearly) return;
    await _purchasePro(current.yearlyProduct!, fallbackState: current);
  }

  Future<void> purchaseBusiness() async {
    final current = state.valueOrNull;
    if (current == null || !current.canPurchaseBusiness) return;
    await _purchasePro(current.businessProduct!, fallbackState: current);
  }

  Future<void> _purchasePro(
    ProductDetails product, {
    required BillingState fallbackState,
  }) async {
    _currentAction = _BillingAction.purchase;
    state = AsyncValue.data(
      fallbackState.copyWith(isPurchasePending: true, feedback: null),
    );

    try {
      final started = await ref.read(billingServiceProvider).purchase(product);
      if (!started) {
        _currentAction = _BillingAction.none;
        _emitFeedback(
          state.valueOrNull ?? fallbackState,
          type: BillingFeedbackType.purchaseCancelled,
          message: 'Purchase cancelled',
          isPurchasePending: false,
        );
      }
    } catch (_) {
      _currentAction = _BillingAction.none;
      _emitFeedback(
        state.valueOrNull ?? fallbackState,
        type: BillingFeedbackType.purchaseCancelled,
        message: 'Purchase cancelled',
        isPurchasePending: false,
      );
    }
  }

  Future<void> restorePurchases() async {
    final current = state.valueOrNull;
    if (current == null || !current.canRestore) return;

    _currentAction = _BillingAction.restore;
    state = AsyncValue.data(
      current.copyWith(isRestoring: true, feedback: null),
    );

    try {
      await ref.read(billingServiceProvider).restorePurchases();
      final restoredPlan = await _syncPlanFromStore();
      _currentAction = _BillingAction.none;

      final latest = state.valueOrNull ?? current;
      if (restoredPlan != null && restoredPlan != InvoiceFlowPlan.free) {
        _emitFeedback(
          latest,
          type: BillingFeedbackType.restoreSuccess,
          message: 'Purchases restored.',
          isRestoring: false,
        );
        return;
      }

      _emitFeedback(
        latest,
        type: BillingFeedbackType.restoreNotFound,
        message: 'No purchases to restore.',
        isRestoring: false,
      );
    } catch (_) {
      _currentAction = _BillingAction.none;
      _emitFeedback(
        state.valueOrNull ?? current,
        type: BillingFeedbackType.restoreFailed,
        message: 'Unable to restore purchases right now.',
        isRestoring: false,
      );
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!BillingServiceInterface.isPaidTierProduct(purchase.productID)) {
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
            await _handleSuccessfulPurchase(purchase.productID);
          case PurchaseStatus.error:
            _handleErrorPurchase();
          case PurchaseStatus.canceled:
            await _handleCancelledPurchase();
        }
      } finally {
        if (purchase.pendingCompletePurchase) {
          await ref.read(billingServiceProvider).completePurchase(purchase);
        }
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(String productId) async {
    final purchasedPlan = BillingServiceInterface.isBusinessProduct(productId)
        ? InvoiceFlowPlan.business
        : InvoiceFlowPlan.pro;
    await _persistPlanTier(purchasedPlan);

    final current = state.valueOrNull ?? const BillingState.initial();
    final next = current.copyWith(isPurchasePending: false, isRestoring: false);

    if (_currentAction == _BillingAction.purchase) {
      _currentAction = _BillingAction.none;
      _emitFeedback(
        next,
        type: BillingFeedbackType.purchaseSuccess,
        message: 'Pro features are now active.',
      );
      return;
    }

    state = AsyncValue.data(next);
  }

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
        type: BillingFeedbackType.purchaseCancelled,
        message: 'Purchase cancelled',
        isPurchasePending: false,
      );
      return;
    }

    state = AsyncValue.data(
      current.copyWith(isPurchasePending: false, isRestoring: false),
    );
  }

  Future<void> _handleCancelledPurchase() async {
    final current = state.valueOrNull;
    if (current == null) {
      _currentAction = _BillingAction.none;
      return;
    }

    final action = _currentAction;
    _currentAction = _BillingAction.none;

    final subscriptionState = ref
        .read(subscriptionControllerProvider)
        .valueOrNull;
    if (subscriptionState?.isPro == true) {
      await _persistPlan(isPro: false);
    }

    if (action == _BillingAction.purchase) {
      _emitFeedback(
        current,
        type: BillingFeedbackType.purchaseCancelled,
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
        type: BillingFeedbackType.purchaseCancelled,
        message: 'Purchase cancelled',
        isPurchasePending: false,
      );
      return;
    }

    if (action == _BillingAction.restore) {
      _emitFeedback(
        current,
        type: BillingFeedbackType.restoreFailed,
        message: 'Unable to restore purchases right now.',
        isRestoring: false,
      );
      return;
    }

    state = AsyncValue.data(
      current.copyWith(isPurchasePending: false, isRestoring: false),
    );
  }

  Future<InvoiceFlowPlan?> _syncPlanFromStore() async {
    final syncedPlan = await ref
        .read(billingServiceProvider)
        .syncOwnedPlanState(BillingServiceInterface.allProductIds);
    if (syncedPlan == null) return null;

    await _persistPlanTier(syncedPlan);
    return syncedPlan;
  }

  Future<void> _persistPlan({required bool isPro}) async {
    await ref.read(subscriptionLocalDatasourceProvider).savePlan(isPro: isPro);
    ref.invalidate(subscriptionControllerProvider);
  }

  Future<void> _persistPlanTier(InvoiceFlowPlan plan) async {
    await ref.read(subscriptionLocalDatasourceProvider).savePlanTier(plan);
    ref.invalidate(subscriptionControllerProvider);
  }

  void _emitFeedback(
    BillingState base, {
    required BillingFeedbackType type,
    required String message,
    bool? isPurchasePending,
    bool? isRestoring,
  }) {
    _feedbackCounter += 1;
    state = AsyncValue.data(
      base.copyWith(
        isPurchasePending: isPurchasePending,
        isRestoring: isRestoring,
        feedback: BillingFeedback(
          id: _feedbackCounter,
          type: type,
          message: message,
        ),
      ),
    );
  }
}
