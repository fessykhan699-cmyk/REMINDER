import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/onboarding_local_datasource.dart';
import '../../data/repositories/onboarding_repository_impl.dart';
import '../../domain/entities/onboarding_page.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../../domain/usecases/complete_onboarding_usecase.dart';

class OnboardingState {
  const OnboardingState({
    required this.pages,
    required this.currentIndex,
    required this.isLoading,
  });

  factory OnboardingState.initial() {
    return const OnboardingState(pages: [], currentIndex: 0, isLoading: true);
  }

  final List<OnboardingPageEntity> pages;
  final int currentIndex;
  final bool isLoading;

  bool get isLastPage => pages.isNotEmpty && currentIndex == pages.length - 1;

  OnboardingState copyWith({
    List<OnboardingPageEntity>? pages,
    int? currentIndex,
    bool? isLoading,
  }) {
    return OnboardingState(
      pages: pages ?? this.pages,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final onboardingLocalDatasourceProvider = Provider<OnboardingLocalDatasource>(
  (ref) => OnboardingLocalDatasource(),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) =>
      OnboardingRepositoryImpl(ref.watch(onboardingLocalDatasourceProvider)),
);

final completeOnboardingUseCaseProvider = Provider<CompleteOnboardingUseCase>(
  (ref) => CompleteOnboardingUseCase(ref.watch(authRepositoryProvider)),
);

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends Notifier<OnboardingState> {
  bool _didLoad = false;

  @override
  OnboardingState build() {
    if (!_didLoad) {
      _didLoad = true;
      Future<void>(_loadPages);
    }
    return OnboardingState.initial();
  }

  Future<void> _loadPages() async {
    final pages = await ref.read(onboardingRepositoryProvider).getPages();

    state = state.copyWith(pages: pages, isLoading: false);
  }

  void setPage(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void nextPage() {
    if (state.currentIndex >= state.pages.length - 1) {
      return;
    }
    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }
}
