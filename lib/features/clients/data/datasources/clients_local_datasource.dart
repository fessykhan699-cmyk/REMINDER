import 'dart:math';

import 'package:hive/hive.dart';

import '../../../../core/storage/hive_storage.dart';
import '../models/client_model.dart';

class ClientsLocalDatasource {
  final Box<ClientModel> _clientsBox = Hive.box<ClientModel>(
    HiveStorage.clientsBoxName,
  );

  final Map<int, List<ClientModel>> _pageCache = {};
  final Map<String, ClientModel> _clientCache = {};

  List<ClientModel> _sortedClients() {
    final clients = _clientsBox.values.toList();
    clients.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return clients;
  }

  Future<List<ClientModel>> fetchClients({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _pageCache.containsKey(page)) {
      return _pageCache[page]!;
    }

    await Future<void>.delayed(const Duration(milliseconds: 220));

    final clients = _sortedClients();
    final start = (page - 1) * pageSize;
    if (start >= clients.length) {
      _pageCache[page] = const [];
      return const [];
    }

    final end = min(start + pageSize, clients.length);
    final data = List<ClientModel>.unmodifiable(clients.sublist(start, end));

    for (final item in data) {
      _clientCache[item.id] = item;
    }

    _pageCache[page] = data;
    return data;
  }

  Future<ClientModel> addClient(ClientModel client) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _clientsBox.put(client.id, client);
    _clientCache[client.id] = client;
    _pageCache.clear();
    return client;
  }

  Future<ClientModel?> getClientById(String id) async {
    final cached = _clientCache[id];
    if (cached != null) {
      return cached;
    }

    await Future<void>.delayed(const Duration(milliseconds: 80));

    final client = _clientsBox.get(id);
    if (client != null) {
      _clientCache[id] = client;
    }

    return client;
  }
}
