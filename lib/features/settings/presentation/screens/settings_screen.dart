import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/services/analytics_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/providers/firestore_sync_provider.dart';
import '../../../../shared/components/app_scaffold.dart';
import '../../../../core/services/app_feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/components/premium_primary_button.dart';
import '../../../../shared/widgets/app_failure_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/app_preferences.dart';
import '../../domain/entities/profile.dart';
import '../controllers/app_preferences_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/app_lock_gate.dart';
import '../widgets/pin_editor_sheet.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../controllers/expense_currency_controller.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _headerTapCount = 0;
  DateTime? _lastHeaderTapTime;
  bool _developerOptionsVisible = false;

  void _onHeaderTap() {
    final now = DateTime.now();
    final last = _lastHeaderTapTime;
    if (last == null || now.difference(last).inSeconds > 3) {
      _headerTapCount = 1;
    } else {
      _headerTapCount++;
    }
    _lastHeaderTapTime = now;
    if (_headerTapCount >= 7) {
      setState(() {
        _developerOptionsVisible = true;
        _headerTapCount = 0;
      });
    }
  }

  static const List<String> _currencyOptions = <String>[
    'USD',
    'AED',
    'EUR',
    'GBP',
    'INR',
  ];

  Future<void> _openProfileEditor() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
    );
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      AppFeedbackService.showSnackBar('Unable to open that link right now.');
    }
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: const <String, String>{
        'subject': 'Invoice Flow support',
      },
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      AppFeedbackService.showSnackBar(
        'Unable to open your email app right now.',
      );
    }
  }

  Future<void> _toggleAppLock(AppPreferences preferences, bool enabled) async {
    final preferencesController = ref.read(
      appPreferencesControllerProvider.notifier,
    );
    final appLockSession = ref.read(appLockSessionProvider.notifier);

    if (!enabled) {
      await preferencesController.patch(
        (current) => current.copyWith(appLockEnabled: false),
      );
      appLockSession.state = false;
      return;
    }

    var nextPin = preferences.appLockPin;
    if (!preferences.hasPin) {
      final createdPin = await showPinEditorSheet(
        context,
        title: 'Set App Lock PIN',
        submitLabel: 'Save PIN',
      );
      if (!mounted || createdPin == null) {
        return;
      }
      nextPin = createdPin;
    }

    await preferencesController.patch(
      (current) => current.copyWith(appLockEnabled: true, appLockPin: nextPin),
    );
    appLockSession.state = true;
    if (mounted) {
      AppFeedbackService.showSnackBar('App lock is enabled.');
    }
  }

  Future<void> _changePin(AppPreferences preferences) async {
    final preferencesController = ref.read(
      appPreferencesControllerProvider.notifier,
    );
    final appLockSession = ref.read(appLockSessionProvider.notifier);

    final nextPin = await showPinEditorSheet(
      context,
      title: preferences.hasPin ? 'Change PIN' : 'Set PIN',
      submitLabel: 'Save PIN',
    );
    if (!mounted || nextPin == null) {
      return;
    }

    await preferencesController.patch(
      (current) => current.copyWith(appLockPin: nextPin),
    );
    appLockSession.state = true;
    if (mounted) {
      AppFeedbackService.showSnackBar('PIN updated.');
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and ALL data '
          '(invoices, clients, expenses). This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _performDelete();
  }

  Future<void> _performDelete() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Deleting account...'),
          ],
        ),
      ),
    );

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await ref.read(firestoreSyncServiceProvider).deleteAccount(userId);

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      ref.read(authControllerProvider.notifier).logout();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading dialog

      final isReauthError = e.toString().contains('requires-recent-login');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isReauthError
                ? 'For security, please sign out and sign back in, '
                    'then try deleting again.'
                : 'Failed to delete account: $e',
          ),
          duration: Duration(seconds: isReauthError ? 5 : 3),
        ),
      );
    }
  }

  String _formatTaxPercent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  double _sanitizeTaxPercent(String rawValue) {
    final parsed = double.tryParse(rawValue.trim());
    if (parsed == null) {
      return 0;
    }
    return parsed.clamp(0.0, 100.0).toDouble();
  }

  String _sanitizeInvoicePrefix(String rawValue) {
    final sanitized = rawValue.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9-]'),
      '',
    );
    return sanitized.isEmpty ? 'INV' : sanitized;
  }

  Future<T?> _showSelectionSettingSheet<T>({
    required String title,
    required String subtitle,
    required T currentValue,
    required List<_SettingOption<T>> options,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 16;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < options.length; index++) ...[
                  _SettingSheetOptionRow(
                    label: options[index].label,
                    description: options[index].description,
                    selected: options[index].value == currentValue,
                    onTap: () {
                      Navigator.of(context).pop(options[index].value);
                    },
                  ),
                  if (index != options.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showTextSettingSheet({
    required String title,
    required String subtitle,
    required String initialValue,
    required String hintText,
    required TextInputType keyboardType,
    required List<TextInputFormatter> inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? suffixText,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _TextSettingSheet(
          title: title,
          subtitle: subtitle,
          initialValue: initialValue,
          hintText: hintText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          suffixText: suffixText,
        );
      },
    );
  }

  Future<void> _editDefaultCurrency(AppPreferences preferences) async {
    final nextValue = await _showSelectionSettingSheet<String>(
      title: 'Default Currency',
      subtitle: 'Used for all invoices',
      currentValue: preferences.defaultCurrency,
      options: _currencyOptions
          .map(
            (currency) =>
                _SettingOption<String>(value: currency, label: currency),
          )
          .toList(growable: false),
    );

    if (!mounted ||
        nextValue == null ||
        nextValue == preferences.defaultCurrency) {
      return;
    }

    await _togglePreference(
      (current) => current.copyWith(defaultCurrency: nextValue),
    );
  }

  Future<void> _editExpenseCurrency(String currentCurrency) async {
    final nextValue = await _showSelectionSettingSheet<String>(
      title: 'Expense Currency',
      subtitle: 'Used for expense tracking',
      currentValue: currentCurrency,
      options: _currencyOptions
          .map(
            (currency) =>
                _SettingOption<String>(value: currency, label: currency),
          )
          .toList(growable: false),
    );

    if (!mounted || nextValue == null || nextValue == currentCurrency) {
      return;
    }

    await ref
        .read(expenseCurrencyControllerProvider.notifier)
        .setCurrency(nextValue);
  }

  Future<void> _editDefaultTaxPercent(AppPreferences preferences) async {
    final rawValue = await _showTextSettingSheet(
      title: 'Default Tax %',
      subtitle: 'Automatically applied to totals',
      initialValue: _formatTaxPercent(preferences.defaultTaxPercent),
      hintText: '0',
      suffixText: '%',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    );

    if (!mounted || rawValue == null) {
      return;
    }

    final sanitized = _sanitizeTaxPercent(rawValue);
    if ((preferences.defaultTaxPercent - sanitized).abs() < 0.0001) {
      return;
    }

    await _togglePreference(
      (current) => current.copyWith(defaultTaxPercent: sanitized),
    );
  }

  Future<void> _editInvoicePrefix(AppPreferences preferences) async {
    final rawValue = await _showTextSettingSheet(
      title: 'Invoice Prefix',
      subtitle: 'Used for invoice numbering',
      initialValue: preferences.invoicePrefix,
      hintText: 'INV',
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
      ],
    );

    if (!mounted || rawValue == null) {
      return;
    }

    final sanitized = _sanitizeInvoicePrefix(rawValue);
    if (sanitized == preferences.invoicePrefix) {
      return;
    }

    await _togglePreference(
      (current) => current.copyWith(invoicePrefix: sanitized),
    );
  }

  Future<void> _editNextInvoiceNumber(AppPreferences preferences) async {
    final rawValue = await _showTextSettingSheet(
      title: 'Next Invoice Number',
      subtitle: 'The sequential number for your next invoice',
      initialValue: preferences.nextInvoiceNumber.toString(),
      hintText: '1',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );

    if (!mounted || rawValue == null) {
      return;
    }

    final sanitized = int.tryParse(rawValue.trim()) ?? 1;
    if (sanitized == preferences.nextInvoiceNumber) {
      return;
    }

    await _togglePreference(
      (current) => current.copyWith(nextInvoiceNumber: sanitized),
    );
  }

  Future<void> _editPaymentTerms(AppPreferences preferences) async {
    final nextValue = await _showSelectionSettingSheet<PaymentTermsOption>(
      title: 'Payment Terms',
      subtitle: 'Default due date calculation',
      currentValue: preferences.paymentTerms,
      options: PaymentTermsOption.values
          .map(
            (terms) => _SettingOption<PaymentTermsOption>(
              value: terms,
              label: terms.label,
              description: 'Sets the due date ${terms.days} days after issue.',
            ),
          )
          .toList(growable: false),
    );

    if (!mounted ||
        nextValue == null ||
        nextValue == preferences.paymentTerms) {
      return;
    }

    await _togglePreference(
      (current) => current.copyWith(paymentTerms: nextValue),
    );
  }

  Future<void> _togglePreference(
    AppPreferences Function(AppPreferences current) update,
  ) {
    return ref.read(appPreferencesControllerProvider.notifier).patch(update);
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(settingsControllerProvider);
    final preferencesState = ref.watch(appPreferencesControllerProvider);
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
    final usage = ref.watch(subscriptionUsageProvider);
    final expenseCurrency = ref.watch(expenseCurrencyControllerProvider);

    final profileError = profileState.asError;
    final preferencesError = preferencesState.asError;
    if (profileError != null || preferencesError != null) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: AppFailureState(
          message:
              profileError?.error.toString() ??
              preferencesError?.error.toString() ??
              'Unable to load settings.',
          onRetry: () {
            ref.invalidate(settingsControllerProvider);
            ref.invalidate(appPreferencesControllerProvider);
          },
        ),
      );
    }

    final profile = profileState.valueOrNull;
    final preferences = preferencesState.valueOrNull;

    if (profile == null || preferences == null) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 380 ? 16.0 : 20.0;
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight + 80;

    return AppScaffold(
      extendBody: true,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            bottomPadding,
          ),
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onHeaderTap,
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            _ProfileSectionCard(profile: profile, onEdit: _openProfileEditor),
            const SizedBox(height: 20),
            _PlanSectionCard(
              subscription: subscription,
              usage: usage,
              onUpgrade: subscription.isPro
                  ? null
                  : () {
                      AnalyticsService.instance.logUpgradeTapped(
                        'settings_plan_card',
                      );
                      const UpgradeToProRoute().push(context);
                    },
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Notifications',
              children: [
                _SwitchRow(
                  title: 'Push notifications',
                  subtitle: 'Schedule local due reminders on this device.',
                  value: preferences.pushNotificationsEnabled,
                  enabled: subscription.isPro,
                  onChanged: subscription.isPro
                      ? (value) => _togglePreference(
                          (current) =>
                              current.copyWith(pushNotificationsEnabled: value),
                        )
                      : null,
                ),
                _SwitchRow(
                  title: 'WhatsApp reminders',
                  subtitle: 'Allow reminder launches through WhatsApp.',
                  value: preferences.whatsAppRemindersEnabled,
                  enabled: subscription.isPro,
                  onChanged: subscription.isPro
                      ? (value) => _togglePreference(
                          (current) =>
                              current.copyWith(whatsAppRemindersEnabled: value),
                        )
                      : null,
                ),
                _SwitchRow(
                  title: 'SMS reminders',
                  subtitle: 'Allow reminder launches through SMS.',
                  value: preferences.smsRemindersEnabled,
                  enabled: subscription.isPro,
                  onChanged: subscription.isPro
                      ? (value) => _togglePreference(
                          (current) =>
                              current.copyWith(smsRemindersEnabled: value),
                        )
                      : null,
                ),
                _SwitchRow(
                  title: '24h before',
                  subtitle: 'Schedule a reminder one day before the due date.',
                  value: preferences.remind24HoursBefore,
                  enabled:
                      subscription.isPro &&
                      preferences.pushNotificationsEnabled,
                  onChanged:
                      (subscription.isPro &&
                          preferences.pushNotificationsEnabled)
                      ? (value) => _togglePreference(
                          (current) =>
                              current.copyWith(remind24HoursBefore: value),
                        )
                      : null,
                ),
                _SwitchRow(
                  title: '3h before',
                  subtitle: 'Schedule a final heads-up three hours before due.',
                  value: preferences.remind3HoursBefore,
                  enabled:
                      subscription.isPro &&
                      preferences.pushNotificationsEnabled,
                  onChanged:
                      (subscription.isPro &&
                          preferences.pushNotificationsEnabled)
                      ? (value) => _togglePreference(
                          (current) =>
                              current.copyWith(remind3HoursBefore: value),
                        )
                      : null,
                ),
                _SwitchRow(
                  title: 'On due date',
                  subtitle: 'Notify when the invoice becomes due.',
                  value: preferences.remindOnDueDate,
                  enabled:
                      subscription.isPro &&
                      preferences.pushNotificationsEnabled,
                  onChanged:
                      (subscription.isPro &&
                          preferences.pushNotificationsEnabled)
                      ? (value) => _togglePreference(
                          (current) => current.copyWith(remindOnDueDate: value),
                        )
                      : null,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Security',
              children: [
                _SwitchRow(
                  title: 'App lock',
                  subtitle: preferences.appLockEnabled
                      ? 'PIN lock is active for app launch and return.'
                      : 'Protect the app with a PIN.',
                  value: preferences.appLockEnabled,
                  onChanged: (value) => _toggleAppLock(preferences, value),
                ),
                _ActionRow(
                  title: 'Change PIN',
                  subtitle: preferences.hasPin
                      ? 'Update your current app lock PIN.'
                      : 'Set a 4 to 6 digit PIN first.',
                  icon: Icons.lock_outline,
                  onTap: () => _changePin(preferences),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Invoice Settings',
              children: [
                _SettingValueRow(
                  title: 'Invoice Currency',
                  subtitle: 'Used for all invoices',
                  value: _currencyOptions.contains(preferences.defaultCurrency)
                      ? preferences.defaultCurrency
                      : _currencyOptions.first,
                  trailingIcon: Icons.keyboard_arrow_down_rounded,
                  onTap: () => _editDefaultCurrency(preferences),
                ),
                _SettingValueRow(
                  title: 'Expense Currency',
                  subtitle: 'Used for expense tracking',
                  value: _currencyOptions.contains(expenseCurrency)
                      ? expenseCurrency
                      : _currencyOptions.first,
                  trailingIcon: Icons.keyboard_arrow_down_rounded,
                  onTap: () => _editExpenseCurrency(expenseCurrency),
                ),
                _SettingValueRow(
                  title: 'Default Tax %',
                  subtitle: 'Automatically applied to totals',
                  value: '${_formatTaxPercent(preferences.defaultTaxPercent)}%',
                  trailingIcon: Icons.edit_outlined,
                  onTap: () => _editDefaultTaxPercent(preferences),
                ),
                _SettingValueRow(
                  title: 'Invoice Prefix',
                  subtitle: 'Used for invoice numbering',
                  value: preferences.invoicePrefix,
                  trailingIcon: Icons.edit_outlined,
                  onTap: () => _editInvoicePrefix(preferences),
                ),
                _SettingValueRow(
                  title: 'Next Number',
                  subtitle: 'Sequential counter for next invoice',
                  value: preferences.nextInvoiceNumber.toString(),
                  trailingIcon: Icons.edit_outlined,
                  onTap: () => _editNextInvoiceNumber(preferences),
                ),
                _SettingValueRow(
                  title: 'Payment Terms',
                  subtitle: 'Default due date calculation',
                  value: preferences.paymentTerms.label,
                  trailingIcon: Icons.keyboard_arrow_down_rounded,
                  onTap: () => _editPaymentTerms(preferences),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Automation',
              children: [
                _SwitchRow(
                  title: 'One-tap invoice',
                  subtitle: 'Use assisted invoice creation from quick actions.',
                  value: preferences.oneTapInvoiceEnabled,
                  onChanged: (value) => _togglePreference(
                    (current) => current.copyWith(oneTapInvoiceEnabled: value),
                  ),
                ),
                _SwitchRow(
                  title: 'Smart prediction',
                  subtitle: 'Allow the app to prefill invoice suggestions.',
                  value: preferences.smartPredictionEnabled,
                  onChanged: (value) => _togglePreference(
                    (current) =>
                        current.copyWith(smartPredictionEnabled: value),
                  ),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Collaboration',
              children: [
                _ActionRow(
                  title: 'Team Members',
                  subtitle: 'Business Plan',
                  icon: Icons.group_outlined,
                  onTap: () => const TeamMembersRoute().push(context),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Legal',
              children: [
                _ActionRow(
                  title: 'Privacy Policy',
                  subtitle: 'Open the privacy policy in your browser.',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => _openExternalLink(AppConstants.privacyPolicyUrl),
                ),
                _ActionRow(
                  title: 'Terms of Service',
                  subtitle: 'Open the terms of service in your browser.',
                  icon: Icons.description_outlined,
                  onTap: () =>
                      _openExternalLink(AppConstants.termsOfServiceUrl),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'About',
              children: [
                _InfoRow(label: 'App', value: AppConstants.aboutAppName),
                _InfoRow(label: 'Version', value: AppConstants.appVersion),
                _ActionRow(
                  title: 'Support email',
                  subtitle: AppConstants.supportEmail,
                  icon: Icons.email_outlined,
                  onTap: _openSupportEmail,
                  isLast: true,
                ),
              ],
            ),
            if (_developerOptionsVisible) ...[
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Developer Options',
                children: [
                  _SwitchRow(
                    title: 'Debug Mode',
                    subtitle: 'Bypass subscription checks (testing only)',
                    value: ref.watch(debugModeProvider),
                    onChanged: (value) => ref
                        .read(subscriptionControllerProvider.notifier)
                        .setDebugMode(value),
                    isLast: true,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Logout',
              icon: Icons.logout,
              onPressed: () {
                ref.read(appLockSessionProvider.notifier).state = false;
                ref.read(authControllerProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text(
                  'Permanently delete your account and all data',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: _showDeleteConfirmation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.profile, required this.onEdit});

  final UserProfile profile;
  final VoidCallback onEdit;

  ({String value, bool isPlaceholder}) _valueOrPrompt(
    String value,
    String prompt,
  ) {
    final trimmed = value.trim();
    return (
      value: trimmed.isEmpty ? prompt : trimmed,
      isPlaceholder: trimmed.isEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = profile.name.trim().isEmpty
        ? 'Your Profile'
        : profile.name.trim();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _ProfileDetailRow(
            label: 'Name',
            info: _valueOrPrompt(profile.name, 'Add your name'),
          ),
          _ProfileDetailRow(
            label: 'Email',
            info: _valueOrPrompt(profile.email, 'Add your email'),
          ),
          _ProfileDetailRow(
            label: 'Business Name',
            info: _valueOrPrompt(
              profile.businessName,
              'Add your business name',
            ),
          ),
          _ProfileDetailRow(
            label: 'Phone',
            info: _valueOrPrompt(profile.phone, 'Add your phone number'),
          ),
          _ProfileDetailRow(
            label: 'Address',
            info: _valueOrPrompt(profile.address, 'Add your address'),
            isLast: true,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.cardBackground,
                side: const BorderSide(color: AppColors.glassBorder),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'Edit Profile',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSectionCard extends StatelessWidget {
  const _PlanSectionCard({
    required this.subscription,
    required this.usage,
    this.onUpgrade,
  });

  final SubscriptionState subscription;
  final SubscriptionUsage usage;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaidTier = subscription.isPro;
    final isBusiness = subscription.isBusiness;
    final title = isBusiness
        ? 'Business Plan'
        : (isPaidTier ? 'Pro Plan' : 'Free Plan');
    final badgeLabel = isPaidTier ? 'Active' : 'Current Plan';
    final clientUsage = isPaidTier
        ? '${usage.clientCount} / Unlimited'
        : '${usage.clientCount} / ${SubscriptionState.freeClientLimit}';
    final invoiceUsage = isPaidTier
        ? '${usage.monthlyInvoiceCount} / Unlimited'
        : '${usage.monthlyInvoiceCount} / ${SubscriptionState.freeMonthlyInvoiceLimit}';
    final highlights = isBusiness
        ? const <String>[
            'Everything in Pro',
            'Up to 3 users',
            'Shared workspace',
          ]
        : isPaidTier
        ? const <String>[
            'Unlimited clients',
            'Unlimited invoices',
            'No PDF watermark',
          ]
        : const <String>[
            '3 clients limit',
            '5 invoices/month',
            'PDF includes watermark',
          ];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final badge = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  badgeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );

              final titleText = Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              );

              if (constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleText, const SizedBox(height: 12), badge],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleText),
                  const SizedBox(width: 12),
                  badge,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < highlights.length; index++) ...[
            _PlanFeatureRow(text: highlights[index]),
            if (index != highlights.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          Text(
            isPaidTier ? 'Usage' : 'Usage this month',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _UsageStatRow(label: 'Clients', value: clientUsage),
          const SizedBox(height: 12),
          _UsageStatRow(label: 'Invoices', value: invoiceUsage),
          if (!isPaidTier && onUpgrade != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onUpgrade,
              child: Text(
                'Cloud backup: Upgrade to Pro',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            PremiumPrimaryButton(
              label: 'Upgrade to Pro',
              leading: const Icon(
                Icons.workspace_premium_outlined,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () async {
                onUpgrade!.call();
              },
            ),
          ] else if (isPaidTier) ...[
            const SizedBox(height: 16),
            Text(
              isBusiness
                  ? 'Invoice Flow Business is active on this device.'
                  : 'Invoice Flow Pro is active on this device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cloud backup: Active',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanFeatureRow extends StatelessWidget {
  const _PlanFeatureRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '•',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.label,
    required this.info,
    this.isLast = false,
  });

  final String label;
  final ({String value, bool isPlaceholder}) info;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlaceholder = info.isPlaceholder;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            info.value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isPlaceholder
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
              fontWeight: isPlaceholder ? FontWeight.w600 : FontWeight.w700,
              height: 1.3,
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}

class _UsageStatRow extends StatelessWidget {
  const _UsageStatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }
}

class _SettingRowText extends StatelessWidget {
  const _SettingRowText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SettingValueRow extends StatelessWidget {
  const _SettingValueRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.trailingIcon = Icons.keyboard_arrow_right_rounded,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;
  final IconData trailingIcon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SettingRowText(title: title, subtitle: subtitle),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      trailingIcon,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isLast) {
      return row;
    }

    return Column(children: [row, const SizedBox(height: 14)]);
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final row = Opacity(
      opacity: enabled ? 1 : 0.6,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: (enabled && onChanged != null) ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SettingRowText(title: title, subtitle: subtitle),
              ),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Switch.adaptive(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isLast) {
      return row;
    }

    return Column(children: [row, const SizedBox(height: 14)]);
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SettingRowText(title: title, subtitle: subtitle),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 24,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isLast) {
      return row;
    }

    return Column(children: [row, const SizedBox(height: 14)]);
  }
}

class _SettingOption<T> {
  const _SettingOption({
    required this.value,
    required this.label,
    this.description,
  });

  final T value;
  final String label;
  final String? description;
}

class _SettingSheetOptionRow extends StatelessWidget {
  const _SettingSheetOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.35)
                : AppColors.glassBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TextSettingSheet extends StatefulWidget {
  const _TextSettingSheet({
    required this.title,
    required this.subtitle,
    required this.initialValue,
    required this.hintText,
    required this.keyboardType,
    required this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.suffixText,
  });

  final String title;
  final String subtitle;
  final String initialValue;
  final String hintText;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final TextCapitalization textCapitalization;
  final String? suffixText;

  @override
  State<_TextSettingSheet> createState() => _TextSettingSheetState();
}

class _TextSettingSheetState extends State<_TextSettingSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration() {
    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color),
      );
    }

    return InputDecoration(
      hintText: widget.hintText,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      suffixText: widget.suffixText,
      suffixStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.glassBorder),
      enabledBorder: border(AppColors.glassBorder),
      focusedBorder: border(AppColors.accent.withValues(alpha: 0.45)),
    );
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 16;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + bottomPadding),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              textCapitalization: widget.textCapitalization,
              decoration: _inputDecoration(),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Save', icon: Icons.check, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
