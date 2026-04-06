import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/app_feedback_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'features/settings/presentation/widgets/app_lock_gate.dart';
import 'features/subscription/presentation/controllers/play_billing_controller.dart';
import 'features/subscription/presentation/controllers/subscription_controller.dart';

class InvoiceReminderApp extends ConsumerWidget {
  const InvoiceReminderApp({
    super.key,
    this.scaffoldBackgroundColor = const Color(0xFF0F1115),
  });

  final Color scaffoldBackgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(subscriptionControllerProvider, (previous, next) {});
    ref.listen(playBillingControllerProvider, (previous, next) {});

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Invoice Reminder',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppFeedbackService.scaffoldMessengerKey,
      themeMode: ThemeMode.dark,
      theme: AppTheme.darkTheme.copyWith(
        scaffoldBackgroundColor: scaffoldBackgroundColor,
      ),
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        return AppLockGate(child: child);
      },
      routerConfig: router,
    );
  }
}
