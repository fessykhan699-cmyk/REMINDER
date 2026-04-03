import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/widgets/app_failure_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../invoices/presentation/controllers/invoice_creation_learning_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/settings_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final quickCreateSettings = ref.watch(invoiceCreationLearningProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => AppFailureState(
          message: error.toString(),
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
        data: (profile) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(profile.email),
                    const SizedBox(height: 2),
                    Text(profile.businessName),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SettingsTile(
                title: 'Notifications',
                subtitle: 'Reminder channels and behavior',
                trailing: Icon(Icons.chevron_right),
              ),
              const SettingsTile(
                title: 'Security',
                subtitle: 'Session and account security',
                trailing: Icon(Icons.chevron_right),
              ),
              SettingsTile(
                title: 'Open Quick Invoice Details',
                subtitle: quickCreateSettings.openDetailAfterQuickCreate
                    ? 'One-tap invoices open the detail view after creation.'
                    : 'One-tap invoices stay in place and show undo feedback only.',
                trailing: Switch.adaptive(
                  value: quickCreateSettings.openDetailAfterQuickCreate,
                  onChanged: (value) {
                    ref
                        .read(invoiceCreationLearningProvider.notifier)
                        .setOpenDetailAfterQuickCreate(value);
                  },
                ),
                onTap: () {
                  ref
                      .read(invoiceCreationLearningProvider.notifier)
                      .setOpenDetailAfterQuickCreate(
                        !quickCreateSettings.openDetailAfterQuickCreate,
                      );
                },
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Logout',
                icon: Icons.logout,
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
          );
        },
      ),
    );
  }
}
