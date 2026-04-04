import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';

Future<String?> showPinEditorSheet(
  BuildContext context, {
  required String title,
  required String submitLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _PinEditorSheet(title: title, submitLabel: submitLabel),
  );
}

class _PinEditorSheet extends StatefulWidget {
  const _PinEditorSheet({required this.title, required this.submitLabel});

  final String title;
  final String submitLabel;

  @override
  State<_PinEditorSheet> createState() => _PinEditorSheetState();
}

class _PinEditorSheetState extends State<_PinEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_autovalidateMode == AutovalidateMode.disabled) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(_pinController.text.trim());
  }

  String? _validatePin(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 4 || trimmed.length > 6) {
      return 'Use 4 to 6 digits.';
    }
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'PIN must contain digits only.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets.bottom),
        child: GlassCard(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              autovalidateMode: _autovalidateMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a 4 to 6 digit PIN for app lock.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(labelText: 'PIN'),
                    validator: _validatePin,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(labelText: 'Confirm PIN'),
                    validator: (value) {
                      final pinError = _validatePin(value);
                      if (pinError != null) {
                        return pinError;
                      }
                      if (value?.trim() != _pinController.text.trim()) {
                        return 'PINs do not match.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: widget.submitLabel,
                    icon: Icons.save_outlined,
                    onPressed: _submit,
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
