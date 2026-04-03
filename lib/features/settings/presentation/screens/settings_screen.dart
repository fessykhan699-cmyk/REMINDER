import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/widgets/app_failure_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/settings_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);

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
