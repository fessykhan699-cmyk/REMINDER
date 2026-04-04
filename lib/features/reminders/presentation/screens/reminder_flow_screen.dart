import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../settings/presentation/controllers/app_preferences_controller.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
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
    final preferences = ref.watch(appPreferencesControllerProvider).valueOrNull;
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
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
    final whatsappEnabled = preferences?.whatsAppRemindersEnabled ?? true;
    final smsEnabled = preferences?.smsRemindersEnabled ?? true;
    final canSendWhatsapp =
        !state.isSending && state.canSendReminder && whatsappEnabled;
    final canSendSms = !state.isSending && state.canSendReminder && smsEnabled;
    final helperText = !state.canSendReminder
        ? 'Add a valid client phone number to send reminders.'
        : !whatsappEnabled && !smsEnabled
        ? 'Enable WhatsApp or SMS reminders in Settings.'
        : !subscription.isPro
        ? 'WhatsApp sharing is available on Pro. SMS remains available on Free.'
        : null;

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
                  onPressed: canSendWhatsapp
                      ? () async {
                          try {
                            await controller.sendReminder(
                              ReminderChannel.whatsapp,
                            );
                          } on SubscriptionGateException catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            final upgraded = await promptUpgradeForDecision(
                              context,
                              error.decision,
                            );
                            if (!upgraded || !context.mounted) {
                              return;
                            }
                            await controller.sendReminder(
                              ReminderChannel.whatsapp,
                            );
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: canSendSms
                      ? () async {
                          await controller.sendReminder(ReminderChannel.sms);
                        }
                      : null,
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Send via SMS'),
                ),
                const SizedBox(height: 12),
                Text(
                  helperText ?? '3-tap flow: tone -> preview -> send.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
