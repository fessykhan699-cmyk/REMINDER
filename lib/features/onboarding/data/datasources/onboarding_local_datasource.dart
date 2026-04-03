import 'package:flutter/material.dart';

import '../models/onboarding_page_model.dart';

class OnboardingLocalDatasource {
  Future<List<OnboardingPageModel>> getPages() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    return const [
      OnboardingPageModel(
        title: 'Track Every Invoice',
        subtitle: 'Create, edit, and monitor payment status in one clear feed.',
        cta: 'Next',
        icon: Icons.receipt_long_rounded,
      ),
      OnboardingPageModel(
        title: 'Remind in 3 Taps',
        subtitle:
            'Pick tone, preview the message, send through WhatsApp or SMS.',
        cta: 'Next',
        icon: Icons.notifications_active_rounded,
      ),
      OnboardingPageModel(
        title: 'Get Paid Faster',
        subtitle: 'Use smart reminders to recover overdue cash flow quickly.',
        cta: 'Get started',
        icon: Icons.trending_up_rounded,
      ),
    ];
  }
}
