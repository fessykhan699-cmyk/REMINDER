import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

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
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

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
    final theme = Theme.of(context);

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
      appBar: AppBar(
        title: const Text('Send Reminder'),
        leading: IconButton(
          icon: const Icon(RemixIcons.arrow_left_line),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: invoice == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(spacingXL),
                child: Text(state.errorMessage ?? 'Preparing reminder...'),
              ),
            )
          : SafeArea(
              child: ListView(
                padding: EdgeInsets.only(
                  left: spacingMD,
                  right: spacingMD,
                  top: spacingSM,
                  bottom: MediaQuery.of(context).padding.bottom + 100,
                ),
                children: [
                  _staggeredItem(
                    index: 0,
                    child: GlassCard(
                      padding: const EdgeInsets.all(spacingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(spacingSM),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  RemixIcons.bill_line,
                                  size: 18,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: spacingSM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Invoice #${invoice.id}',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      invoice.clientName,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: spacingLG),
                  _staggeredItem(
                    index: 1,
                    child: Text(
                      'Choose Tone',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: spacingSM),
                  _staggeredItem(
                    index: 2,
                    child: Wrap(
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
                  ),
                  const SizedBox(height: spacingLG),
                  _staggeredItem(
                    index: 3,
                    child: GlassCard(
                      padding: const EdgeInsets.all(spacingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                RemixIcons.chat_quote_line,
                                size: 16,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Message Preview',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: spacingMD),
                          Container(
                            padding: const EdgeInsets.all(spacingMD),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              state.previewMessage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textPrimary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: spacingXL),
                  _staggeredItem(
                    index: 4,
                    child: PrimaryButton(
                      label: 'Send on WhatsApp',
                      icon: RemixIcons.whatsapp_line,
                      isLoading: state.isSending,
                      onPressed: canSendWhatsapp
                          ? () async {
                              try {
                                await controller.sendReminder(
                                  ReminderChannel.whatsapp,
                                );
                              } on SubscriptionGateException catch (error) {
                                if (!context.mounted) return;
                                final upgraded = await promptUpgradeForDecision(
                                  context,
                                  error.decision,
                                );
                                if (!upgraded || !context.mounted) return;
                                await controller.sendReminder(
                                  ReminderChannel.whatsapp,
                                );
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(height: spacingMD),
                  _staggeredItem(
                    index: 5,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: spacingMD),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: canSendSms
                          ? () async {
                              await controller.sendReminder(ReminderChannel.sms);
                            }
                          : null,
                      icon: const Icon(RemixIcons.message_3_line, size: 20),
                      label: const Text('Send via SMS'),
                    ),
                  ),
                  const SizedBox(height: spacingLG),
                  _staggeredItem(
                    index: 6,
                    child: Container(
                      padding: const EdgeInsets.all(spacingMD),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            RemixIcons.information_line,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: spacingSM),
                          Expanded(
                            child: Text(
                              helperText ?? '3-tap flow: tone -> preview -> send.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _staggeredItem({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
