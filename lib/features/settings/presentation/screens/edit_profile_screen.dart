import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    _phoneController.text = profile.phone.isEmpty ? '+' : profile.phone;
    _addressController.text = profile.address;
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
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
    );
    await ref.read(settingsControllerProvider.notifier).saveProfile(profile);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
  }

  InputDecoration _decoration(String label, {String? hintText}) {
    OutlineInputBorder border() {
      return OutlineInputBorder(borderRadius: BorderRadius.circular(14));
    }

    return InputDecoration(
      labelText: label,
      hintText: hintText,
      border: border(),
      enabledBorder: border(),
      focusedBorder: border(),
      errorBorder: border(),
      focusedErrorBorder: border(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (profile) {
          _hydrate(profile);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                        'Profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration('Name'),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Name is required.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _businessNameController,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration('Business Name'),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Business name is required.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration('Email'),
                        validator: (value) =>
                            UserProfile.isValidEmail(value ?? '')
                            ? null
                            : 'Enter a valid email address.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration('Phone'),
                        validator: (value) =>
                            UserProfile.hasValidInternationalPhone(value ?? '')
                            ? null
                            : 'Use a phone number with country code.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        keyboardType: TextInputType.streetAddress,
                        maxLines: 2,
                        decoration: _decoration('Address'),
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
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
