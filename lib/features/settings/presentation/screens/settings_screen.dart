import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/app_feedback_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/widgets/app_failure_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/app_preferences.dart';
import '../controllers/app_preferences_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/app_lock_gate.dart';
import '../widgets/pin_editor_sheet.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const List<String> _currencyOptions = <String>[
    'USD',
    'AED',
    'EUR',
    'GBP',
    'INR',
  ];

  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _invoicePrefixController =
      TextEditingController();
  final FocusNode _taxFocusNode = FocusNode();
  final FocusNode _invoicePrefixFocusNode = FocusNode();

  bool _didHydratePreferences = false;

  @override
  void initState() {
    super.initState();
    _taxFocusNode.addListener(() {
      if (!_taxFocusNode.hasFocus) {
        _commitTaxSetting();
      }
    });
    _invoicePrefixFocusNode.addListener(() {
      if (!_invoicePrefixFocusNode.hasFocus) {
        _commitInvoicePrefixSetting();
      }
    });
  }

  @override
  void dispose() {
    _taxController.dispose();
    _invoicePrefixController.dispose();
    _taxFocusNode.dispose();
    _invoicePrefixFocusNode.dispose();
    super.dispose();
  }

  void _hydratePreferenceFields(AppPreferences preferences) {
    if (_didHydratePreferences) {
      return;
    }

    _didHydratePreferences = true;
    _taxController.text = _formatTaxPercent(preferences.defaultTaxPercent);
    _invoicePrefixController.text = preferences.invoicePrefix;
  }

  Future<void> _commitTaxSetting() async {
    final current = ref.read(appPreferencesControllerProvider).valueOrNull;
    if (current == null) {
      return;
    }

    final sanitized = _sanitizeTaxPercent(_taxController.text);
    final normalizedText = _formatTaxPercent(sanitized);
    if (_taxController.text != normalizedText) {
      _taxController.value = TextEditingValue(
        text: normalizedText,
        selection: TextSelection.collapsed(offset: normalizedText.length),
      );
    }

    if ((current.defaultTaxPercent - sanitized).abs() < 0.0001) {
      return;
    }

    await ref
        .read(appPreferencesControllerProvider.notifier)
        .patch(
          (preferences) => preferences.copyWith(defaultTaxPercent: sanitized),
        );
  }

  Future<void> _commitInvoicePrefixSetting() async {
    final current = ref.read(appPreferencesControllerProvider).valueOrNull;
    if (current == null) {
      return;
    }

    final sanitized = _sanitizeInvoicePrefix(_invoicePrefixController.text);
    if (_invoicePrefixController.text != sanitized) {
      _invoicePrefixController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }

    if (current.invoicePrefix == sanitized) {
      return;
    }

    await ref
        .read(appPreferencesControllerProvider.notifier)
        .patch((preferences) => preferences.copyWith(invoicePrefix: sanitized));
  }

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
    if (!enabled) {
      await ref
          .read(appPreferencesControllerProvider.notifier)
          .patch((current) => current.copyWith(appLockEnabled: false));
      ref.read(appLockSessionProvider.notifier).state = false;
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

    await ref
        .read(appPreferencesControllerProvider.notifier)
        .patch(
          (current) =>
              current.copyWith(appLockEnabled: true, appLockPin: nextPin),
        );
    ref.read(appLockSessionProvider.notifier).state = true;
    AppFeedbackService.showSnackBar('App lock is enabled.');
  }

  Future<void> _changePin(AppPreferences preferences) async {
    final nextPin = await showPinEditorSheet(
      context,
      title: preferences.hasPin ? 'Change PIN' : 'Set PIN',
      submitLabel: 'Save PIN',
    );
    if (!mounted || nextPin == null) {
      return;
    }

    await ref
        .read(appPreferencesControllerProvider.notifier)
        .patch((current) => current.copyWith(appLockPin: nextPin));
    ref.read(appLockSessionProvider.notifier).state = true;
    AppFeedbackService.showSnackBar('PIN updated.');
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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

    final profileError = profileState.asError;
    final preferencesError = preferencesState.asError;
    if (profileError != null || preferencesError != null) {
      return Scaffold(
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
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    _hydratePreferenceFields(preferences);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          GestureDetector(
            onTap: _openProfileEditor,
            behavior: HitTestBehavior.opaque,
            child: _SectionCard(
              title: 'Profile',
              children: [
                _InfoRow(label: 'Name', value: _displayValue(profile.name)),
                _InfoRow(label: 'Email', value: _displayValue(profile.email)),
                _InfoRow(
                  label: 'Business Name',
                  value: _displayValue(profile.businessName),
                ),
                _InfoRow(label: 'Phone', value: _displayValue(profile.phone)),
                _InfoRow(
                  label: 'Address',
                  value: _displayValue(profile.address),
                  isLast: true,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openProfileEditor,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Profile'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _PlanSectionCard(
            subscription: subscription,
            usage: usage,
            onUpgrade: subscription.isPro
                ? null
                : () {
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
                onChanged: (value) => _togglePreference(
                  (current) =>
                      current.copyWith(pushNotificationsEnabled: value),
                ),
              ),
              _SwitchRow(
                title: 'WhatsApp reminders',
                subtitle: 'Allow reminder launches through WhatsApp.',
                value: preferences.whatsAppRemindersEnabled,
                onChanged: (value) => _togglePreference(
                  (current) =>
                      current.copyWith(whatsAppRemindersEnabled: value),
                ),
              ),
              _SwitchRow(
                title: 'SMS reminders',
                subtitle: 'Allow reminder launches through SMS.',
                value: preferences.smsRemindersEnabled,
                onChanged: (value) => _togglePreference(
                  (current) => current.copyWith(smsRemindersEnabled: value),
                ),
              ),
              _SwitchRow(
                title: '24h before',
                subtitle: 'Schedule a reminder one day before the due date.',
                value: preferences.remind24HoursBefore,
                enabled: preferences.pushNotificationsEnabled,
                onChanged: (value) => _togglePreference(
                  (current) => current.copyWith(remind24HoursBefore: value),
                ),
              ),
              _SwitchRow(
                title: '3h before',
                subtitle: 'Schedule a final heads-up three hours before due.',
                value: preferences.remind3HoursBefore,
                enabled: preferences.pushNotificationsEnabled,
                onChanged: (value) => _togglePreference(
                  (current) => current.copyWith(remind3HoursBefore: value),
                ),
              ),
              _SwitchRow(
                title: 'On due date',
                subtitle: 'Notify when the invoice becomes due.',
                value: preferences.remindOnDueDate,
                enabled: preferences.pushNotificationsEnabled,
                onChanged: (value) => _togglePreference(
                  (current) => current.copyWith(remindOnDueDate: value),
                ),
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
              DropdownButtonFormField<String>(
                initialValue:
                    _currencyOptions.contains(preferences.defaultCurrency)
                    ? preferences.defaultCurrency
                    : _currencyOptions.first,
                decoration: _inputDecoration('Default currency'),
                items: _currencyOptions
                    .map(
                      (currency) => DropdownMenuItem<String>(
                        value: currency,
                        child: Text(currency),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  _togglePreference(
                    (current) => current.copyWith(defaultCurrency: value),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _taxController,
                focusNode: _taxFocusNode,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: _inputDecoration('Default tax %'),
                onSubmitted: (_) => _commitTaxSetting(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _invoicePrefixController,
                focusNode: _invoicePrefixFocusNode,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                ],
                decoration: _inputDecoration('Invoice prefix'),
                onSubmitted: (_) => _commitInvoicePrefixSetting(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentTermsOption>(
                initialValue: preferences.paymentTerms,
                decoration: _inputDecoration('Payment terms'),
                items: PaymentTermsOption.values
                    .map(
                      (terms) => DropdownMenuItem<PaymentTermsOption>(
                        value: terms,
                        child: Text(terms.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  _togglePreference(
                    (current) => current.copyWith(paymentTerms: value),
                  );
                },
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
                  (current) => current.copyWith(smartPredictionEnabled: value),
                ),
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
                onTap: () => _openExternalLink(AppConstants.termsOfServiceUrl),
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
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Logout',
            icon: Icons.logout,
            onPressed: () {
              ref.read(appLockSessionProvider.notifier).state = false;
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _displayValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Not set' : trimmed;
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
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...children,
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

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Plan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
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
                  subscription.isPro ? 'Invoice Flow Pro' : 'Free',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            subscription.isPro
                ? 'Unlimited clients, unlimited invoices, smart reminders, WhatsApp sharing, and no PDF watermark.'
                : 'Free includes up to 5 clients, 5 invoices each month, and watermarked PDF exports.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Usage', value: usage.clientUsageLabel),
          _InfoRow(
            label: 'Invoices',
            value: usage.invoiceUsageLabel,
            isLast: subscription.isPro || onUpgrade != null,
          ),
          if (subscription.isPro) ...[
            const SizedBox(height: 6),
            Text(
              'Invoice Flow Pro is active on this device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ] else if (onUpgrade != null) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Upgrade to Pro',
              icon: Icons.workspace_premium_outlined,
              onPressed: onUpgrade,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: textTheme.bodyLarge, softWrap: true),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Opacity(
      opacity: enabled ? 1 : 0.6,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
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
                ),
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

    return Column(children: [row, const SizedBox(height: 12)]);
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
    final theme = Theme.of(context);
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
              child: Column(
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
              ),
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

    return Column(children: [row, const SizedBox(height: 12)]);
  }
}
