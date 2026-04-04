import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/components/premium_frosted_card.dart';
import '../../../../shared/components/premium_primary_button.dart';
import '../../../clients/domain/entities/client.dart';
import '../../../clients/presentation/controllers/clients_controller.dart';
import '../../../settings/domain/entities/app_preferences.dart';
import '../../../settings/presentation/controllers/app_preferences_controller.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../../settings/presentation/widgets/profile_editor_sheet.dart';
import '../../domain/entities/invoice.dart';
import '../controllers/invoice_creation_learning_controller.dart';
import '../controllers/invoice_prediction_engine.dart';
import '../controllers/invoices_controller.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientFieldKey = GlobalKey<FormFieldState<Client?>>();
  final _dueDateFieldKey = GlobalKey<FormFieldState<DateTime?>>();
  final _serviceController = TextEditingController();
  final _amountController = TextEditingController();
  final _serviceFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();

  Client? _selectedClient;
  DateTime? _selectedDueDate;
  String? _lastAutoServiceValue;
  String? _lastAutoAmountValue;
  DateTime? _lastAutoDueDate;
  DateTime? _lastSettingsDueDate;
  bool _isSaving = false;
  bool _smartSyncScheduled = false;
  bool _settingsSyncScheduled = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _serviceController.dispose();
    _amountController.dispose();
    _serviceFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<Client?> _showClientPicker() {
    FocusScope.of(context).unfocus();

    return showModalBottomSheet<Client>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ClientPickerSheet(selectedClientId: _selectedClient?.id);
      },
    );
  }

  Future<DateTime?> _showDueDatePicker() {
    FocusScope.of(context).unfocus();
    final paymentTerms = ref
        .read(appPreferencesControllerProvider)
        .valueOrNull
        ?.paymentTerms
        .days;

    return showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate:
          _selectedDueDate ??
          _dateAfterDays(
            paymentTerms ?? const AppPreferences.defaults().paymentTerms.days,
          ),
    );
  }

  Future<void> _selectClient() async {
    final selectedClient = await _showClientPicker();

    if (!mounted || selectedClient == null) {
      return;
    }

    _applySelectedClient(
      selectedClient,
      requestServiceFocus: true,
      forceFill: true,
    );
  }

  Future<void> _selectDueDate() async {
    final pickedDate = await _showDueDatePicker();

    if (!mounted || pickedDate == null) {
      return;
    }

    setState(() => _selectedDueDate = pickedDate);
    _dueDateFieldKey.currentState?.didChange(pickedDate);
  }

  void _applySelectedClient(
    Client client, {
    required bool requestServiceFocus,
    required bool forceFill,
  }) {
    FocusScope.of(context).unfocus();

    setState(() => _selectedClient = client);
    _clientFieldKey.currentState?.didChange(client);

    _applyClientSuggestion(
      intelligence: _buildCurrentIntelligence(),
      client: client,
      force: forceFill,
    );

    if (!requestServiceFocus) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _serviceFocusNode.requestFocus();
      }
    });
  }

  SmartInvoicePrediction _buildCurrentIntelligence() {
    return ref.read(smartInvoicePredictionProvider);
  }

  void _scheduleSmartSync() {
    final launchMode = ref.read(invoiceCreateLaunchModeProvider);
    if (launchMode == InvoiceCreateLaunchMode.manual) {
      return;
    }

    if (_smartSyncScheduled) {
      return;
    }

    _smartSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _smartSyncScheduled = false;
      if (!mounted) {
        return;
      }

      _syncSmartDefaults(_buildCurrentIntelligence());
    });
  }

  void _scheduleSettingsSync(AppPreferences preferences) {
    if (_settingsSyncScheduled) {
      return;
    }

    _settingsSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settingsSyncScheduled = false;
      if (!mounted) {
        return;
      }

      final nextSettingsDueDate = _dateAfterDays(preferences.paymentTerms.days);
      final currentDueDate = _selectedDueDate;
      final shouldApply =
          currentDueDate == null ||
          _sameCalendarDay(currentDueDate, _lastSettingsDueDate);
      _lastSettingsDueDate = nextSettingsDueDate;
      if (!shouldApply ||
          _sameCalendarDay(currentDueDate, nextSettingsDueDate)) {
        return;
      }

      setState(() => _selectedDueDate = nextSettingsDueDate);
      _dueDateFieldKey.currentState?.didChange(nextSettingsDueDate);
    });
  }

  void _syncSmartDefaults(SmartInvoicePrediction intelligence) {
    final selectedClient = _selectedClient;
    if (selectedClient != null) {
      _applyClientSuggestion(
        intelligence: intelligence,
        client: selectedClient,
        force: false,
      );
      return;
    }

    final suggestedAmount = intelligence.quickAmountConfidence >= 0.50
        ? intelligence.quickAmount
        : null;

    if (suggestedAmount != null) {
      _applySmartValues(amount: suggestedAmount, force: false);
    }
  }

  void _applyClientSuggestion({
    required SmartInvoicePrediction intelligence,
    required Client client,
    required bool force,
  }) {
    final draft = intelligence.buildDraftForClient(
      client,
      minimumConfidence: 0.50,
    );

    _applySmartValues(
      service: draft.usedFallbackService ? null : draft.service,
      amount: draft.usedFallbackAmount ? null : draft.amount,
      force: force,
    );
  }

  void _applySmartValues({
    String? service,
    double? amount,
    int? dueDays,
    required bool force,
  }) {
    final suggestedService = service?.trim();
    if (suggestedService != null &&
        suggestedService.isNotEmpty &&
        (force || _shouldApplyAutoService())) {
      if (!_sameServiceValue(_serviceController.text, suggestedService)) {
        _serviceController.value = TextEditingValue(
          text: suggestedService,
          selection: TextSelection.collapsed(offset: suggestedService.length),
        );
      }
      _lastAutoServiceValue = suggestedService;
    }

    if (amount != null) {
      final amountText = _formatAmountInput(amount);
      if (force || _shouldApplyAutoAmount()) {
        if (!_sameNumericText(_amountController.text, amountText)) {
          _amountController.value = TextEditingValue(
            text: amountText,
            selection: TextSelection.collapsed(offset: amountText.length),
          );
        }
        _lastAutoAmountValue = amountText;
      }
    }

    if (dueDays != null) {
      final suggestedDate = _dateAfterDays(dueDays);
      if ((force || _shouldApplyAutoDueDate()) &&
          !_sameCalendarDay(_selectedDueDate, suggestedDate)) {
        setState(() => _selectedDueDate = suggestedDate);
        _dueDateFieldKey.currentState?.didChange(suggestedDate);
      }
      _lastAutoDueDate = suggestedDate;
    }
  }

  bool _shouldApplyAutoService() {
    final currentValue = _serviceController.text.trim();
    return currentValue.isEmpty ||
        _sameServiceValue(currentValue, _lastAutoServiceValue);
  }

  bool _shouldApplyAutoAmount() {
    final currentValue = _amountController.text.trim();
    return currentValue.isEmpty ||
        _sameNumericText(currentValue, _lastAutoAmountValue);
  }

  bool _shouldApplyAutoDueDate() {
    final currentValue = _selectedDueDate;
    if (currentValue == null) {
      return true;
    }

    return _sameCalendarDay(currentValue, _lastAutoDueDate);
  }

  String _buildAmountHintText(
    SmartInvoicePrediction intelligence,
    SmartClientSuggestion? clientSuggestion,
    String currencyCode,
  ) {
    if (clientSuggestion?.amount != null &&
        (clientSuggestion?.amountConfidence ?? 0) >= 0.50) {
      final amountReason = clientSuggestion?.amountReason ?? 'last used';
      return '${_compactCurrency(clientSuggestion!.amount!, currencyCode)} ($amountReason)';
    }

    if (intelligence.quickAmount != null &&
        intelligence.quickAmountConfidence >= 0.50) {
      final amountReason = intelligence.quickAmountReason ?? 'common amount';
      return '${_compactCurrency(intelligence.quickAmount!, currencyCode)} ($amountReason)';
    }

    return '250.00';
  }

  List<_SmartActionChipData> _buildSmartActions(
    SmartInvoicePrediction intelligence,
    SmartClientSuggestion? clientSuggestion,
    String currencyCode,
  ) {
    final actions = <_SmartActionChipData>[];

    if (_selectedClient != null && clientSuggestion != null) {
      final latestInvoice = clientSuggestion.latestInvoice;
      final latestDueDays = latestInvoice == null
          ? null
          : _dueDaysFromInvoice(latestInvoice);

      final hasSuggestedBundle =
          (clientSuggestion.service != null &&
              clientSuggestion.serviceConfidence >= 0.50) ||
          (clientSuggestion.amount != null &&
              clientSuggestion.amountConfidence >= 0.50) ||
          (clientSuggestion.suggestedDueDays != null &&
              clientSuggestion.dueDaysConfidence >= 0.50);

      if (hasSuggestedBundle) {
        actions.add(
          _SmartActionChipData(
            label: 'Same as Previous',
            onTap: () {
              final draft = intelligence.buildDraftForClient(
                _selectedClient,
                minimumConfidence: 0.50,
              );
              _applySmartValues(
                service: draft.usedFallbackService ? null : draft.service,
                amount: draft.usedFallbackAmount ? null : draft.amount,
                dueDays: draft.dueDays,
                force: true,
              );
            },
          ),
        );
      }

      final showLastInvoiceChip =
          latestInvoice != null &&
          !_matchesSuggestedSnapshot(latestInvoice, clientSuggestion);
      if (showLastInvoiceChip) {
        actions.add(
          _SmartActionChipData(
            label: 'Last Invoice',
            onTap: () {
              _applySmartValues(
                service: latestInvoice.service,
                amount: latestInvoice.amount,
                dueDays: latestDueDays,
                force: true,
              );
            },
          ),
        );
      } else if (actions.length < 2 &&
          clientSuggestion.suggestedDueDays != null &&
          clientSuggestion.dueDaysConfidence >= 0.50) {
        actions.add(
          _SmartActionChipData(
            label: 'Due in ${clientSuggestion.suggestedDueDays} days',
            onTap: () {
              _applySmartValues(
                dueDays: clientSuggestion.suggestedDueDays,
                force: true,
              );
            },
          ),
        );
      }
    } else {
      if (intelligence.quickAmount != null &&
          intelligence.quickAmountConfidence >= 0.50) {
        actions.add(
          _SmartActionChipData(
            label:
                'Quick ${_compactCurrency(intelligence.quickAmount!, currencyCode)}',
            onTap: () {
              _applySmartValues(amount: intelligence.quickAmount, force: true);
            },
          ),
        );
      }

      if (actions.length < 2 && intelligence.preferredDueDays != null) {
        actions.add(
          _SmartActionChipData(
            label: 'Due in ${intelligence.preferredDueDays} days',
            onTap: () {
              _applySmartValues(
                dueDays: intelligence.preferredDueDays,
                force: true,
              );
            },
          ),
        );
      }
    }

    return actions.take(2).toList(growable: false);
  }

  bool _matchesSuggestedSnapshot(
    Invoice latestInvoice,
    SmartClientSuggestion suggestion,
  ) {
    return _sameServiceValue(latestInvoice.service, suggestion.service) &&
        _sameNumericValues(latestInvoice.amount, suggestion.amount) &&
        _dueDaysFromInvoice(latestInvoice) == suggestion.suggestedDueDays;
  }

  int? _dueDaysFromInvoice(Invoice invoice) {
    final createdDate = DateTime(
      invoice.createdAt.year,
      invoice.createdAt.month,
      invoice.createdAt.day,
    );
    final dueDate = DateTime(
      invoice.dueDate.year,
      invoice.dueDate.month,
      invoice.dueDate.day,
    );
    final difference = dueDate.difference(createdDate).inDays;
    if (difference <= 0) {
      return null;
    }
    return difference;
  }

  DateTime _dateAfterDays(int days) {
    final today = DateTime.now();
    return DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: days));
  }

  String _formatAmountInput(double value) {
    final fixed = value.toStringAsFixed(2);
    if (fixed.endsWith('.00')) {
      return fixed.substring(0, fixed.length - 3);
    }
    if (fixed.endsWith('0')) {
      return fixed.substring(0, fixed.length - 1);
    }
    return fixed;
  }

  String _normalizedInvoicePrefix(String rawPrefix) {
    final sanitized = rawPrefix.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9-]'),
      '',
    );
    return sanitized.isEmpty ? 'INV' : sanitized;
  }

  double _applyTax(double amount, double taxPercent) {
    if (taxPercent <= 0) {
      return amount;
    }

    return amount * (1 + (taxPercent / 100));
  }

  String _compactCurrency(double value, String currencyCode) {
    if (value == value.roundToDouble()) {
      return AppFormatters.currency(
        value,
        currencyCode: currencyCode,
        includeDecimals: false,
      );
    }
    return AppFormatters.currency(value, currencyCode: currencyCode);
  }

  bool _sameServiceValue(String? left, String? right) {
    final normalizedLeft = left?.trim().toLowerCase() ?? '';
    final normalizedRight = right?.trim().toLowerCase() ?? '';
    return normalizedLeft.isNotEmpty && normalizedLeft == normalizedRight;
  }

  bool _sameNumericText(String? left, String? right) {
    final leftValue = double.tryParse(left?.trim() ?? '');
    final rightValue = double.tryParse(right?.trim() ?? '');
    if (leftValue == null || rightValue == null) {
      return false;
    }
    return (leftValue - rightValue).abs() < 0.001;
  }

  bool _sameNumericValues(double? left, double? right) {
    if (left == null || right == null) {
      return false;
    }
    return (left - right).abs() < 0.001;
  }

  Future<bool> _ensureUserProfileReady() async {
    final profile = await ref.read(getProfileUseCaseProvider).call();
    if (profile.isComplete) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final updatedProfile = await showUserProfileEditorSheet(
      context,
      initialProfile: profile,
      title: 'Set Up Profile',
      submitLabel: 'Save Profile',
    );

    if (updatedProfile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete your profile before creating an invoice.'),
          ),
        );
      }
      return false;
    }

    await ref
        .read(settingsControllerProvider.notifier)
        .saveProfile(updatedProfile);
    return true;
  }

  bool _sameCalendarDay(DateTime? left, DateTime? right) {
    if (left == null || right == null) {
      return false;
    }

    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    if (_autovalidateMode == AutovalidateMode.disabled) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
    }

    final form = _formKey.currentState;
    final selectedClient = _selectedClient;
    final selectedDueDate = _selectedDueDate;
    final service = _serviceController.text.trim();
    final subtotalAmount = double.tryParse(_amountController.text.trim());
    final now = DateTime.now();
    final intelligence = ref.read(smartInvoicePredictionProvider);
    final preferences =
        ref.read(appPreferencesControllerProvider).valueOrNull ??
        await ref.read(getAppPreferencesUseCaseProvider).call();

    if (!(form?.validate() ?? false) ||
        selectedClient == null ||
        selectedDueDate == null ||
        subtotalAmount == null) {
      return;
    }

    final hasProfile = await _ensureUserProfileReady();
    if (!hasProfile) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final invoiceId = await ref
          .read(invoiceRepositoryProvider)
          .getNextInvoiceId(
            prefix: _normalizedInvoicePrefix(preferences.invoicePrefix),
          );
      final taxPercent = preferences.defaultTaxPercent;
      final totalAmount = _applyTax(subtotalAmount, taxPercent);
      final invoice = Invoice(
        id: invoiceId,
        clientId: selectedClient.id,
        clientName: selectedClient.name,
        service: service,
        amount: totalAmount,
        dueDate: selectedDueDate,
        status: InvoiceStatus.pending,
        createdAt: now,
        currencyCode: preferences.defaultCurrency,
        taxPercent: taxPercent,
        paymentTermsDays: preferences.paymentTerms.days,
      );

      final createdInvoice = await ref
          .read(invoicesControllerProvider.notifier)
          .createInvoice(invoice);
      final predictedDraft = intelligence.buildDraftForClient(
        selectedClient,
        now: now,
        minimumConfidence: 0,
      );
      await ref
          .read(invoiceCreationLearningProvider.notifier)
          .recordPredictionOutcome(
            predictedClientId: intelligence.suggestedClient?.id,
            predictedService: predictedDraft.usedFallbackService
                ? null
                : predictedDraft.service,
            predictedAmount: predictedDraft.usedFallbackAmount
                ? null
                : predictedDraft.amount,
            predictedDueDate: predictedDraft.usedFallbackDueDays
                ? null
                : predictedDraft.dueDate,
            actualInvoice: createdInvoice,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save the invoice right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    ref.watch(invoiceCreateLaunchModeProvider);
    final preferencesState = ref.watch(appPreferencesControllerProvider);
    final preferences = preferencesState.valueOrNull;
    final displayPreferences = preferences ?? const AppPreferences.defaults();
    final intelligence = ref.watch(smartInvoicePredictionProvider);
    final clientSuggestion = _selectedClient == null
        ? null
        : intelligence.suggestionFor(_selectedClient!.id);
    final amountHintText = _buildAmountHintText(
      intelligence,
      clientSuggestion,
      displayPreferences.defaultCurrency,
    );
    final smartActions = _buildSmartActions(
      intelligence,
      clientSuggestion,
      displayPreferences.defaultCurrency,
    );

    _scheduleSmartSync();
    if (preferences != null) {
      _scheduleSettingsSync(preferences);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Invoice')),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              child: PremiumFrostedCard(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autovalidateMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select a client, add the service, then choose when payment is due.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_selectedClient == null &&
                          intelligence.suggestedClient != null) ...[
                        const SizedBox(height: 16),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _applySelectedClient(
                                intelligence.suggestedClient!,
                                requestServiceFocus: false,
                                forceFill: true,
                              );
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.24,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _ClientAvatar(
                                    name: intelligence.suggestedClient!.name,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Suggested: ${intelligence.suggestedClient!.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          intelligence.suggestedClientReason ??
                                              'Based on your invoice history',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Use',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (smartActions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: smartActions
                              .map(
                                (action) => ActionChip(
                                  label: Text(action.label),
                                  onPressed: action.onTap,
                                  backgroundColor: AppColors.glassFill,
                                  side: BorderSide(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                  labelStyle: theme.textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FormField<Client?>(
                        key: _clientFieldKey,
                        initialValue: _selectedClient,
                        validator: (value) {
                          if (value == null) {
                            return 'Select a client.';
                          }
                          return null;
                        },
                        builder: (field) {
                          return _LabeledField(
                            label: 'Client',
                            errorText: field.errorText,
                            child: _InputSurface(
                              isFocused: false,
                              hasError: field.hasError,
                              onTap: _selectClient,
                              child: Row(
                                children: [
                                  if (field.value != null) ...[
                                    _ClientAvatar(name: field.value!.name),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Text(
                                      field.value?.name ?? 'Select a client',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: field.value == null
                                                ? AppColors.textMuted
                                                : AppColors.textPrimary,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.expand_more_rounded,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _InvoiceTextField(
                        controller: _serviceController,
                        label: 'Service',
                        hintText: 'Monthly retainer',
                        focusNode: _serviceFocusNode,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          _amountFocusNode.requestFocus();
                        },
                      ),
                      const SizedBox(height: 16),
                      _InvoiceTextField(
                        controller: _amountController,
                        label: 'Amount',
                        hintText: amountHintText,
                        focusNode: _amountFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$'),
                          ),
                        ],
                        validator: (value) {
                          final rawValue = value?.trim() ?? '';
                          if (rawValue.isEmpty) {
                            return 'Enter an amount.';
                          }

                          final parsedValue = double.tryParse(rawValue);
                          if (parsedValue == null || parsedValue <= 0) {
                            return 'Enter a valid amount.';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) async {
                          await _selectDueDate();
                        },
                      ),
                      const SizedBox(height: 16),
                      FormField<DateTime?>(
                        key: _dueDateFieldKey,
                        initialValue: _selectedDueDate,
                        validator: (value) {
                          if (value == null) {
                            return 'Select a due date.';
                          }
                          return null;
                        },
                        builder: (field) {
                          final dateText = field.value == null
                              ? 'Select date'
                              : AppFormatters.shortDate(field.value!);

                          return _LabeledField(
                            label: 'Due Date',
                            errorText: field.errorText,
                            child: _InputSurface(
                              isFocused: false,
                              hasError: field.hasError,
                              onTap: _selectDueDate,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      dateText,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: field.value == null
                                                ? AppColors.textMuted
                                                : AppColors.textPrimary,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      PremiumPrimaryButton(
                        label: 'Save Invoice',
                        isLoading: _isSaving,
                        onPressed: _isSaving ? null : _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmartActionChipData {
  const _SmartActionChipData({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

class _ClientPickerSheet extends ConsumerStatefulWidget {
  const _ClientPickerSheet({required this.selectedClientId});

  final String? selectedClientId;

  @override
  ConsumerState<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends ConsumerState<_ClientPickerSheet> {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();

  bool _showAddForm = false;
  bool _isSaving = false;
  bool _didResolveLocaleCountry = false;
  String _initialCountryCode = 'US';
  String _fullPhoneNumber = '';
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didResolveLocaleCountry) {
      return;
    }

    _initialCountryCode = _resolveInitialCountryCode(
      Localizations.localeOf(context),
    );
    _didResolveLocaleCountry = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  String _resolveInitialCountryCode(Locale locale) {
    final localeCountryCode = locale.countryCode;
    if (localeCountryCode != null && localeCountryCode.length == 2) {
      return localeCountryCode.toUpperCase();
    }

    switch (locale.languageCode.toLowerCase()) {
      case 'ar':
        return 'AE';
      case 'de':
        return 'DE';
      case 'es':
        return 'ES';
      case 'fr':
        return 'FR';
      case 'hi':
        return 'IN';
      case 'it':
        return 'IT';
      case 'ja':
        return 'JP';
      case 'ko':
        return 'KR';
      case 'pt':
        return 'BR';
      case 'ru':
        return 'RU';
      case 'zh':
        return 'CN';
      default:
        return 'US';
    }
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  void _revalidateContactFields() {
    if (_autovalidateMode != AutovalidateMode.disabled) {
      _formKey.currentState?.validate();
    }
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    final phoneDigits = _digitsOnly(_fullPhoneNumber);

    if (email.isEmpty && phoneDigits.isEmpty) {
      return 'Add an email or phone number.';
    }

    if (email.isNotEmpty && !_emailRegex.hasMatch(email)) {
      return 'Enter a valid email.';
    }

    return null;
  }

  String? _validatePhone(dynamic phone) {
    final email = _emailController.text.trim();
    final localDigits = _digitsOnly(_phoneController.text);

    if (localDigits.isEmpty && email.isEmpty) {
      return 'Add an email or phone number.';
    }

    if (localDigits.isEmpty) {
      return null;
    }

    final fullDigits = _digitsOnly(_fullPhoneNumber);
    if (fullDigits.length < 8 || fullDigits.length > 15) {
      return 'Enter a valid phone number.';
    }

    return null;
  }

  Future<void> _saveClient() async {
    if (_isSaving) {
      return;
    }

    if (_autovalidateMode == AutovalidateMode.disabled) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
    }

    final form = _formKey.currentState;
    if (!(form?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final createdClient = await ref
          .read(clientsControllerProvider.notifier)
          .addClient(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _fullPhoneNumber.trim(),
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(createdClient);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to add the client right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsState = ref.watch(clientsControllerProvider);
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          mediaQuery.viewInsets.bottom + 12,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.82,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.20),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _showAddForm
                      ? _buildAddClientView(theme)
                      : _buildSelectionView(theme, clientsState),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionView(
    ThemeData theme,
    AsyncValue<List<Client>> clientsState,
  ) {
    return SizedBox(
      key: const ValueKey('client-list'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BottomSheetHeader(
            title: 'Client',
            subtitle: 'Select an existing client or add a new one.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Select Existing Client',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: clientsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Unable to load clients.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () {
                            ref
                                .read(clientsControllerProvider.notifier)
                                .loadInitial();
                          },
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              data: (clients) {
                if (clients.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No clients yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add a client here and it will be selected for this invoice automatically.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: clients.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    final subtitle = client.email.isNotEmpty
                        ? client.email
                        : client.phone;
                    final isSelected = client.id == widget.selectedClientId;

                    return _ClientListTile(
                      client: client,
                      subtitle: subtitle,
                      isSelected: isSelected,
                      onTap: () => Navigator.of(context).pop(client),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: PremiumPrimaryButton(
              label: 'Add New Client',
              variant: PremiumButtonVariant.secondary,
              leading: const Icon(Icons.add_rounded, size: 18),
              onPressed: () async {
                setState(() => _showAddForm = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _nameFocusNode.requestFocus();
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddClientView(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('add-client'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BottomSheetHeader(
              title: 'Add New Client',
              subtitle: 'Create the client here and link it to this invoice.',
              onBack: () => setState(() => _showAddForm = false),
            ),
            _InvoiceTextField(
              controller: _nameController,
              label: 'Client Name',
              hintText: 'Acme Studio',
              focusNode: _nameFocusNode,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return 'Enter the client name.';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                _emailFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 16),
            _InvoiceTextField(
              controller: _emailController,
              label: 'Email',
              hintText: 'client@business.com',
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
              onChanged: (_) => _revalidateContactFields(),
              onFieldSubmitted: (_) {
                _phoneFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Phone',
              child: IntlPhoneField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                initialCountryCode: _initialCountryCode,
                disableLengthCheck: true,
                autovalidateMode: _autovalidateMode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
                dropdownTextStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.accent,
                decoration: _buildGlassTextFieldDecoration(
                  theme,
                  hintText: '555010100',
                  counterText: '',
                ),
                onChanged: (phone) {
                  final localNumber = _digitsOnly(phone.number);
                  _fullPhoneNumber = localNumber.isEmpty
                      ? ''
                      : '+${phone.completeNumber}';
                  _revalidateContactFields();
                },
                onCountryChanged: (country) {
                  final localNumber = _digitsOnly(_phoneController.text);
                  _fullPhoneNumber = localNumber.isEmpty
                      ? ''
                      : '+${country.fullCountryCode}$localNumber';
                  _revalidateContactFields();
                },
                validator: _validatePhone,
                onSubmitted: (_) async {
                  await _saveClient();
                },
              ),
            ),
            const SizedBox(height: 24),
            PremiumPrimaryButton(
              label: 'Save Client',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _saveClient,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetHeader extends StatelessWidget {
  const _BottomSheetHeader({
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Column(
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientListTile extends StatelessWidget {
  const _ClientListTile({
    required this.client,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final Client client;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.10)
                : AppColors.glassFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.50)
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              _ClientAvatar(name: client.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _buildGlassTextFieldDecoration(
  ThemeData theme, {
  String? hintText,
  String? counterText,
  bool hasError = false,
  bool isFocused = false,
}) {
  OutlineInputBorder border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
  }

  final defaultBorderColor = Colors.white.withValues(alpha: 0.08);
  final activeBorderColor = hasError
      ? AppColors.danger
      : isFocused
      ? AppColors.accent.withValues(alpha: 0.60)
      : defaultBorderColor;

  return InputDecoration(
    hintText: hintText,
    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
    filled: true,
    fillColor: Colors.transparent,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(activeBorderColor),
    enabledBorder: border(hasError ? AppColors.danger : defaultBorderColor),
    focusedBorder: border(
      hasError ? AppColors.danger : AppColors.accent.withValues(alpha: 0.60),
    ),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger),
    counterText: counterText,
  );
}

class _InvoiceTextField extends FormField<String> {
  _InvoiceTextField({
    required TextEditingController controller,
    required this.label,
    this.hintText,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    super.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
  }) : _controller = controller,
       super(
         initialValue: controller.text,
         builder: (field) {
           final widget = field.widget as _InvoiceTextField;
           final theme = Theme.of(field.context);
           Widget buildSurface(bool isFocused) {
             return TextField(
               controller: widget._controller,
               focusNode: widget.focusNode,
               keyboardType: widget.keyboardType,
               textInputAction: widget.textInputAction,
               inputFormatters: widget.inputFormatters,
               onChanged: widget.onChanged,
               onSubmitted: widget.onFieldSubmitted,
               style: theme.textTheme.bodyLarge?.copyWith(
                 color: AppColors.textPrimary,
               ),
               cursorColor: AppColors.accent,
               scrollPadding: const EdgeInsets.only(bottom: 120),
               decoration: _buildGlassTextFieldDecoration(
                 theme,
                 hintText: widget.hintText,
                 hasError: field.hasError,
                 isFocused: isFocused,
               ),
             );
           }

           Widget surface = buildSurface(widget.focusNode?.hasFocus ?? false);

           if (widget.focusNode != null) {
             surface = AnimatedBuilder(
               animation: widget.focusNode!,
               builder: (context, _) {
                 return buildSurface(widget.focusNode!.hasFocus);
               },
             );
           }

           return _LabeledField(
             label: widget.label,
             errorText: field.errorText,
             child: surface,
           );
         },
       );

  final TextEditingController _controller;
  final String label;
  final String? hintText;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  FormFieldState<String> createState() => _InvoiceTextFieldState();
}

class _InvoiceTextFieldState extends FormFieldState<String> {
  @override
  _InvoiceTextField get widget => super.widget as _InvoiceTextField;

  @override
  void initState() {
    super.initState();
    widget._controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _InvoiceTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget._controller != widget._controller) {
      oldWidget._controller.removeListener(_handleControllerChanged);
      widget._controller.addListener(_handleControllerChanged);
      setValue(widget._controller.text);
    }
  }

  @override
  void dispose() {
    widget._controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (widget._controller.text != value) {
      didChange(widget._controller.text);
    }
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.errorText,
  });

  final String label;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _InputSurface extends StatelessWidget {
  const _InputSurface({
    required this.child,
    this.onTap,
    this.hasError = false,
    this.isFocused = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool hasError;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.danger
        : isFocused
        ? AppColors.accent.withValues(alpha: 0.60)
        : AppColors.glassBorder;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      height: 56,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isFocused ? 1.2 : 1),
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent.withValues(alpha: 0.18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        _initialsFromName(name),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _initialsFromName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }

    final first = parts.first.characters.first;
    final second = parts.last.characters.first;
    return '$first$second'.toUpperCase();
  }
}
