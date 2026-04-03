import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/clients_local_datasource.dart';
import '../models/client_model.dart';

class ClientRepositoryImpl implements ClientRepository {
  const ClientRepositoryImpl(this._datasource);

  final ClientsLocalDatasource _datasource;

  @override
  Future<List<Client>> getClients({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) {
    return _datasource.fetchClients(
      page: page,
      pageSize: pageSize,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<Client> addClient(Client client) {
    return _datasource.addClient(ClientModel.fromEntity(client));
  }

  @override
  Future<Client?> getClientById(String id) => _datasource.getClientById(id);
}
