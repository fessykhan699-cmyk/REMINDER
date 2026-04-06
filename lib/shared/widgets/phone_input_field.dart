import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../components/glass_card.dart';

/// Reusable phone input field with country code selector.
///
/// Stores full phone as: countryCode + number (e.g. "+971503388541")
class PhoneInputField extends StatefulWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    this.hintText = '50 123 4567',
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSaved,
    this.onFullPhoneChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String?)? onSaved;
  final ValueChanged<String>? onFullPhoneChanged;

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  String _selectedCountryCode = '+971';

  static const List<_CountryCodeOption> _countryCodes = [
    _CountryCodeOption(code: '+1', label: 'US/CA', flag: '🇺🇸'),
    _CountryCodeOption(code: '+44', label: 'UK', flag: '🇬🇧'),
    _CountryCodeOption(code: '+971', label: 'UAE', flag: '🇦🇪'),
    _CountryCodeOption(code: '+91', label: 'India', flag: '🇮🇳'),
    _CountryCodeOption(code: '+966', label: 'Saudi', flag: '🇸🇦'),
    _CountryCodeOption(code: '+974', label: 'Qatar', flag: '🇶🇦'),
    _CountryCodeOption(code: '+965', label: 'Kuwait', flag: '🇰🇼'),
    _CountryCodeOption(code: '+968', label: 'Oman', flag: '🇴🇲'),
    _CountryCodeOption(code: '+973', label: 'Bahrain', flag: '🇧🇭'),
    _CountryCodeOption(code: '+49', label: 'Germany', flag: '🇩🇪'),
    _CountryCodeOption(code: '+33', label: 'France', flag: '🇫🇷'),
    _CountryCodeOption(code: '+61', label: 'Australia', flag: '🇦🇺'),
    _CountryCodeOption(code: '+86', label: 'China', flag: '🇨🇳'),
    _CountryCodeOption(code: '+92', label: 'Pakistan', flag: '🇵🇰'),
    _CountryCodeOption(code: '+63', label: 'Philippines', flag: '🇵🇭'),
  ];

  @override
  void initState() {
    super.initState();
    final parsed = _parsePhone(widget.controller.text);
    _selectedCountryCode = parsed.$1;
    widget.controller.text = parsed.$2;
    widget.controller.addListener(_notifyFullPhone);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_notifyFullPhone);
    super.dispose();
  }

  void _notifyFullPhone() {
    widget.onFullPhoneChanged?.call(_fullPhone());
  }

  (String countryCode, String number) _parsePhone(String phone) {
    if (phone.isEmpty) return ('+971', '');
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    for (final option in _countryCodes) {
      final codeDigits = option.code.startsWith('+')
          ? option.code.substring(1)
          : option.code;
      if (digits.startsWith(codeDigits)) {
        return (option.code, digits.substring(codeDigits.length));
      }
    }
    return ('+971', digits);
  }

  String _fullPhone() {
    final number = widget.controller.text.trim();
    if (number.isEmpty) return '';
    final code = _selectedCountryCode.startsWith('+')
        ? _selectedCountryCode
        : '+$_selectedCountryCode';
    return '$code${number.replaceFirst(RegExp(r'^\+'), '')}';
  }

  Future<void> _openPicker() async {
    final selected = await showModalBottomSheet<_CountryCodeOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.65,
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Country Code',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _countryCodes.length,
                      itemBuilder: (listContext, index) {
                        final option = _countryCodes[index];
                        return InkWell(
                          onTap: () => Navigator.of(listContext).pop(option),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  option.flag,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  option.code,
                                  style: Theme.of(listContext)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  option.label,
                                  style: Theme.of(listContext)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                                const Spacer(),
                                if (option.code == _selectedCountryCode)
                                  const Icon(
                                    Icons.check,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                              ],
                            ),
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
      },
    );

    if (selected != null && selected.code != _selectedCountryCode) {
      setState(() {
        _selectedCountryCode = selected.code;
        _notifyFullPhone();
      });
    }
  }

  InputDecoration _decoration() {
    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color),
      );
    }

    return InputDecoration(
      hintText: widget.hintText,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefix: GestureDetector(
        onTap: _openPicker,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCountryCode,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.glassBorder),
      enabledBorder: border(AppColors.glassBorder),
      focusedBorder: border(AppColors.accent.withValues(alpha: 0.55)),
      errorBorder: border(AppColors.danger.withValues(alpha: 0.65)),
      focusedErrorBorder: border(AppColors.danger.withValues(alpha: 0.85)),
    );
  }

  @override
  void didUpdateWidget(covariant PhoneInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      final parsed = _parsePhone(widget.controller.text);
      setState(() {
        _selectedCountryCode = parsed.$1;
        widget.controller.text = parsed.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      textAlignVertical: TextAlignVertical.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _decoration(),
      validator: widget.validator != null
          ? (value) => widget.validator!(_fullPhone())
          : null,
      onSaved: widget.onSaved != null
          ? (_) => widget.onSaved!(_fullPhone())
          : null,
    );
  }
}

class _CountryCodeOption {
  const _CountryCodeOption({
    required this.code,
    required this.label,
    required this.flag,
  });

  final String code;
  final String label;
  final String flag;
}
