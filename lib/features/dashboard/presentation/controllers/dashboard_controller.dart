import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../invoices/presentation/controllers/invoices_controller.dart';
import '../../data/datasources/dashboard_local_datasource.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_summary_usecase.dart';

final dashboardLocalDatasourceProvider = Provider<DashboardLocalDatasource>(
  (ref) => DashboardLocalDatasource(),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(
    invoiceRepository: ref.watch(invoiceRepositoryProvider),
    localDatasource: ref.watch(dashboardLocalDatasourceProvider),
  ),
);

final getDashboardSummaryUseCaseProvider = Provider<GetDashboardSummaryUseCase>(
  (ref) => GetDashboardSummaryUseCase(ref.watch(dashboardRepositoryProvider)),
);

final dashboardControllerProvider =
    AutoDisposeNotifierProvider<
      DashboardController,
      AsyncValue<DashboardSummary>
    >(DashboardController.new);

class DashboardController
    extends AutoDisposeNotifier<AsyncValue<DashboardSummary>> {
  @override
  AsyncValue<DashboardSummary> build() {
    Future<void>(load);
    return const AsyncValue.loading();
  }

  Future<void> load() async {
    state = await AsyncValue.guard(
      () => ref.read(getDashboardSummaryUseCaseProvider).call(),
    );
  }
}
