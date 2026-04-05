import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/widgets/app_failure_state.dart';
import '../../domain/entities/client.dart';
import '../controllers/clients_controller.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _didHydrate = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  OutlineInputBorder _buildBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
  }

  InputDecoration _buildInputDecoration(ThemeData theme, {String? hintText}) {
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
    );
  }

  void _hydrateClient(Client client) {
    if (_didHydrate) {
      return;
    }

    _nameController.text = client.name;
    _emailController.text = client.email;
    _phoneController.text = client.phone;
    _didHydrate = true;
  }

  String? _validateName(String? value) {
    if ((value?.trim() ?? '').isEmpty) {
      return 'Name required';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (!Client.isValidEmail((value ?? '').trim())) {
      return 'Email invalid';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    if (!Client.hasValidInternationalPhone((value ?? '').trim())) {
      return 'Phone invalid';
    }

    return null;
  }

  Future<void> _saveClient(Client existingClient) async {
    if (_isSaving || _isDeleting) {
      return;
    }

    if (_autovalidateMode == AutovalidateMode.disabled) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() => _isSaving = true);
    var shouldResetSavingState = true;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(clientsControllerProvider.notifier);

    try {
      await controller.updateClient(
        existingClient.copyWith(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
        ),
      );

      if (!mounted) {
        return;
      }

      shouldResetSavingState = false;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Client updated successfully.')),
      );
    } on ValidationException catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.message == 'Client not found.') {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('This client is no longer available.')),
        );
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Failed to update client ${existingClient.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save client')),
      );
    } finally {
      if (mounted && shouldResetSavingState) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteClient(Client client) async {
    if (_isSaving || _isDeleting) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete client?'),
          content: Text('Remove ${client.name} from your saved clients?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);
    var shouldResetDeletingState = true;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(clientsControllerProvider.notifier);

    try {
      await controller.deleteClient(client.id);

      if (!mounted) {
        return;
      }

      shouldResetDeletingState = false;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${client.name} deleted.')),
      );
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Failed to delete client ${client.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to delete client')),
      );
    } finally {
      if (mounted && shouldResetDeletingState) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientState = ref.watch(clientDetailProvider(widget.clientId));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Client')),
      body: clientState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => AppFailureState(
          message: error.toString(),
          onRetry: () => ref.invalidate(clientDetailProvider(widget.clientId)),
        ),
        data: (client) {
          if (client == null) {
            return _MissingClientState(
              onBack: () {
                Navigator.of(context).maybePop();
              },
              onRetry: () {
                ref.invalidate(clientDetailProvider(widget.clientId));
              },
            );
          }

          _hydrateClient(client);
          final theme = Theme.of(context);
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

          return SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 20, 20, 120 + bottomInset),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autovalidateMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailField(
                        label: 'Client Name',
                        child: TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          cursorColor: AppColors.accent,
                          decoration: _buildInputDecoration(
                            theme,
                            hintText: 'Acme Studio',
                          ),
                          validator: _validateName,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DetailField(
                        label: 'Email',
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          cursorColor: AppColors.accent,
                          decoration: _buildInputDecoration(
                            theme,
                            hintText: 'client@business.com',
                          ),
                          validator: _validateEmail,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DetailField(
                        label: 'Phone',
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          cursorColor: AppColors.accent,
                          decoration: _buildInputDecoration(
                            theme,
                            hintText: '+1555010100',
                          ),
                          validator: _validatePhone,
                          onFieldSubmitted: (_) async {
                            await _saveClient(client);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Created At'),
                        subtitle: Text(
                          AppFormatters.shortDate(client.createdAt),
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Save Changes',
                        isLoading: _isSaving,
                        onPressed: () async {
                          await _saveClient(client);
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSaving || _isDeleting
                              ? null
                              : () async {
                                  await _deleteClient(client);
                                },
                          icon: _isDeleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete Client'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.child});

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

class _MissingClientState extends StatelessWidget {
  const _MissingClientState({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_off_outlined,
              color: AppColors.textMuted,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              'Client unavailable',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This client may have been removed or is no longer available locally.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(height: 8),
            TextButton(onPressed: onBack, child: const Text('Back to Clients')),
          ],
        ),
      ),
    );
  }
}
