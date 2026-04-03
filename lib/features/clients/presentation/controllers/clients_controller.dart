import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/adaptive/adaptive_system_controller.dart';
import '../../data/datasources/clients_local_datasource.dart';
import '../../data/repositories/client_repository_impl.dart';
import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../../domain/usecases/add_client_usecase.dart';
import '../../domain/usecases/get_clients_usecase.dart';

final clientsLocalDatasourceProvider = Provider<ClientsLocalDatasource>(
  (ref) => ClientsLocalDatasource(),
);

final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => ClientRepositoryImpl(ref.watch(clientsLocalDatasourceProvider)),
);

final getClientsUseCaseProvider = Provider<GetClientsUseCase>(
  (ref) => GetClientsUseCase(ref.watch(clientRepositoryProvider)),
);

final addClientUseCaseProvider = Provider<AddClientUseCase>(
  (ref) => AddClientUseCase(ref.watch(clientRepositoryProvider)),
);

final clientsControllerProvider =
    NotifierProvider<ClientsController, AsyncValue<List<Client>>>(
      ClientsController.new,
    );

final clientDetailProvider = FutureProvider.family<Client?, String>((ref, id) {
  return ref.watch(clientRepositoryProvider).getClientById(id);
});

class ClientsController extends Notifier<AsyncValue<List<Client>>> {
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;

  @override
  AsyncValue<List<Client>> build() {
    Future<void>(loadInitial);
    return const AsyncValue.loading();
  }

  Future<void> loadInitial() async {
    _currentPage = 1;
    _hasMore = true;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(getClientsUseCaseProvider)
          .call(page: 1, pageSize: AppConstants.defaultPageSize),
    );
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || state.isLoading) {
      return;
    }

    _isLoadingMore = true;

    try {
      final current = state.valueOrNull ?? const <Client>[];
      final nextPage = _currentPage + 1;
      final next = await ref
          .read(getClientsUseCaseProvider)
          .call(page: nextPage, pageSize: AppConstants.defaultPageSize);

      if (next.isEmpty) {
        _hasMore = false;
      } else {
        _currentPage = nextPage;
        state = AsyncValue.data([...current, ...next]);
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<Client> addClient({
    required String name,
    required String email,
    required String phone,
  }) async {
    final client = Client(
      id: IdGenerator.nextId('client'),
      name: name,
      email: email,
      phone: phone,
      createdAt: DateTime.now(),
    );

    final created = await ref.read(addClientUseCaseProvider).call(client);
    final current = state.valueOrNull ?? const <Client>[];
    state = AsyncValue.data([created, ...current]);
    await ref
        .read(adaptiveSystemProvider.notifier)
        .recordAction(AdaptiveActionKey.addClient);
    return created;
  }
}
