import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
import '../../domain/entities/client.dart';
import '../controllers/clients_controller.dart';

class AddClientScreen extends ConsumerStatefulWidget {
  const AddClientScreen({super.key});

  @override
  ConsumerState<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends ConsumerState<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();

  bool _isSaving = false;
  bool _didResolveLocaleCountry = false;
  String _initialCountryCode = 'US';
  String _fullPhoneNumber = '';
  String _localPhoneDigits = '';
  String? _submissionErrorText;
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

  OutlineInputBorder _buildBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
  }

  InputDecoration _buildInputDecoration(
    ThemeData theme, {
    String? hintText,
    String? counterText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: AppColors.textMuted,
      ),
      filled: true,
      fillColor: Colors.transparent,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _buildBorder(Colors.white.withValues(alpha: 0.08)),
      enabledBorder: _buildBorder(Colors.white.withValues(alpha: 0.08)),
      focusedBorder: _buildBorder(AppColors.accent.withValues(alpha: 0.60)),
      errorBorder: _buildBorder(AppColors.danger),
      focusedErrorBorder: _buildBorder(AppColors.danger),
      counterText: counterText,
    );
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  void _trimEmail() {
    final trimmed = _emailController.text.trim();
    if (trimmed == _emailController.text) {
      return;
    }

    _emailController.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
      composing: TextRange.empty,
    );
  }

  void _revalidateContactFields() {
    if (_autovalidateMode != AutovalidateMode.disabled) {
      _formKey.currentState?.validate();
    }
  }

  void _clearSubmissionError() {
    if (_submissionErrorText == null) {
      return;
    }

    setState(() {
      _submissionErrorText = null;
    });
  }

  String _buildInternationalPhone({
    String? completeNumber,
    String? dialCode,
    String? localDigits,
  }) {
    if (completeNumber != null) {
      final digits = _digitsOnly(completeNumber);
      return digits.isEmpty ? '' : '+$digits';
    }

    final normalizedLocalDigits = _digitsOnly(localDigits ?? _localPhoneDigits);
    if (normalizedLocalDigits.isEmpty) {
      return '';
    }

    final normalizedDialCode = _digitsOnly(dialCode ?? '');
    if (normalizedDialCode.isEmpty) {
      return '+$normalizedLocalDigits';
    }

    return '+$normalizedDialCode$normalizedLocalDigits';
  }

  String? _validateName(String? value) {
    if ((value?.trim() ?? '').isEmpty) {
      return 'Name required';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (!Client.isValidEmail(email)) {
      return 'Invalid email';
    }

    return null;
  }

  String? _validatePhone(dynamic phone) {
    if (_localPhoneDigits.length < 8) {
      return 'Invalid phone';
    }

    if (!Client.hasValidInternationalPhone(_fullPhoneNumber)) {
      return 'Invalid phone';
    }

    return null;
  }

  String? _submissionValidationMessage() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      return 'Name required';
    }
    if (!Client.isValidEmail(email)) {
      return 'Invalid email';
    }
    if (_localPhoneDigits.length < 8 ||
        !Client.hasValidInternationalPhone(_fullPhoneNumber)) {
      return 'Invalid phone';
    }

    return null;
  }

  String _messageForClientError(AppException error) {
    switch (error.message) {
      case 'A client with this email already exists.':
      case 'A client with this phone already exists.':
      case 'A client with this ID already exists.':
        return 'Client already exists';
      default:
        return error.message;
    }
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    _trimEmail();
    if (_submissionErrorText != null) {
      setState(() {
        _submissionErrorText = null;
      });
    }

    if (_autovalidateMode == AutovalidateMode.disabled) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
    }

    final validationMessage = _submissionValidationMessage();
    if (validationMessage != null) {
      setState(() {
        _submissionErrorText = validationMessage;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() => _isSaving = true);
    var shouldResetSavingState = true;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final clientsController = ref.read(clientsControllerProvider.notifier);

    try {
      final createdClient = await clientsController.addClient(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _fullPhoneNumber.trim(),
      );

      if (!mounted) {
        return;
      }

      shouldResetSavingState = false;
      navigator.pop(createdClient);
      messenger.showSnackBar(
        const SnackBar(content: Text('Client saved successfully.')),
      );
    } on SubscriptionGateException catch (error) {
      if (!mounted) {
        return;
      }
      await promptUpgradeForDecision(context, error.decision);
    } on ValidationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submissionErrorText = _messageForClientError(error);
      });
      messenger.showSnackBar(
        SnackBar(content: Text(_messageForClientError(error))),
      );
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submissionErrorText = _messageForClientError(error);
      });
      messenger.showSnackBar(
        SnackBar(content: Text(_messageForClientError(error))),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to save client from add screen: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _submissionErrorText = 'Failed to save client';
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save client')),
      );
    } finally {
      if (mounted && shouldResetSavingState) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Client')),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 120 + bottomInset),
                  itemCount: 1,
                  itemBuilder: (context, index) {
                    return Form(
                      key: _formKey,
                      autovalidateMode: _autovalidateMode,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LabeledField(
                            label: 'Client Name',
                            child: TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              cursorColor: AppColors.accent,
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              decoration: _buildInputDecoration(
                                theme,
                                hintText: 'Acme Studio',
                              ),
                              validator: _validateName,
                              onChanged: (_) => _clearSubmissionError(),
                              onFieldSubmitted: (_) {
                                _emailFocusNode.requestFocus();
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _LabeledField(
                            label: 'Email',
                            child: TextFormField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              cursorColor: AppColors.accent,
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              decoration: _buildInputDecoration(
                                theme,
                                hintText: 'client@business.com',
                              ),
                              validator: _validateEmail,
                              onChanged: (_) {
                                _clearSubmissionError();
                                _revalidateContactFields();
                              },
                              onFieldSubmitted: (_) {
                                _phoneFocusNode.requestFocus();
                              },
                            ),
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
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              dropdownTextStyle: theme.textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.textPrimary),
                              cursorColor: AppColors.accent,
                              decoration: _buildInputDecoration(
                                theme,
                                hintText: '555010100',
                                counterText: '',
                              ),
                              onChanged: (phone) {
                                _clearSubmissionError();
                                _localPhoneDigits = _digitsOnly(phone.number);
                                _fullPhoneNumber = _buildInternationalPhone(
                                  completeNumber: phone.completeNumber,
                                );
                                _revalidateContactFields();
                              },
                              onCountryChanged: (country) {
                                _clearSubmissionError();
                                _fullPhoneNumber = _buildInternationalPhone(
                                  dialCode: country.fullCountryCode,
                                  localDigits: _localPhoneDigits,
                                );
                                _revalidateContactFields();
                              },
                              validator: _validatePhone,
                              onSubmitted: (_) async {
                                await _save();
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Save Client',
                            isLoading: _isSaving,
                            onPressed: _save,
                          ),
                          if (_submissionErrorText != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _submissionErrorText!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

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
      ],
    );
  }
}
