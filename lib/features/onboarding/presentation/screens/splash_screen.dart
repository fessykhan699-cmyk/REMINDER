import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    String statusLabel;
    switch (authState.status) {
      case AuthStatus.initializing:
        statusLabel = 'Preparing secure workspace...';
      case AuthStatus.authenticated:
        statusLabel = 'Opening dashboard...';
      case AuthStatus.unauthenticated:
        statusLabel = 'Checking onboarding state...';
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.payments_rounded, size: 44),
              const SizedBox(height: 12),
              Text(
                'Invoice Reminder',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 12),
              Text(statusLabel),
            ],
          ),
        ),
      ),
    );
  }
}
