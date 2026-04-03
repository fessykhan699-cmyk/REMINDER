import 'package:flutter/material.dart';

import '../../../../shared/components/glass_card.dart';

class SmartReminderCard extends StatelessWidget {
  const SmartReminderCard({
    super.key,
    required this.message,
    required this.onAction,
    this.enabled = true,
  });

  final String message;
  final VoidCallback onAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Reminder',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: enabled ? onAction : null,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send Suggested Reminder'),
          ),
        ],
      ),
    );
  }
}
