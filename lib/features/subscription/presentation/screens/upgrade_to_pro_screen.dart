import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/premium_frosted_card.dart';
import '../../../../shared/components/premium_primary_button.dart';
import '../../domain/entities/subscription_state.dart';
import '../controllers/billing_controller.dart';
import '../controllers/subscription_controller.dart';
import '../../../../data/services/analytics_service.dart';
import 'package:flutter/foundation.dart';

enum _UpgradePlan { monthly, yearly }

class UpgradeToProScreen extends ConsumerStatefulWidget {
  const UpgradeToProScreen({super.key});

  @override
  ConsumerState<UpgradeToProScreen> createState() => _UpgradeToProScreenState();
}

class _UpgradeToProScreenState extends ConsumerState<UpgradeToProScreen>
    with SingleTickerProviderStateMixin {
  _UpgradePlan _selectedPlan = _UpgradePlan.yearly;
  bool _isShowingSuccessState = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Log to Analytics
    AnalyticsService.instance.logUpgradePromptShown('generic');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<BillingState>>(billingControllerProvider, (
      previous,
      next,
    ) {
      final previousFeedbackId = previous?.valueOrNull?.feedback?.id;
      final feedback = next.valueOrNull?.feedback;
      if (feedback == null || feedback.id == previousFeedbackId || !mounted) {
        return;
      }

      unawaited(_handleBillingFeedback(feedback));
    });

    final theme = Theme.of(context);
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
    final usage = ref.watch(subscriptionUsageProvider);
    final billingAsync = ref.watch(billingControllerProvider);
    final billing =
        billingAsync.valueOrNull ?? const BillingState.initial();
    final selectedPlan = _effectiveSelectedPlan(billing);
    final monthlyPriceLabel = billing.monthlyProduct?.price ?? r'$4.91 / month';
    final yearlyPriceLabel = billing.yearlyProduct?.price ?? r'$39.99 / year';
    final canPurchase = switch (selectedPlan) {
      _UpgradePlan.monthly => billing.canPurchaseMonthly,
      _UpgradePlan.yearly => billing.canPurchaseYearly,
    };
    final ctaLabel = subscription.isPro ? 'Pro Active' : 'Upgrade Now';
    final ctaAction = subscription.isPro || !canPurchase
        ? null
        : () => _startPurchase(selectedPlan);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Upgrade to Pro')),
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable content ──
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──
                      PremiumFrostedCard(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.24,
                                  ),
                                ),
                              ),
                              child: Text(
                                'UPGRADE TO PRO',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: spacingMD),
                            Text(
                              'Upgrade to Pro',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: spacingSM),
                            Text(
                              'Unlock unlimited invoices, remove branding, and get paid faster.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: spacingMD),

                      // ── Pricing cards side-by-side ──
                      Row(
                        children: [
                          Expanded(
                            child: _PlanCard(
                              title: 'Monthly',
                              priceLabel: monthlyPriceLabel,
                              subtitle: 'Flexible',
                              isSelected: selectedPlan == _UpgradePlan.monthly,
                              onTap: () => setState(
                                () => _selectedPlan = _UpgradePlan.monthly,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PlanCard(
                              title: 'Yearly',
                              priceLabel: yearlyPriceLabel,
                              subtitle: 'Best Value',
                              badgeLabel: 'Save 33%',
                              isHighlighted: true,
                              isSelected: selectedPlan == _UpgradePlan.yearly,
                              onTap: () => setState(
                                () => _selectedPlan = _UpgradePlan.yearly,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: spacingXS),

                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: spacingSM,
                          ),
                          child: Text(
                            _billingCaption(
                              billingAsync,
                              billing,
                              selectedPlan,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      const SizedBox(height: spacingSM),

                      // ── Features ──
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _BenefitRow(text: 'Unlimited invoices'),
                            SizedBox(height: spacingSM + 2),
                            _BenefitRow(text: 'Remove watermark'),
                            SizedBox(height: spacingSM + 2),
                            _BenefitRow(text: 'Add your logo'),
                            SizedBox(height: spacingSM + 2),
                            _BenefitRow(text: 'Smart reminders'),
                            SizedBox(height: spacingSM + 2),
                            _BenefitRow(text: 'Professional branding'),
                            SizedBox(height: spacingSM + 2),
                            _BenefitRow(text: 'Priority support'),
                          ],
                        ),
                      ),

                      const SizedBox(height: spacingMD),

                      // ── Trust section ──
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TrustChip(text: 'Secure ${defaultTargetPlatform == TargetPlatform.android ? 'Google Play' : 'App Store'} billing'),
                          _TrustChip(text: 'Cancel anytime'),
                          _TrustChip(text: 'No hidden fees'),
                        ],
                      ),

                      const SizedBox(height: spacingMD),

                      // ── Usage ──
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your current usage',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: spacingSM + 2),
                            Text(
                              _usageHeadline(usage),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: spacingXS),
                            Text(
                              _usageSupportCopy(usage),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: spacingMD - 2),
                            _UsageRow(
                              label: 'Clients',
                              value: usage.clientUsageLabel,
                            ),
                            const SizedBox(height: spacingSM),
                            _UsageRow(
                              label: 'Invoices',
                              value: usage.invoiceUsageLabel,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 100,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Fixed bottom CTA ──
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary.withValues(alpha: 0.95),
                  border: Border(
                    top: BorderSide(color: AppColors.glassBorder, width: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: PremiumPrimaryButton(
                        label: ctaLabel,
                        isLoading: billing.isPurchasePending,
                        onPressed: ctaAction,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        'Continue with Free',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    if (billing.canRestore || billing.isRestoring)
                      TextButton(
                        onPressed: billing.canRestore
                            ? () => ref
                                  .read(billingControllerProvider.notifier)
                                  .restorePurchases()
                            : null,
                        child: Text(
                          billing.isRestoring
                              ? 'Restoring purchases...'
                              : 'Restore purchases',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _UpgradePlan _effectiveSelectedPlan(BillingState billing) {
    if (_selectedPlan == _UpgradePlan.yearly &&
        billing.yearlyProduct == null &&
        billing.monthlyProduct != null) {
      return _UpgradePlan.monthly;
    }

    return _selectedPlan;
  }

  Future<void> _startPurchase(_UpgradePlan plan) async {
    switch (plan) {
      case _UpgradePlan.monthly:
        AnalyticsService.instance.logUpgradeTapped('monthly');
        await ref
            .read(billingControllerProvider.notifier)
            .purchaseMonthlyPro();
      case _UpgradePlan.yearly:
        AnalyticsService.instance.logUpgradeTapped('yearly');
        await ref
            .read(billingControllerProvider.notifier)
            .purchaseYearlyPro();
    }
  }

  Future<void> _handleBillingFeedback(BillingFeedback feedback) async {
    if (!mounted) {
      return;
    }

    final isSuccess =
        feedback.type == BillingFeedbackType.purchaseSuccess ||
        feedback.type == BillingFeedbackType.restoreSuccess;

    if (!isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(feedback.message)));
      return;
    }

    if (_isShowingSuccessState) {
      return;
    }

    _isShowingSuccessState = true;
    await _showSuccessDialog();
    _isShowingSuccessState = false;

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumFrostedCard(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.28),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You\'re now Pro 🎉',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Unlimited invoices, premium branding, and full access are live right away.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                const _BenefitRow(text: 'All restrictions removed immediately'),
                const SizedBox(height: 10),
                const _BenefitRow(text: 'Watermark-free exports are unlocked'),
                const SizedBox(height: 10),
                const _BenefitRow(text: 'Custom branding is ready to use'),
                const SizedBox(height: 18),
                PremiumPrimaryButton(
                  label: 'Continue',
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _billingCaption(
    AsyncValue<BillingState> billingAsync,
    BillingState billing,
    _UpgradePlan selectedPlan,
  ) {
    final storeName = defaultTargetPlatform == TargetPlatform.android ? 'Google Play' : 'App Store';
    
    if (billingAsync.isLoading) {
      return 'Connecting to $storeName Billing...';
    }

    if (!billing.storeAvailable) {
      return '$storeName Billing is unavailable on this device.';
    }

    if (billing.monthlyProduct == null && billing.yearlyProduct == null) {
      return 'The Pro plans are not available in $storeName right now.';
    }

    if (selectedPlan == _UpgradePlan.yearly && billing.yearlyProduct == null) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'Standard billing live in $storeName. Yearly discount not available.';
      }
      return 'Yearly billing is not live in $storeName yet. Monthly is still available.';
    }

    if (selectedPlan == _UpgradePlan.monthly &&
        billing.monthlyProduct == null) {
      return 'Monthly billing is not live in $storeName yet. Yearly is available.';
    }

    if (billing.errorMessage != null && billing.errorMessage!.isNotEmpty) {
      return billing.errorMessage!;
    }

    return 'Secure payment via $storeName. Cancel anytime.';
  }

  String _usageHeadline(SubscriptionUsage usage) {
    if (usage.remainingMonthlyInvoiceSlots <= 0) {
      return 'You\'ve reached your free limit';
    }

    if (usage.remainingMonthlyInvoiceSlots == 1) {
      return '1 invoice left this month';
    }

    return '${usage.monthlyInvoiceCount}/${SubscriptionState.freeMonthlyInvoiceLimit} invoices used';
  }

  String _usageSupportCopy(SubscriptionUsage usage) {
    if (usage.remainingMonthlyInvoiceSlots <= 0) {
      return 'Upgrade to continue without limits.';
    }

    if (usage.remainingMonthlyInvoiceSlots == 1) {
      return 'Unlock full access instantly before you hit the limit.';
    }

    return 'Free includes up to 5 clients and 5 invoices each month. Pro removes every cap right away.';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.priceLabel,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.badgeLabel,
    this.isHighlighted = false,
  });

  final String title;
  final String priceLabel;
  final String subtitle;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback onTap;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isSelected
        ? AppColors.accent.withValues(alpha: 0.50)
        : isHighlighted
        ? AppColors.accent.withValues(alpha: 0.22)
        : AppColors.glassBorder;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected && isHighlighted ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (badgeLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeLabel!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                priceLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected ? AppColors.accent : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
