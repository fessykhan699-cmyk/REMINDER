import '../entities/client.dart';
import '../repositories/client_repository.dart';

class GetClientsUseCase {
  const GetClientsUseCase(this._repository);

  final ClientRepository _repository;

  Future<List<Client>> call({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) {
    return _repository.getClients(
      page: page,
      pageSize: pageSize,
      forceRefresh: forceRefresh,
    );
  }
}
