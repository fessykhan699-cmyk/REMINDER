import '../entities/onboarding_page.dart';

abstract interface class OnboardingRepository {
  Future<List<OnboardingPageEntity>> getPages();
}
