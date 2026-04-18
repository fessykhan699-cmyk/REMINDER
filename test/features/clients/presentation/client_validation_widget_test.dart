import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminder/core/errors/app_exception.dart';
import 'package:reminder/features/clients/data/datasources/clients_local_datasource.dart';
import 'package:reminder/features/clients/data/models/client_model.dart';
import 'package:reminder/features/clients/presentation/controllers/clients_controller.dart';
import 'package:reminder/features/clients/presentation/screens/add_client_screen.dart';
import 'package:reminder/features/clients/domain/entities/client.dart';
import 'package:reminder/features/clients/domain/repositories/client_repository.dart';
import 'package:reminder/features/subscription/domain/entities/subscription_state.dart';
import 'package:reminder/features/subscription/presentation/controllers/subscription_controller.dart';
import 'package:reminder/shared/adaptive/adaptive_system_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('client validation failures are rejected reliably', (
    tester,
  ) async {
    final datasource = _InMemoryClientsLocalDatasource();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientsLocalDatasourceProvider.overrideWithValue(datasource),
          clientRepositoryProvider.overrideWithValue(
            _LocalClientRepository(datasource),
          ),
          subscriptionGatekeeperProvider.overrideWith(
            (ref) => _AlwaysAllowSubscriptionGatekeeper(ref),
          ),
          adaptiveSystemProvider.overrideWith(
            _TestAdaptiveSystemController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en', 'AE'),
          supportedLocales: const [Locale('en', 'AE')],
          home: const _AddClientValidationHost(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Open Add Client'), findsOneWidget);
    expect(datasource.clients, isEmpty);
    expect(tester.takeException(), isNull);

    await _openAddClientScreen(tester);
    await _fillClientForm(
      tester,
      name: 'Test Client',
      email: 'invalid-email',
      phoneDigits: '500000000',
    );

    await tester.tap(find.text('Save Client'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email'), findsAtLeastNWidgets(1));
    expect(find.text('Client saved successfully.'), findsNothing);
    expect(datasource.clients, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await _openAddClientScreen(tester);
    await _fillClientForm(
      tester,
      name: 'Test Client',
      email: 'test@mail.com',
      phoneDigits: '12345',
    );

    await tester.tap(find.text('Save Client'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid phone'), findsAtLeastNWidgets(1));
    expect(find.text('Client saved successfully.'), findsNothing);
    expect(datasource.clients, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await _openAddClientScreen(tester);
    await _fillClientForm(
      tester,
      name: 'Test Client',
      email: 'test@mail.com',
      phoneDigits: '500000000',
    );

    await tester.tap(find.text('Save Client'));
    await tester.pumpAndSettle();

    expect(find.text('Add Client'), findsNothing);
    expect(find.text('Open Add Client'), findsOneWidget);
    expect(datasource.clients, hasLength(1));
    expect(datasource.clients.single.name, 'Test Client');
    expect(datasource.clients.single.email, 'test@mail.com');
    expect(datasource.clients.single.phone, '+971500000000');
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await _openAddClientScreen(tester);
    await _fillClientForm(
      tester,
      name: 'Test Client',
      email: 'test@mail.com',
      phoneDigits: '500000000',
    );

    await tester.tap(find.text('Save Client'));
    await tester.pumpAndSettle();

    expect(find.text('Client already exists'), findsOneWidget);
    expect(find.text('Failed to save client'), findsNothing);
    expect(datasource.clients, hasLength(1));
    expect(datasource.clients.single.name, 'Test Client');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openAddClientScreen(WidgetTester tester) async {
  await tester.tap(find.text('Open Add Client'));
  await tester.pumpAndSettle();
  expect(find.text('Add Client'), findsOneWidget);
}

Future<void> _fillClientForm(
  WidgetTester tester, {
  required String name,
  required String email,
  required String phoneDigits,
}) async {
  await tester.enterText(find.byType(EditableText).at(0), name);
  await tester.enterText(find.byType(EditableText).at(1), email);
  await tester.enterText(find.byType(EditableText).at(2), phoneDigits);
  await tester.pumpAndSettle();
}

class _AddClientValidationHost extends StatelessWidget {
  const _AddClientValidationHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const AddClientScreen(),
              ),
            );
          },
          child: const Text('Open Add Client'),
        ),
      ),
    );
  }
}

class _InMemoryClientsLocalDatasource extends ClientsLocalDatasource {
  final Map<String, ClientModel> _clients = <String, ClientModel>{};

  List<ClientModel> get clients {
    final values = _clients.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<ClientModel>.unmodifiable(values);
  }

  String _normalizeEmail(String value) => value.trim().toLowerCase();

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? '' : '+$digits';
  }

  void _ensureUnique(ClientModel client) {
    final normalizedEmail = _normalizeEmail(client.email);
    final normalizedPhone = _normalizePhone(client.phone);

    for (final existing in _clients.values) {
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

  @override
  Future<List<ClientModel>> fetchClients({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final values = clients;
    final start = (page - 1) * pageSize;
    if (start >= values.length) {
      return const <ClientModel>[];
    }

    final end = start + pageSize > values.length
        ? values.length
        : start + pageSize;
    return List<ClientModel>.unmodifiable(values.sublist(start, end));
  }

  @override
  Future<ClientModel> addClient(ClientModel client) async {
    if (_clients.containsKey(client.id)) {
      throw const ValidationException('A client with this ID already exists.');
    }

    _ensureUnique(client);
    _clients[client.id] = client;
    return client;
  }

  @override
  Future<ClientModel> updateClient(ClientModel client) async {
    if (!_clients.containsKey(client.id)) {
      throw const CacheException('Client not found.');
    }

    _ensureUnique(client);
    _clients[client.id] = client;
    return client;
  }

  @override
  Future<void> deleteClient(String id) async {
    _clients.remove(id);
  }

  @override
  Future<ClientModel?> getClientById(String id) async {
    return _clients[id];
  }
}

class _LocalClientRepository implements ClientRepository {
  _LocalClientRepository(this._datasource);

  final ClientsLocalDatasource _datasource;

  @override
  Future<Client> addClient(Client client) async {
    return _datasource.addClient(ClientModel.fromEntity(client));
  }

  @override
  Future<void> deleteClient(String id) => _datasource.deleteClient(id);

  @override
  Future<Client?> getClientById(String id) => _datasource.getClientById(id);

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
  Future<Client> updateClient(Client client) {
    return _datasource.updateClient(ClientModel.fromEntity(client));
  }
}

class _AlwaysAllowSubscriptionGatekeeper extends SubscriptionGatekeeper {
  _AlwaysAllowSubscriptionGatekeeper(super.ref);

  @override
  Future<SubscriptionGateDecision> evaluate(
    SubscriptionGateFeature feature,
  ) async {
    return SubscriptionGateDecision.allowed(feature, isPro: true);
  }

  @override
  Future<void> ensureAllowed(SubscriptionGateFeature feature) async {}
}

class _TestAdaptiveSystemController extends AdaptiveSystemController {
  @override
  AdaptiveSystemState build() {
    return const AdaptiveSystemState.initial();
  }

  @override
  Future<void> recordAction(AdaptiveActionKey action) async {}
}
