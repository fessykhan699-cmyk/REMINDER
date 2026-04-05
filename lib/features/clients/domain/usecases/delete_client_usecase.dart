import '../repositories/client_repository.dart';

class DeleteClientUseCase {
  const DeleteClientUseCase(this._repository);

  final ClientRepository _repository;

  Future<void> call(String clientId) => _repository.deleteClient(clientId);
}
