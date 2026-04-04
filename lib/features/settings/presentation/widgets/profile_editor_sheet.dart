import 'package:flutter/material.dart';

import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';
import '../../domain/entities/profile.dart';

Future<UserProfile?> showUserProfileEditorSheet(
  BuildContext context, {
  required UserProfile initialProfile,
  required String title,
  required String submitLabel,
}) {
  return showModalBottomSheet<UserProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _UserProfileEditorSheet(
      initialProfile: initialProfile,
      title: title,
      submitLabel: submitLabel,
    ),
  );
}

class _UserProfileEditorSheet extends StatefulWidget {
  const _UserProfileEditorSheet({
    required this.initialProfile,
    required this.title,
    required this.submitLabel,
  });

  final UserProfile initialProfile;
  final String title;
  final String submitLabel;

  @override
  State<_UserProfileEditorSheet> createState() =>
      _UserProfileEditorSheetState();
}

class _UserProfileEditorSheetState extends State<_UserProfileEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _businessNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _emailController = TextEditingController(text: widget.initialProfile.email);
    _businessNameController = TextEditingController(
      text: widget.initialProfile.businessName,
    );
    _phoneController = TextEditingController(
      text: widget.initialProfile.phone.isEmpty
          ? '+'
          : widget.initialProfile.phone,
    );
    _addressController = TextEditingController(
      text: widget.initialProfile.address,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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

    Navigator.of(context).pop(
      UserProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        businessName: _businessNameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hintText}) {
    return InputDecoration(labelText: label, hintText: hintText);
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration('Name', hintText: 'Your name'),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _businessNameController,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      'Business Name',
                      hintText: 'Your business name',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Business name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      'Email',
                      hintText: 'owner@business.com',
                    ),
                    validator: (value) {
                      if (!UserProfile.isValidEmail(value ?? '')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      'Phone',
                      hintText: '+1 555 123 4567',
                    ),
                    validator: (value) {
                      if (!UserProfile.hasValidInternationalPhone(value ?? '')) {
                        return 'Use a phone number with country code.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    keyboardType: TextInputType.streetAddress,
                    textInputAction: TextInputAction.done,
                    maxLines: 2,
                    decoration: _decoration(
                      'Address',
                      hintText: 'Business address (optional)',
                    ),
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
