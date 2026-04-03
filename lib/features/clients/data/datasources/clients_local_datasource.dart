import 'dart:math';

import '../models/client_model.dart';

class ClientsLocalDatasource {
  final List<ClientModel> _clients = [
    ClientModel(
      id: 'client-1',
      name: 'Northwind Studio',
      email: 'billing@northwind.com',
      phone: '+1 555 103 882',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    ClientModel(
      id: 'client-2',
      name: 'Acme Retail',
      email: 'finance@acme.co',
      phone: '+1 555 912 100',
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
    ),
  ];

  final Map<int, List<ClientModel>> _pageCache = {};
  final Map<String, ClientModel> _clientCache = {};

  Future<List<ClientModel>> fetchClients({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _pageCache.containsKey(page)) {
      return _pageCache[page]!;
    }

    await Future<void>.delayed(const Duration(milliseconds: 220));

    final start = (page - 1) * pageSize;
    if (start >= _clients.length) {
      _pageCache[page] = const [];
      return const [];
    }

    final end = min(start + pageSize, _clients.length);
    final data = List<ClientModel>.unmodifiable(_clients.sublist(start, end));

    for (final item in data) {
      _clientCache[item.id] = item;
    }

    _pageCache[page] = data;
    return data;
  }

  Future<ClientModel> addClient(ClientModel client) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _clients.insert(0, client);
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

    for (final client in _clients) {
      if (client.id == id) {
        _clientCache[id] = client;
        return client;
      }
    }

    return null;
  }
}
