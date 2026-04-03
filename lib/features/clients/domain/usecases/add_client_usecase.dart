import '../entities/client.dart';
import '../repositories/client_repository.dart';

class AddClientUseCase {
  const AddClientUseCase(this._repository);

  final ClientRepository _repository;

  Future<Client> call(Client client) => _repository.addClient(client);
}
