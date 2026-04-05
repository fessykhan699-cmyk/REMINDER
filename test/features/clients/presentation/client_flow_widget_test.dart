import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reminder/core/constants/app_routes.dart';
import 'package:reminder/core/errors/app_exception.dart';
import 'package:reminder/features/clients/data/datasources/clients_local_datasource.dart';
import 'package:reminder/features/clients/data/models/client_model.dart';
import 'package:reminder/features/clients/presentation/controllers/clients_controller.dart';
import 'package:reminder/features/clients/presentation/screens/add_client_screen.dart';
import 'package:reminder/features/clients/presentation/screens/client_detail_screen.dart';
import 'package:reminder/features/clients/presentation/screens/clients_list_screen.dart';
import 'package:reminder/features/invoices/domain/entities/invoice.dart';
import 'package:reminder/features/invoices/presentation/controllers/invoices_controller.dart';
import 'package:reminder/features/subscription/domain/entities/subscription_state.dart';
import 'package:reminder/features/subscription/presentation/controllers/subscription_controller.dart';
import 'package:reminder/shared/adaptive/adaptive_system_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('client add edit delete flow stays stable', (tester) async {
    final datasource = _InMemoryClientsLocalDatasource();
    final router = GoRouter(
      initialLocation: ClientsTabRoute.routePath,
      routes: [
        GoRoute(
          path: ClientsTabRoute.routePath,
          builder: (context, state) => const _ClientsTestRouteHost(),
        ),
        GoRoute(
          path: AddClientRoute.routePath,
          builder: (context, state) => const AddClientScreen(),
        ),
        GoRoute(
          path: ClientDetailRoute.routePath,
          builder: (context, state) {
            return ClientDetailScreen(
              clientId: state.pathParameters['clientId']!,
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientsLocalDatasourceProvider.overrideWithValue(datasource),
          invoicesControllerProvider.overrideWith(_TestInvoicesController.new),
          subscriptionGatekeeperProvider.overrideWith(
            (ref) => _AlwaysAllowSubscriptionGatekeeper(ref),
          ),
          adaptiveSystemProvider.overrideWith(
            _TestAdaptiveSystemController.new,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en', 'AE'),
          supportedLocales: const [Locale('en', 'AE')],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No clients yet'), findsOneWidget);
    expect(
      find.text('Add your first client to start invoicing faster.'),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add Client'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(0), 'Test Client');
    await tester.enterText(find.byType(EditableText).at(1), 'test@mail.com');
    await tester.enterText(find.byType(EditableText).at(2), '500000000');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Client'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to add client'), findsNothing);
    expect(find.text('Unable to add the client right now.'), findsNothing);
    expect(find.text('Failed to save client'), findsNothing);
    expect(find.text('Client saved successfully.'), findsOneWidget);
    expect(find.text('Test Client'), findsOneWidget);
    expect(datasource.clients.single.name, 'Test Client');
    expect(datasource.clients.single.email, 'test@mail.com');
    expect(datasource.clients.single.phone, '+971500000000');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Test Client'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Client'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(0), 'Updated Client');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to save client'), findsNothing);
    expect(find.text('Edit Client'), findsNothing);
    expect(find.text('Updated Client'), findsOneWidget);
    expect(find.text('Test Client'), findsNothing);
    expect(datasource.clients.single.name, 'Updated Client');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Updated Client'));
    await tester.pumpAndSettle();

    final deleteClientButton = find.widgetWithText(
      OutlinedButton,
      'Delete Client',
    );
    await tester.ensureVisible(deleteClientButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteClientButton);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to delete client'), findsNothing);
    expect(find.text('Updated Client'), findsNothing);
    expect(find.text('No clients yet'), findsOneWidget);
    expect(datasource.clients, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _ClientsTestRouteHost extends StatelessWidget {
  const _ClientsTestRouteHost();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ClientsListScreen(),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            tooltip: 'Add client',
            onPressed: () {
              const AddClientRoute().push(context);
            },
            child: const Icon(Icons.add),
          ),
        ),
      ],
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

class _TestInvoicesController extends InvoicesController {
  @override
  AsyncValue<List<Invoice>> build() {
    return const AsyncValue.data(<Invoice>[]);
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
