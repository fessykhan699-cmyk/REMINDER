import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
import '../../domain/entities/profile.dart';
import '../controllers/settings_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String _logoPath = '';
  String _signaturePath = '';
  bool _didHydrate = false;
  bool _isSaving = false;
  bool _isPickingLogo = false;
  bool _isPickingSignature = false;
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
    _logoPath = profile.logoPath;
    _signaturePath = profile.signaturePath;
  }

  String _normalizedPhoneValue([String? rawValue]) {
    final trimmed = (rawValue ?? _phoneController.text).trim();
    if (trimmed.isEmpty) {
      return '';
    }

    return '+${trimmed.replaceFirst(RegExp(r'^\+'), '')}';
  }

  Future<void> _pickBrandAsset({required bool isSignature}) async {
    final decision = await ref
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.premiumBranding);
    if (!decision.isAllowed) {
      if (!mounted) {
        return;
      }
      await promptUpgradeForDecision(context, decision);
      return;
    }

    setState(() {
      if (isSignature) {
        _isPickingSignature = true;
      } else {
        _isPickingLogo = true;
      }
    });

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 1600,
      );
      if (pickedFile == null || !mounted) {
        return;
      }

      final persistedPath = await _persistBrandAsset(
        pickedFile,
        baseName: isSignature ? 'signature' : 'logo',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (isSignature) {
          _signaturePath = persistedPath;
        } else {
          _logoPath = persistedPath;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open image picker right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (isSignature) {
            _isPickingSignature = false;
          } else {
            _isPickingLogo = false;
          }
        });
      }
    }
  }

  Future<String> _persistBrandAsset(
    XFile file, {
    required String baseName,
  }) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final assetDirectory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}brand_assets',
    );
    if (!await assetDirectory.exists()) {
      await assetDirectory.create(recursive: true);
    }

    final extension = _fileExtension(file.path);
    final targetPath =
        '${assetDirectory.path}${Platform.pathSeparator}$baseName$extension';
    await File(file.path).copy(targetPath);
    return targetPath;
  }

  String _fileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot < 0 || lastDot == path.length - 1) {
      return '.png';
    }

    return path.substring(lastDot);
  }

  void _clearBrandAsset({required bool isSignature}) {
    setState(() {
      if (isSignature) {
        _signaturePath = '';
      } else {
        _logoPath = '';
      }
    });
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
      logoPath: _logoPath.trim(),
      signaturePath: _signaturePath.trim(),
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
    final subscription = ref.watch(subscriptionControllerProvider).valueOrNull;
    final isPro = subscription?.isPro ?? false;
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
          return SafeArea(
            child: ListView(
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
                        const SizedBox(height: 16),
                        _BrandAssetField(
                          label: 'Brand Logo',
                          helper: isPro
                              ? 'Used on Pro invoices. Falls back to the app logo if empty.'
                              : 'Pro only. Upgrade to use your own logo on invoices.',
                          assetPath: _logoPath,
                          isLoading: _isPickingLogo,
                          emptyLabel: 'No logo selected',
                          onPick: () => _pickBrandAsset(isSignature: false),
                          onClear: _logoPath.trim().isEmpty
                              ? null
                              : () => _clearBrandAsset(isSignature: false),
                        ),
                        const SizedBox(height: 16),
                        _BrandAssetField(
                          label: 'Authorized Signature',
                          helper: isPro
                              ? 'Optional signature image for Pro invoices.'
                              : 'Pro only. Upgrade to add a signature block to invoices.',
                          assetPath: _signaturePath,
                          isLoading: _isPickingSignature,
                          emptyLabel: 'No signature selected',
                          onPick: () => _pickBrandAsset(isSignature: true),
                          onClear: _signaturePath.trim().isEmpty
                              ? null
                              : () => _clearBrandAsset(isSignature: true),
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
            ),
          );
        },
      ),
    );
  }
}

class _BrandAssetField extends StatelessWidget {
  const _BrandAssetField({
    required this.label,
    required this.helper,
    required this.assetPath,
    required this.isLoading,
    required this.emptyLabel,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final String helper;
  final String assetPath;
  final bool isLoading;
  final String emptyLabel;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedPath = assetPath.trim();
    final file = normalizedPath.isEmpty ? null : File(normalizedPath);
    final hasPreview = file?.existsSync() ?? false;

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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasPreview)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    file!,
                    height: 72,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Text(
                  emptyLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                helper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : onPick,
                      icon: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_outlined),
                      label: Text(hasPreview ? 'Replace' : 'Upload'),
                    ),
                  ),
                  if (onClear != null) ...[
                    const SizedBox(width: 12),
                    TextButton(onPressed: onClear, child: const Text('Clear')),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
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
