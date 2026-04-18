import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/clients_local_datasource.dart';
import '../models/client_model.dart';
import '../../../../data/services/firestore_sync_service.dart';
import '../../../../data/services/analytics_service.dart';

class ClientRepositoryImpl implements ClientRepository {
  const ClientRepositoryImpl(
    this._datasource, {
    this.syncService,
    this.userId,
    this.isPro = false,
  });

  final ClientsLocalDatasource _datasource;
  final FirestoreSyncService? syncService;
  final String? userId;
  final bool isPro;

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
  Future<Client> addClient(Client client) async {
    final model = ClientModel.fromEntity(client);
    final saved = await _datasource.addClient(model);
    _syncClient(saved);
    
    // Log to Analytics
    AnalyticsService.instance.logClientCreated(clientId: saved.id);
    
    return saved;
  }

  @override
  Future<Client> updateClient(Client client) async {
    final model = ClientModel.fromEntity(client);
    final saved = await _datasource.updateClient(model);
    _syncClient(saved);
    return saved;
  }

  @override
  Future<void> deleteClient(String id) async {
    await _datasource.deleteClient(id);
    _deleteClient(id);
  }

  @override
  Future<Client?> getClientById(String id) => _datasource.getClientById(id);

  // ── Private sync helpers ────────────────────────────────────────────────

  void _syncClient(ClientModel model) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.syncClientToCloud(userId: uid, isPro: isPro, client: model);
  }

  void _deleteClient(String clientId) {
    final svc = syncService;
    final uid = userId;
    if (svc == null || uid == null) return;
    svc.deleteClientFromCloud(userId: uid, isPro: isPro, clientId: clientId);
  }
}
