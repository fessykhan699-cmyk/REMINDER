import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:reminder/core/errors/app_exception.dart';
import 'package:reminder/core/storage/hive_storage.dart';
import 'package:reminder/features/clients/data/datasources/clients_local_datasource.dart';
import 'package:reminder/features/clients/data/models/client_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ClientsLocalDatasource datasource;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('clients_datasource_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ClientModelAdapter());
    }
  });

  setUp(() async {
    datasource = ClientsLocalDatasource();
    final box = await Hive.openBox<ClientModel>(HiveStorage.clientsBoxName);
    await box.clear();
    await box.close();
  });

  tearDownAll(() async {
    if (Hive.isBoxOpen(HiveStorage.clientsBoxName)) {
      await Hive.box<ClientModel>(HiveStorage.clientsBoxName).close();
    }
    await Hive.deleteBoxFromDisk(HiveStorage.clientsBoxName);
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('adds, fetches, updates, and deletes a persisted client', () async {
    final client = ClientModel(
      id: 'client-001',
      name: 'Acme Studio',
      email: 'hello@acme.test',
      phone: '+1555010100',
      createdAt: DateTime(2026, 4, 5),
    );

    final added = await datasource.addClient(client);
    expect(added.id, client.id);

    final fetched = await datasource.getClientById(client.id);
    expect(fetched, isNotNull);
    expect(fetched!.email, 'hello@acme.test');

    final page = await datasource.fetchClients(forceRefresh: true);
    expect(page.map((item) => item.id), contains(client.id));

    final updated = await datasource.updateClient(
      ClientModel(
        id: client.id,
        name: 'Acme Studio Ltd',
        email: 'billing@acme.test',
        phone: '+1555010199',
        createdAt: client.createdAt,
      ),
    );

    expect(updated.name, 'Acme Studio Ltd');
    expect((await datasource.getClientById(client.id))?.phone, '+1555010199');

    await datasource.deleteClient(client.id);

    expect(await datasource.getClientById(client.id), isNull);
    expect(await datasource.fetchClients(forceRefresh: true), isEmpty);
  });

  test('rejects duplicate clients by email and phone', () async {
    await datasource.addClient(
      ClientModel(
        id: 'client-001',
        name: 'Acme Studio',
        email: 'hello@acme.test',
        phone: '+1555010100',
        createdAt: DateTime(2026, 4, 5),
      ),
    );

    await expectLater(
      datasource.addClient(
        ClientModel(
          id: 'client-002',
          name: 'Acme Studio Copy',
          email: 'HELLO@acme.test',
          phone: '+1555099999',
          createdAt: DateTime(2026, 4, 5, 1),
        ),
      ),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.message,
          'message',
          'A client with this email already exists.',
        ),
      ),
    );

    await expectLater(
      datasource.addClient(
        ClientModel(
          id: 'client-003',
          name: 'Acme Studio Phone Copy',
          email: 'copy@acme.test',
          phone: '+1 (555) 010-100',
          createdAt: DateTime(2026, 4, 5, 2),
        ),
      ),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.message,
          'message',
          'A client with this phone already exists.',
        ),
      ),
    );
  });
}
