import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/hive_storage.dart';
import '../models/client_model.dart';

class ClientsLocalDatasource {
  final Map<int, List<ClientModel>> _pageCache = {};
  final Map<String, ClientModel> _clientCache = {};

  String _normalizeEmail(String value) => value.trim().toLowerCase();

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? '' : '+$digits';
  }

  void _ensureUniqueClient(Box<ClientModel> clientsBox, ClientModel client) {
    final normalizedEmail = _normalizeEmail(client.email);
    final normalizedPhone = _normalizePhone(client.phone);

    for (final existing in clientsBox.values) {
      if (existing.id == client.id) {
        continue;
      }

      if (_normalizeEmail(existing.email) == normalizedEmail) {
        throw const ValidationException(
          'A client with this email already exists.',
        );
      }

      if (_normalizePhone(existing.phone) == normalizedPhone) {
        throw const ValidationException(
          'A client with this phone already exists.',
        );
      }
    }
  }

  Future<Box<ClientModel>> _ensureBoxOpen() async {
    if (Hive.isBoxOpen(HiveStorage.clientsBoxName)) {
      return Hive.box<ClientModel>(HiveStorage.clientsBoxName);
    }

    return Hive.openBox<ClientModel>(HiveStorage.clientsBoxName);
  }

  List<ClientModel> _sortedClients(Box<ClientModel> clientsBox) {
    final clients = clientsBox.values.toList();
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
    final clientsBox = await _ensureBoxOpen();

    final clients = _sortedClients(clientsBox);
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
    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final clientsBox = await _ensureBoxOpen();
      if (clientsBox.containsKey(client.id)) {
        throw const ValidationException(
          'A client with this ID already exists.',
        );
      }
      _ensureUniqueClient(clientsBox, client);
      await clientsBox.put(client.id, client);
      _clientCache[client.id] = client;
      _pageCache.clear();
      return client;
    } on AppException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Failed to add client ${client.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<ClientModel> updateClient(ClientModel client) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final clientsBox = await _ensureBoxOpen();
      if (!clientsBox.containsKey(client.id)) {
        throw const CacheException('Client not found.');
      }
      _ensureUniqueClient(clientsBox, client);
      await clientsBox.put(client.id, client);
      _clientCache[client.id] = client;
      _pageCache.clear();
      return client;
    } on AppException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Failed to update client ${client.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteClient(String id) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final clientsBox = await _ensureBoxOpen();
      if (!clientsBox.containsKey(id)) {
        _clientCache.remove(id);
        _pageCache.clear();
        return;
      }
      await clientsBox.delete(id);
      _clientCache.remove(id);
      _pageCache.clear();
    } catch (error, stackTrace) {
      debugPrint('Failed to delete client $id: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<ClientModel?> getClientById(String id) async {
    final cached = _clientCache[id];
    if (cached != null) {
      return cached;
    }

    await Future<void>.delayed(const Duration(milliseconds: 80));
    final clientsBox = await _ensureBoxOpen();

    final client = clientsBox.get(id);
    if (client != null) {
      _clientCache[id] = client;
    }

    return client;
  }
}
