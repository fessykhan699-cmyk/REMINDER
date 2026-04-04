import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
import '../controllers/clients_controller.dart';

class AddClientScreen extends ConsumerStatefulWidget {
  const AddClientScreen({super.key});

  @override
  ConsumerState<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends ConsumerState<AddClientScreen> {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

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

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    final phoneDigits = _digitsOnly(_fullPhoneNumber);

    if (email.isEmpty && phoneDigits.isEmpty) {
      return 'Add an email or phone number.';
    }

    if (email.isNotEmpty && !_emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
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
      return 'Phone number must be 8 to 15 digits';
    }

    return null;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    _trimEmail();

    if (_autovalidateMode == AutovalidateMode.disabled) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields.')),
      );
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref
          .read(clientsControllerProvider.notifier)
          .addClient(
            name: name,
            email: _emailController.text.trim(),
            phone: _fullPhoneNumber.trim(),
          );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on SubscriptionGateException catch (error) {
      if (!mounted) {
        return;
      }
      await promptUpgradeForDecision(context, error.decision);
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
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Client')),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 20, 20, 120 + bottomInset),
            child: Form(
              key: _formKey,
              autovalidateMode: _autovalidateMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LabeledField(
                    label: 'Client Name',
                    child: TextField(
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
                      onSubmitted: (_) {
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
                      onChanged: (_) => _revalidateContactFields(),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      dropdownTextStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      cursorColor: AppColors.accent,
                      decoration: _buildInputDecoration(
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
                      onSubmitted: (_) {
                        _save();
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Save Client',
                    isLoading: _isSaving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
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
