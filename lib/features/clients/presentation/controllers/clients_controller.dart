import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../data/providers/firestore_sync_provider.dart';
import '../../../../data/services/workspace/workspace_provider.dart';
import '../../../../shared/adaptive/adaptive_system_controller.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../data/datasources/clients_local_datasource.dart';
import '../../data/repositories/client_repository_impl.dart';
import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../../../invoices/presentation/controllers/invoices_controller.dart';
import '../../../reminders/data/providers/reminder_repository_provider.dart';
import '../../domain/usecases/add_client_usecase.dart';
import '../../domain/usecases/delete_client_usecase.dart';
import '../../domain/usecases/get_clients_usecase.dart';
import '../../domain/usecases/update_client_usecase.dart';

final clientsLocalDatasourceProvider = Provider<ClientsLocalDatasource>(
  (ref) => ClientsLocalDatasource(),
);

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final datasource = ref.watch(clientsLocalDatasourceProvider);
  return ClientRepositoryImpl(
    datasource,
    syncService: ref.watch(firestoreSyncServiceProvider),
    userId: ref.watch(activeWorkspaceOwnerIdProvider),
    isPro:
        ref.watch(subscriptionControllerProvider).valueOrNull?.isPro ?? false,
  );
});

final getClientsUseCaseProvider = Provider<GetClientsUseCase>(
  (ref) => GetClientsUseCase(ref.watch(clientRepositoryProvider)),
);

final addClientUseCaseProvider = Provider<AddClientUseCase>(
  (ref) => AddClientUseCase(ref.watch(clientRepositoryProvider)),
);

final updateClientUseCaseProvider = Provider<UpdateClientUseCase>(
  (ref) => UpdateClientUseCase(ref.watch(clientRepositoryProvider)),
);

final deleteClientUseCaseProvider = Provider<DeleteClientUseCase>(
  (ref) => DeleteClientUseCase(
    ref.watch(clientRepositoryProvider),
    ref.watch(invoiceRepositoryProvider),
    ref.watch(reminderRepositoryProvider),
  ),
);

final clientsControllerProvider =
    NotifierProvider<ClientsController, AsyncValue<List<Client>>>(
      ClientsController.new,
    );

final clientDetailProvider = FutureProvider.family<Client?, String>((
  ref,
  id,
) async {
  final currentClients = ref.read(clientsControllerProvider).valueOrNull;
  if (currentClients != null) {
    for (final client in currentClients) {
      if (client.id == id) {
        return client;
      }
    }
  }

  return ref.watch(clientRepositoryProvider).getClientById(id);
});

class ClientsController extends Notifier<AsyncValue<List<Client>>> {
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _didLoad = false;

  bool get hasMore => _hasMore;

  @override
  AsyncValue<List<Client>> build() {
    if (!_didLoad) {
      _didLoad = true;
      Future(() => loadInitial());
    }
    return const AsyncValue.loading();
  }

  Future<void> loadInitial() async {
    _currentPage = 1;
    _hasMore = true;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(getClientsUseCaseProvider)
          .call(
            page: 1,
            pageSize: AppConstants.defaultPageSize,
            forceRefresh: true,
          ),
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
    await ref
        .read(subscriptionGatekeeperProvider)
        .ensureAllowed(SubscriptionGateFeature.addClient);

    final client = _validatedClient(
      Client(
        id: IdGenerator.nextId('client'),
        name: name,
        email: email,
        phone: phone,
        createdAt: DateTime.now(),
      ),
    );

    try {
      final created = await ref.read(addClientUseCaseProvider).call(client);
      final current = state.valueOrNull ?? const <Client>[];
      state = AsyncValue.data(_mergeClients(current, created));
      ref.invalidate(clientDetailProvider(created.id));
      await ref
          .read(adaptiveSystemProvider.notifier)
          .recordAction(AdaptiveActionKey.addClient);
      return created;
    } catch (error, stackTrace) {
      if (error is AppException) {
        rethrow;
      }

      debugPrint('Failed to save client: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const AppException('Failed to save client');
    }
  }

  Future<Client> updateClient(Client client) async {
    final validated = _validatedClient(client);

    try {
      final updated = await ref
          .read(updateClientUseCaseProvider)
          .call(validated);
      final current = state.valueOrNull ?? const <Client>[];
      state = AsyncValue.data(_mergeClients(current, updated));
      ref.invalidate(clientDetailProvider(updated.id));
      // Clear invoice cache so clientName resolves to the new name on next fetch
      ref.read(invoicesLocalDatasourceProvider).clearCache();
      return updated;
    } catch (error, stackTrace) {
      if (error is AppException) {
        rethrow;
      }

      debugPrint('Failed to save client ${client.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const AppException('Failed to save client');
    }
  }

  Future<void> deleteClient(String clientId) async {
    try {
      await ref.read(deleteClientUseCaseProvider).call(clientId);
      final current = state.valueOrNull ?? const <Client>[];
      state = AsyncValue.data(
        current.where((item) => item.id != clientId).toList(growable: false),
      );
      ref.invalidate(clientDetailProvider(clientId));
    } catch (error, stackTrace) {
      if (error is AppException) {
        rethrow;
      }

      debugPrint('Failed to delete client $clientId: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const AppException('Failed to delete client');
    }
  }

  List<Client> _mergeClients(List<Client> current, Client client) {
    final merged = <Client>[client];
    for (final item in current) {
      if (item.id != client.id) {
        merged.add(item);
      }
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<Client>.unmodifiable(merged);
  }

  Client _validatedClient(Client client) {
    final normalizedName = client.name.trim();
    final normalizedEmail = client.email.trim();
    final normalizedPhone = Client.normalizePhone(client.phone);

    if (normalizedName.isEmpty) {
      throw const ValidationException('Name required');
    }
    if (!Client.isValidEmail(normalizedEmail)) {
      throw const ValidationException('Invalid email');
    }
    if (!Client.hasValidInternationalPhone(normalizedPhone)) {
      throw const ValidationException('Invalid phone');
    }

    return client.copyWith(
      name: normalizedName,
      email: normalizedEmail,
      phone: normalizedPhone,
    );
  }
}
