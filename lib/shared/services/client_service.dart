import '../../features/clients/domain/entities/client.dart';

abstract interface class ClientService {
  Future<List<Client>> fetchClients({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  });

  Future<Client> createClient(Client client);

  Future<Client?> getClientById(String id);
}
