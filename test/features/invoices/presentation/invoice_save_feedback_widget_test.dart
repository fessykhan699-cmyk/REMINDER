import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:reminder/core/errors/app_exception.dart';
import 'package:reminder/core/storage/hive_storage.dart';
import 'package:reminder/features/clients/domain/entities/client.dart';
import 'package:reminder/features/clients/data/models/client_model.dart';
import 'package:reminder/features/invoices/data/models/invoice_model.dart';
import 'package:reminder/features/invoices/domain/entities/invoice.dart';
import 'package:reminder/features/invoices/presentation/controllers/invoice_creation_learning_controller.dart';
import 'package:reminder/features/invoices/presentation/controllers/invoice_prediction_engine.dart';
import 'package:reminder/features/invoices/presentation/controllers/invoices_controller.dart';
import 'package:reminder/features/invoices/presentation/screens/create_invoice_screen.dart';
import 'package:reminder/features/settings/domain/entities/app_preferences.dart';
import 'package:reminder/features/settings/domain/entities/profile.dart';
import 'package:reminder/features/settings/domain/repositories/settings_repository.dart';
import 'package:reminder/features/settings/presentation/controllers/app_preferences_controller.dart';
import 'package:reminder/features/settings/presentation/controllers/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('invoice_save_feedback_');
    Hive.init(tempDir.path);
    HiveStorage.registerAdapters();
    await Hive.openBox<ClientModel>(HiveStorage.clientsBoxName);
    await Hive.openBox<InvoiceModel>(HiveStorage.invoicesBoxName);
  });

  setUp(() async {
    await Hive.box<ClientModel>(HiveStorage.clientsBoxName).clear();
    await Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName).clear();
  });

  tearDownAll(() async {
    if (Hive.isBoxOpen(HiveStorage.clientsBoxName)) {
      await Hive.box<ClientModel>(HiveStorage.clientsBoxName).close();
    }
    if (Hive.isBoxOpen(HiveStorage.invoicesBoxName)) {
      await Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName).close();
    }
    await Hive.deleteBoxFromDisk(HiveStorage.clientsBoxName);
    await Hive.deleteBoxFromDisk(HiveStorage.invoicesBoxName);
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('create invoice shows success only after save succeeds', (
    tester,
  ) async {
    final saveDatasource = _InMemoryInvoiceSaveDatasource(
      shouldFail: false,
      delay: const Duration(milliseconds: 300),
    );
    final navigatorObserver = _TestNavigatorObserver();

    await _pumpTestApp(
      tester,
      saveDatasource: saveDatasource,
      navigatorObserver: navigatorObserver,
    );
    await _openCreateInvoiceScreen(tester);
    await _fillValidInvoiceForm(tester);

    await _tapSaveInvoice(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Invoice saved'), findsNothing);
    expect(find.text('Unable to save invoice'), findsNothing);
    expect(find.text('Create Invoice'), findsOneWidget);
    expect(saveDatasource.savedInvoices, isEmpty);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(saveDatasource.savedInvoices, hasLength(1));
    expect(saveDatasource.savedInvoices.single.clientName, 'Test Client');
    expect(saveDatasource.savedInvoices.single.service, 'Design');
    expect(saveDatasource.savedInvoices.single.amount, 500);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create invoice shows error only after save fails', (
    tester,
  ) async {
    final saveDatasource = _InMemoryInvoiceSaveDatasource(
      shouldFail: true,
      delay: const Duration(milliseconds: 300),
    );
    final navigatorObserver = _TestNavigatorObserver();

    await _pumpTestApp(
      tester,
      saveDatasource: saveDatasource,
      navigatorObserver: navigatorObserver,
    );
    await _openCreateInvoiceScreen(tester);
    await _fillValidInvoiceForm(tester);

    await _tapSaveInvoice(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Invoice saved'), findsNothing);
    expect(find.text('Unable to save invoice'), findsNothing);
    expect(find.text('Create Invoice'), findsOneWidget);
    expect(saveDatasource.savedInvoices, isEmpty);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('Create Invoice'), findsOneWidget);
    expect(find.text('Invoice Test Host'), findsNothing);
    expect(navigatorObserver.popCount, 0);
    expect(saveDatasource.savedInvoices, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

final _testInvoiceSaveDatasourceProvider =
    Provider<_InMemoryInvoiceSaveDatasource>(
      (ref) => throw UnimplementedError(),
    );

final Client _testClient = Client(
  id: 'client-test-1',
  name: 'Test Client',
  email: 'test@mail.com',
  phone: '+971500000000',
  createdAt: DateTime(2026, 4, 5),
);

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required _InMemoryInvoiceSaveDatasource saveDatasource,
  required _TestNavigatorObserver navigatorObserver,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        _testInvoiceSaveDatasourceProvider.overrideWithValue(saveDatasource),
        invoicesControllerProvider.overrideWith(_TestInvoicesController.new),
        invoiceCreationLearningProvider.overrideWith(
          _TestInvoiceCreationLearningController.new,
        ),
        settingsRepositoryProvider.overrideWithValue(_TestSettingsRepository()),
        appPreferencesControllerProvider.overrideWith(
          _TestAppPreferencesController.new,
        ),
        smartInvoicePredictionProvider.overrideWithValue(
          _buildPrediction(_testClient),
        ),
      ],
      child: MaterialApp(
        navigatorObservers: [navigatorObserver],
        home: const _CreateInvoiceTestHost(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _openCreateInvoiceScreen(WidgetTester tester) async {
  expect(find.text('Invoice Test Host'), findsOneWidget);
  await tester.tap(find.text('Open Create Invoice'));
  await tester.pumpAndSettle();
  expect(find.text('Create Invoice'), findsOneWidget);
}

Future<void> _fillValidInvoiceForm(WidgetTester tester) async {
  await tester.tap(find.text('Suggested: Test Client'));
  await tester.pumpAndSettle();

  // Field order includes invoice number first, then service and amount.
  await tester.enterText(find.byType(EditableText).at(1), 'Design');
  await tester.enterText(find.byType(EditableText).at(2), '500');
  await tester.pumpAndSettle();
}

Future<void> _tapSaveInvoice(WidgetTester tester) async {
  final saveButton = find.text('Save Invoice');
  await tester.ensureVisible(saveButton);
  await tester.pumpAndSettle();
  await tester.tap(saveButton);
}

class _CreateInvoiceTestHost extends StatelessWidget {
  const _CreateInvoiceTestHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Invoice Test Host'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateInvoiceScreen(),
                  ),
                );
              },
              child: const Text('Open Create Invoice'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InMemoryInvoiceSaveDatasource {
  _InMemoryInvoiceSaveDatasource({
    required this.shouldFail,
    required this.delay,
  });

  final bool shouldFail;
  final Duration delay;
  final List<Invoice> savedInvoices = <Invoice>[];

  Future<Invoice> createInvoice(Invoice invoice) async {
    await Future<void>.delayed(delay);

    if (shouldFail) {
      throw const AppException('Unable to save invoice');
    }

    savedInvoices.insert(0, invoice);
    return invoice;
  }
}

class _TestNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

class _TestInvoicesController extends InvoicesController {
  @override
  AsyncValue<List<Invoice>> build() {
    return const AsyncValue.data(<Invoice>[]);
  }

  @override
  Future<Invoice> createInvoice(Invoice invoice) async {
    final created = await ref
        .read(_testInvoiceSaveDatasourceProvider)
        .createInvoice(invoice);
    final current = state.valueOrNull ?? const <Invoice>[];
    state = AsyncValue.data([created, ...current]);
    return created;
  }
}

class _TestInvoiceCreationLearningController
    extends InvoiceCreationLearningController {
  @override
  InvoiceCreationLearningState build() {
    return const InvoiceCreationLearningState.initial();
  }

  @override
  Future<void> recordCreatedInvoice(Invoice invoice) async {}

  @override
  Future<void> recordPredictionOutcome({
    required String? predictedClientId,
    required String? predictedService,
    required double? predictedAmount,
    required DateTime? predictedDueDate,
    required Invoice actualInvoice,
  }) async {}
}

class _TestAppPreferencesController extends AppPreferencesController {
  @override
  AsyncValue<AppPreferences> build() {
    return const AsyncValue.data(AppPreferences.defaults());
  }
}

class _TestSettingsRepository implements SettingsRepository {
  static const UserProfile _profile = UserProfile(
    name: 'Test Owner',
    email: 'owner@test.com',
    businessName: 'Test Studio',
    phone: '+971500000001',
    address: 'Dubai',
  );

  @override
  Future<AppPreferences> getAppPreferences() async {
    return const AppPreferences.defaults();
  }

  @override
  Future<UserProfile> getProfile() async {
    return _profile;
  }

  @override
  Future<AppPreferences> saveAppPreferences(AppPreferences preferences) async {
    return preferences;
  }

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    return profile;
  }
}

SmartInvoicePrediction _buildPrediction(Client client) {
  return SmartInvoicePrediction(
    suggestedClient: client,
    suggestedClientReason: 'Recent client',
    suggestedClientConfidence: 1.0,
    leadingClient: client,
    leadingClientReason: 'Recent client',
    leadingClientConfidence: 1.0,
    preferredDueDays: 30,
    preferredDueDaysConfidence: 1.0,
    defaultDueDays: 30,
    quickAmount: null,
    quickAmountReason: null,
    quickAmountConfidence: 0.0,
    firstAvailableClient: client,
    hasInvoiceHistory: false,
    predictionWeights: const PredictionModelWeights.initial(),
    recentAccuracyAverage: 0.0,
    confidenceAdjustment: 0.0,
    oneTapTemporarilyDisabled: false,
    suggestionsByClient: const <String, SmartClientSuggestion>{},
    clientConfidenceById: <String, double>{client.id: 1.0},
  );
}
