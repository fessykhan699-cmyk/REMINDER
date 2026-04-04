import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/reminder_message_type.dart';
import '../controllers/reminders_controller.dart';
import '../widgets/reminder_type_chip.dart';

class ReminderFlowScreen extends ConsumerWidget {
  const ReminderFlowScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reminderFlowControllerProvider(invoiceId));
    final controller = ref.read(
      reminderFlowControllerProvider(invoiceId).notifier,
    );

    ref.listen(reminderFlowControllerProvider(invoiceId), (previous, next) {
      if (next.successMessage != null &&
          previous?.successMessage != next.successMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.successMessage!)));
      }

      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    final invoice = state.invoice;

    return Scaffold(
      appBar: AppBar(title: const Text('Reminder Flow')),
      body: invoice == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                child: Text(state.errorMessage ?? 'Preparing reminder...'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Text(
                  'Invoice ${invoice.id} • ${invoice.clientName}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ReminderMessageType.values
                      .map(
                        (type) => ReminderTypeChip(
                          label: type.label,
                          selected: state.messageType == type,
                          onTap: () => controller.selectMessageType(type),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message Preview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(state.previewMessage),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Send on WhatsApp',
                  icon: Icons.chat_bubble_outline,
                  isLoading: state.isSending,
                  onPressed: state.isSending || !state.canSendReminder
                      ? null
                      : () => controller.sendReminder(ReminderChannel.whatsapp),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: state.isSending || !state.canSendReminder
                      ? null
                      : () => controller.sendReminder(ReminderChannel.sms),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Send via SMS'),
                ),
                const SizedBox(height: 12),
                Text(
                  '3-tap flow: tone -> preview -> send.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
