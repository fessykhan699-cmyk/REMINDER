import '../entities/client.dart';
import '../repositories/client_repository.dart';

class UpdateClientUseCase {
  const UpdateClientUseCase(this._repository);

  final ClientRepository _repository;

  Future<Client> call(Client client) => _repository.updateClient(client);
}
