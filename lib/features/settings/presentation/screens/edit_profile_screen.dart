import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';
import '../../domain/entities/profile.dart';
import '../controllers/settings_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _didHydrate = false;
  bool _isSaving = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile profile) {
    if (_didHydrate) {
      return;
    }
    _didHydrate = true;
    _nameController.text = profile.name;
    _emailController.text = profile.email;
    _businessNameController.text = profile.businessName;
    _phoneController.text = profile.phone.trim().replaceFirst(
      RegExp(r'^\+'),
      '',
    );
    _addressController.text = profile.address;
  }

  String _normalizedPhoneValue([String? rawValue]) {
    final trimmed = (rawValue ?? _phoneController.text).trim();
    if (trimmed.isEmpty) {
      return '';
    }

    return '+${trimmed.replaceFirst(RegExp(r'^\+'), '')}';
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    final profile = UserProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      businessName: _businessNameController.text.trim(),
      phone: _normalizedPhoneValue(),
      address: _addressController.text.trim(),
    );
    var shouldResetSavingState = true;

    try {
      await ref.read(settingsControllerProvider.notifier).saveProfile(profile);
      if (!mounted) {
        return;
      }

      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      shouldResetSavingState = false;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save the profile right now.')),
      );
    } finally {
      if (mounted && shouldResetSavingState) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _decoration({
    String? hintText,
    String? prefixText,
    int? maxLines,
  }) {
    OutlineInputBorder border(Color color) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color),
      );
    }

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
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
  Widget build(BuildContext context) {
    final profileState = ref.watch(settingsControllerProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 380 ? 16.0 : 20.0;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (profile) {
          _hydrate(profile);
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              bottomPadding,
            ),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autovalidateMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Profile',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Keep your billing details current for invoices and exports.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ProfileField(
                        label: 'Name',
                        child: TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: _decoration(hintText: 'John Doe'),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Name is required.'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileField(
                        label: 'Business Name',
                        child: TextFormField(
                          controller: _businessNameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: _decoration(
                            hintText: 'Studio Ledger Co.',
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Business name is required.'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileField(
                        label: 'Email',
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: _decoration(
                            hintText: 'name@business.com',
                          ),
                          validator: (value) =>
                              UserProfile.isValidEmail(value ?? '')
                              ? null
                              : 'Enter a valid email address.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileField(
                        label: 'Phone',
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: _decoration(
                            hintText: '1 555 123 4567',
                            prefixText: '+ ',
                          ),
                          validator: (value) =>
                              UserProfile.hasValidInternationalPhone(
                                _normalizedPhoneValue(value),
                              )
                              ? null
                              : 'Use a phone number with country code.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileField(
                        label: 'Address',
                        child: TextFormField(
                          controller: _addressController,
                          keyboardType: TextInputType.streetAddress,
                          maxLines: 2,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: _decoration(
                            hintText: 'Business address',
                            maxLines: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Save Profile',
                        icon: Icons.save_outlined,
                        isLoading: _isSaving,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.child});

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
          style: theme.textTheme.bodySmall?.copyWith(
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
