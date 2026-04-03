import 'package:flutter/material.dart';

import '../../domain/entities/onboarding_page.dart';

class OnboardingPageCard extends StatelessWidget {
  const OnboardingPageCard({super.key, required this.page});

  final OnboardingPageEntity page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.2),
            child: Icon(
              page.icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(page.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(page.subtitle, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
