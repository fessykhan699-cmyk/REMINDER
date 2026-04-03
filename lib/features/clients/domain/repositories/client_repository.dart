import '../entities/client.dart';

abstract interface class ClientRepository {
  Future<List<Client>> getClients({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  });

  Future<Client> addClient(Client client);

  Future<Client?> getClientById(String id);
}
