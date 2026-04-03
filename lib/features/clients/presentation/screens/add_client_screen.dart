import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../shared/components/app_input_field.dart';
import '../../../../shared/components/primary_button.dart';
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

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _emailFormKey = GlobalKey<FormState>();
  final _phoneFormKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _validateEmailOnBlur = false;
  bool _validateOnSubmit = false;
  bool _didResolveLocaleCountry = false;
  String _initialCountryCode = 'US';
  String _fullPhoneNumber = '';

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_handleEmailFocusChange);
    _phoneFocusNode.addListener(_handlePhoneFocusChange);
  }

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
    _emailFocusNode
      ..removeListener(_handleEmailFocusChange)
      ..dispose();
    _phoneFocusNode
      ..removeListener(_handlePhoneFocusChange)
      ..dispose();
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

  bool get _shouldValidateEmail {
    return _validateOnSubmit || _validateEmailOnBlur;
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

  void _handleEmailFocusChange() {
    if (_emailFocusNode.hasFocus) {
      return;
    }

    _trimEmail();
    if (!_validateEmailOnBlur) {
      setState(() => _validateEmailOnBlur = true);
    }
    _emailFormKey.currentState?.validate();
  }

  void _handlePhoneFocusChange() {
    if (_phoneFocusNode.hasFocus) {
      return;
    }
    _phoneFormKey.currentState?.validate();
  }

  String? _validateEmail(String? value) {
    if (!_shouldValidateEmail) {
      return null;
    }

    final cleaned = (value ?? '').trim();
    if (!_emailRegex.hasMatch(cleaned)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    _trimEmail();

    if (!_validateOnSubmit) {
      setState(() => _validateOnSubmit = true);
    }

    final isEmailValid = _emailFormKey.currentState?.validate() ?? false;
    final isPhoneValid = _phoneFormKey.currentState?.validate() ?? false;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _fullPhoneNumber.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields.')),
      );
      return;
    }

    if (!isEmailValid || !isPhoneValid || phone.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref
          .read(clientsControllerProvider.notifier)
          .addClient(name: name, email: email, phone: phone);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Client')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          AppInputField(controller: _nameController, label: 'Client Name'),
          const SizedBox(height: 12),
          Form(
            key: _emailFormKey,
            child: TextFormField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: _validateEmail,
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _phoneFormKey,
            child: IntlPhoneField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              initialCountryCode: _initialCountryCode,
              autovalidateMode: AutovalidateMode.disabled,
              keyboardType: TextInputType.phone,
              invalidNumberMessage: 'Enter a valid phone number',
              decoration: const InputDecoration(
                labelText: 'Phone',
                counterText: '',
              ),
              onChanged: (phone) {
                _fullPhoneNumber = phone.completeNumber.trim();
              },
              onCountryChanged: (country) {
                final localNumber = _phoneController.text.trim();
                _fullPhoneNumber = localNumber.isEmpty
                    ? ''
                    : '+${country.fullCountryCode}$localNumber';
              },
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Save Client',
            isLoading: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
