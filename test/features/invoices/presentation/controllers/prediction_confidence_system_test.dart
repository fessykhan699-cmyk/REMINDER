import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reminder/features/clients/domain/entities/client.dart';
import 'package:reminder/features/invoices/domain/entities/invoice.dart';
import 'package:reminder/features/invoices/presentation/controllers/invoice_creation_learning_controller.dart';
import 'package:reminder/features/invoices/presentation/controllers/invoice_prediction_engine.dart';
import 'package:reminder/shared/adaptive/adaptive_system_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Prediction and confidence system', () {
    group('Amount tolerance (5%)', () {
      test('accepts amount prediction at 5 percent delta', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(
          invoiceCreationLearningProvider.notifier,
        );
        final actualInvoice = Invoice(
          id: 'inv-1',
          invoiceNumber: 'INV-001',
          clientId: 'client-a',
          clientName: 'Client A',
          service: 'Design',
          amount: 100,
          dueDate: DateTime(2026, 4, 10),
          status: InvoiceStatus.draft,
          createdAt: DateTime(2026, 4, 3),
        );

        await notifier.recordPredictionOutcome(
          predictedClientId: null,
          predictedService: null,
          predictedAmount: 105,
          predictedDueDate: null,
          actualInvoice: actualInvoice,
        );

        final result = container
            .read(invoiceCreationLearningProvider)
            .predictionHistory
            .single;

        expect(result.amountAccuracy, equals(1.0));
        expect(result.accuracyScore, closeTo(0.30, 0.000001));
      });

      test('rejects amount prediction beyond 5 percent delta', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(
          invoiceCreationLearningProvider.notifier,
        );
        final actualInvoice = Invoice(
          id: 'inv-2',
          invoiceNumber: 'INV-002',
          clientId: 'client-a',
          clientName: 'Client A',
          service: 'Design',
          amount: 100,
          dueDate: DateTime(2026, 4, 10),
          status: InvoiceStatus.draft,
          createdAt: DateTime(2026, 4, 3),
        );

        await notifier.recordPredictionOutcome(
          predictedClientId: null,
          predictedService: null,
          predictedAmount: 105.01,
          predictedDueDate: null,
          actualInvoice: actualInvoice,
        );

        final result = container
            .read(invoiceCreationLearningProvider)
            .predictionHistory
            .single;

        expect(result.amountAccuracy, equals(0.0));
        expect(result.accuracyScore, equals(0.0));
      });
    });

    test('predicts client from combined frequency and recency signals', () {
      final now = DateTime(2026, 4, 3, 10);
      final clientA = _client(
        id: 'a',
        name: 'Alpha',
        createdAt: now.subtract(const Duration(days: 365)),
      );
      final clientB = _client(
        id: 'b',
        name: 'Beta',
        createdAt: now.subtract(const Duration(days: 365)),
      );

      final invoices = <Invoice>[
        for (var i = 0; i < 6; i++)
          _invoice(
            id: 'a-$i',
            client: clientA,
            service: 'Design',
            amount: 120,
            createdAt: now.subtract(Duration(days: i + 1)),
            dueDays: 14,
          ),
        for (var i = 0; i < 2; i++)
          _invoice(
            id: 'b-$i',
            client: clientB,
            service: 'Audit',
            amount: 300,
            createdAt: now.subtract(Duration(days: 80 + i)),
            dueDays: 7,
          ),
      ];

      final prediction = SmartInvoicePrediction.fromData(
        invoices: invoices,
        clients: <Client>[clientA, clientB],
        learning: _learningState(),
        adaptiveState: _adaptiveState(),
        now: now,
      );

      expect(prediction.suggestedClient?.id, equals(clientA.id));
      expect(
        prediction.clientConfidenceFor(clientA.id),
        greaterThan(prediction.clientConfidenceFor(clientB.id)),
      );
    });

    group('Confidence thresholds', () {
      test('maps to instant, prefilled, and manual modes', () {
        final now = DateTime(2026, 4, 3, 10);
        final client = _client(
          id: 'c-1',
          name: 'Threshold Client',
          createdAt: now.subtract(const Duration(days: 400)),
        );

        final highPrediction = _manualPrediction(
          client: client,
          clientConfidence: 0.92,
          serviceConfidence: 0.92,
          amountConfidence: 0.92,
          dueDateConfidence: 0.92,
          recencyConfidence: 0.92,
        );
        final mediumPrediction = _manualPrediction(
          client: client,
          clientConfidence: 0.68,
          serviceConfidence: 0.68,
          amountConfidence: 0.68,
          dueDateConfidence: 0.68,
          recencyConfidence: 0.68,
        );
        final lowPrediction = _manualPrediction(
          client: client,
          clientConfidence: 0.30,
          serviceConfidence: 0.30,
          amountConfidence: 0.30,
          dueDateConfidence: 0.30,
          recencyConfidence: 0.30,
        );

        final highDecision = highPrediction.buildPrimaryActionDecision(
          now: now,
        );
        final mediumDecision = mediumPrediction.buildPrimaryActionDecision(
          now: now,
        );
        final lowDecision = lowPrediction.buildPrimaryActionDecision(now: now);

        expect(highDecision.mode, equals(InvoiceAutomationMode.instant));
        expect(highDecision.tier, equals(InvoiceConfidenceTier.high));

        expect(
          mediumDecision.mode,
          equals(InvoiceAutomationMode.prefilledForm),
        );
        expect(mediumDecision.tier, equals(InvoiceConfidenceTier.medium));

        expect(lowDecision.mode, equals(InvoiceAutomationMode.manualForm));
        expect(lowDecision.tier, equals(InvoiceConfidenceTier.low));
      });
    });

    test('falls back safely when there is no invoice history', () {
      final now = DateTime(2026, 4, 3, 10);
      final client = _client(
        id: 'a',
        name: 'Alpha',
        createdAt: now.subtract(const Duration(days: 200)),
      );

      final prediction = SmartInvoicePrediction.fromData(
        invoices: const <Invoice>[],
        clients: <Client>[client],
        learning: _learningState(),
        adaptiveState: _adaptiveState(),
        now: now,
      );

      final decision = prediction.buildPrimaryActionDecision(now: now);
      final draft = prediction.buildQuickCreateDraft(now: now);

      expect(prediction.hasInvoiceHistory, isFalse);
      expect(decision.mode, equals(InvoiceAutomationMode.manualForm));
      expect(draft.clientId, equals(client.id));
      expect(draft.service, equals('General Service'));
      expect(draft.amount, equals(0.0));
      expect(draft.dueDays, equals(30));
    });

    test('predicts service patterns per client independently', () {
      final now = DateTime(2026, 4, 3, 10);
      final alpha = _client(
        id: 'alpha',
        name: 'Alpha',
        createdAt: now.subtract(const Duration(days: 300)),
      );
      final beta = _client(
        id: 'beta',
        name: 'Beta',
        createdAt: now.subtract(const Duration(days: 300)),
      );

      final invoices = <Invoice>[
        for (var i = 0; i < 4; i++)
          _invoice(
            id: 'a-main-$i',
            client: alpha,
            service: 'Design',
            amount: 150,
            createdAt: now.subtract(Duration(days: i + 1)),
            dueDays: 14,
          ),
        _invoice(
          id: 'a-alt',
          client: alpha,
          service: 'Audit',
          amount: 150,
          createdAt: now.subtract(const Duration(days: 20)),
          dueDays: 14,
        ),
        for (var i = 0; i < 4; i++)
          _invoice(
            id: 'b-main-$i',
            client: beta,
            service: 'SEO',
            amount: 220,
            createdAt: now.subtract(Duration(days: i + 2)),
            dueDays: 7,
          ),
        _invoice(
          id: 'b-alt',
          client: beta,
          service: 'Consulting',
          amount: 220,
          createdAt: now.subtract(const Duration(days: 21)),
          dueDays: 7,
        ),
      ];

      final prediction = SmartInvoicePrediction.fromData(
        invoices: invoices,
        clients: <Client>[alpha, beta],
        learning: _learningState(),
        adaptiveState: _adaptiveState(),
        now: now,
      );

      expect(prediction.suggestionFor(alpha.id)?.service, equals('Design'));
      expect(prediction.suggestionFor(beta.id)?.service, equals('SEO'));
    });

    test('learns due date patterns from historical due-day clusters', () {
      final now = DateTime(2026, 4, 3, 10);
      final client = _client(
        id: 'due-client',
        name: 'Due Client',
        createdAt: now.subtract(const Duration(days: 300)),
      );

      final invoices = <Invoice>[
        for (var i = 0; i < 5; i++)
          _invoice(
            id: 'due-14-$i',
            client: client,
            service: 'Retainer',
            amount: 400,
            createdAt: now.subtract(Duration(days: i + 1)),
            dueDays: 14,
          ),
        _invoice(
          id: 'due-30',
          client: client,
          service: 'Retainer',
          amount: 400,
          createdAt: now.subtract(const Duration(days: 50)),
          dueDays: 30,
        ),
      ];

      final prediction = SmartInvoicePrediction.fromData(
        invoices: invoices,
        clients: <Client>[client],
        learning: _learningState(),
        adaptiveState: _adaptiveState(),
        now: now,
      );

      expect(prediction.suggestionFor(client.id)?.suggestedDueDays, equals(14));
      expect(prediction.preferredDueDays, equals(14));
    });

    test('disables one-tap after 3 consecutive misses', () {
      final now = DateTime(2026, 4, 3, 10);
      final client = _client(
        id: 'safety-client',
        name: 'Safety Client',
        createdAt: now.subtract(const Duration(days: 300)),
      );

      final learning = _learningState(
        predictionHistory: <PredictionResult>[
          _wrongPredictionResult(now.subtract(const Duration(days: 3))),
          _wrongPredictionResult(now.subtract(const Duration(days: 2))),
          _wrongPredictionResult(now.subtract(const Duration(days: 1))),
        ],
      );

      expect(learning.isOneTapTemporarilyDisabled, isTrue);

      final blockedPrediction = _manualPrediction(
        client: client,
        clientConfidence: 0.95,
        serviceConfidence: 0.95,
        amountConfidence: 0.95,
        dueDateConfidence: 0.95,
        recencyConfidence: 0.95,
        recentAccuracyAverage: learning.recentAccuracyAverage,
        confidenceAdjustment: learning.confidenceAdjustment,
        oneTapTemporarilyDisabled: learning.isOneTapTemporarilyDisabled,
      );
      final allowedPrediction = _manualPrediction(
        client: client,
        clientConfidence: 0.95,
        serviceConfidence: 0.95,
        amountConfidence: 0.95,
        dueDateConfidence: 0.95,
        recencyConfidence: 0.95,
      );

      final blockedDecision = blockedPrediction.buildPrimaryActionDecision(
        now: now,
      );
      final allowedDecision = allowedPrediction.buildPrimaryActionDecision(
        now: now,
      );

      expect(blockedDecision.mode, equals(InvoiceAutomationMode.prefilledForm));
      expect(allowedDecision.mode, equals(InvoiceAutomationMode.instant));
    });

    test(
      'auto-tunes weights by increasing strong signals and reducing weak signals',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(
          invoiceCreationLearningProvider.notifier,
        );
        final initial = container
            .read(invoiceCreationLearningProvider)
            .predictionWeights;
        final now = DateTime(2026, 4, 3, 10);

        for (var i = 0; i < 6; i++) {
          final actualInvoice = Invoice(
            id: 'w-$i',
            invoiceNumber: 'INV-W-$i',
            clientId: 'client-1',
            clientName: 'Client 1',
            service: 'Actual Service',
            amount: 100,
            dueDate: DateTime(
              now.year,
              now.month,
              now.day,
            ).add(const Duration(days: 7)),
            status: InvoiceStatus.draft,
            createdAt: now.add(Duration(days: i)),
          );

          await notifier.recordPredictionOutcome(
            predictedClientId: 'client-1',
            predictedService: 'Wrong Service',
            predictedAmount: null,
            predictedDueDate: null,
            actualInvoice: actualInvoice,
          );
        }

        final tuned = container
            .read(invoiceCreationLearningProvider)
            .predictionWeights;
        final sum =
            tuned.clientWeight +
            tuned.serviceWeight +
            tuned.amountWeight +
            tuned.dueDateWeight +
            tuned.recencyWeight;

        expect(tuned.clientWeight, greaterThan(initial.clientWeight));
        expect(tuned.serviceWeight, lessThan(initial.serviceWeight));
        expect(sum, closeTo(1.0, 0.000001));
      },
    );

    test('handles amount outliers using median-centered suggestion', () {
      final now = DateTime(2026, 4, 3, 10);
      final client = _client(
        id: 'outlier-client',
        name: 'Outlier Client',
        createdAt: now.subtract(const Duration(days: 300)),
      );

      final invoices = <Invoice>[
        _invoice(
          id: 'o-1',
          client: client,
          service: 'Monthly Retainer',
          amount: 100,
          createdAt: now.subtract(const Duration(days: 1)),
          dueDays: 14,
        ),
        _invoice(
          id: 'o-2',
          client: client,
          service: 'Monthly Retainer',
          amount: 100,
          createdAt: now.subtract(const Duration(days: 2)),
          dueDays: 14,
        ),
        _invoice(
          id: 'o-3',
          client: client,
          service: 'Monthly Retainer',
          amount: 100,
          createdAt: now.subtract(const Duration(days: 3)),
          dueDays: 14,
        ),
        _invoice(
          id: 'o-4',
          client: client,
          service: 'Monthly Retainer',
          amount: 1000,
          createdAt: now.subtract(const Duration(days: 4)),
          dueDays: 14,
        ),
      ];

      final prediction = SmartInvoicePrediction.fromData(
        invoices: invoices,
        clients: <Client>[client],
        learning: _learningState(),
        adaptiveState: _adaptiveState(),
        now: now,
      );

      final suggestedAmount = prediction.suggestionFor(client.id)?.amount;
      expect(suggestedAmount, isNotNull);
      expect(suggestedAmount!, closeTo(100, 0.000001));
    });

    test('lets recency override older frequency-heavy patterns', () {
      final now = DateTime(2026, 4, 3, 10);
      final frequentOld = _client(
        id: 'legacy',
        name: 'Legacy',
        createdAt: now.subtract(const Duration(days: 500)),
      );
      final recent = _client(
        id: 'recent',
        name: 'Recent',
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      final invoices = <Invoice>[
        for (var i = 0; i < 7; i++)
          _invoice(
            id: 'legacy-$i',
            client: frequentOld,
            service: 'Legacy Service',
            amount: 180,
            createdAt: now.subtract(Duration(days: 220 + i)),
            dueDays: 30,
          ),
        for (var i = 0; i < 3; i++)
          _invoice(
            id: 'recent-$i',
            client: recent,
            service: 'Recent Service',
            amount: 180,
            createdAt: now.subtract(Duration(days: i + 1)),
            dueDays: 30,
          ),
      ];

      final learning = _learningState(
        lastClientId: recent.id,
        lastViewedClientId: recent.id,
        lastViewedClientAt: now.subtract(const Duration(minutes: 10)),
      );

      final prediction = SmartInvoicePrediction.fromData(
        invoices: invoices,
        clients: <Client>[frequentOld, recent],
        learning: learning,
        adaptiveState: _adaptiveState(
          lastAction: AdaptiveActionKey.addClient,
          lastActionAt: now.subtract(const Duration(hours: 1)),
        ),
        now: now,
      );

      expect(prediction.leadingClient?.id, equals(recent.id));
    });

    test('keeps confidence stable under minor data variation', () {
      final now = DateTime(2026, 4, 3, 10);
      final client = _client(
        id: 'stable-client',
        name: 'Stable Client',
        createdAt: now.subtract(const Duration(days: 400)),
      );

      final baselineInvoices = <Invoice>[
        for (var i = 0; i < 8; i++)
          _invoice(
            id: 's-base-$i',
            client: client,
            service: 'Support',
            amount: 120,
            createdAt: now.subtract(Duration(days: i + 1)),
            dueDays: 10,
          ),
      ];

      final slightlyChangedInvoices = <Invoice>[
        ...baselineInvoices,
        _invoice(
          id: 's-variant',
          client: client,
          service: 'Support',
          amount: 122,
          createdAt: now.subtract(const Duration(days: 9)),
          dueDays: 10,
        ),
      ];

      final baselinePrediction = SmartInvoicePrediction.fromData(
        invoices: baselineInvoices,
        clients: <Client>[client],
        learning: _learningState(),
        adaptiveState: _adaptiveState(),
        now: now,
      );
      final changedPrediction = SmartInvoicePrediction.fromData(
        invoices: slightlyChangedInvoices,
        clients: <Client>[client],
        learning: _learningState(),
        adaptiveState: _adaptiveState(),
        now: now,
      );

      final baselineDecision = baselinePrediction.buildPrimaryActionDecision(
        now: now,
      );
      final changedDecision = changedPrediction.buildPrimaryActionDecision(
        now: now,
      );

      expect(
        (changedDecision.confidenceScore - baselineDecision.confidenceScore)
            .abs(),
        lessThan(0.20),
      );
      expect(
        changedDecision.confidenceScore,
        greaterThanOrEqualTo(baselineDecision.confidenceScore - 0.15),
      );
    });

    test('uses safe defaults when no clients and no history exist', () {
      final now = DateTime(2026, 4, 3, 10);

      final prediction = SmartInvoicePrediction.fromData(
        invoices: const <Invoice>[],
        clients: const <Client>[],
        learning: _learningState(),
        adaptiveState: _adaptiveState(),
        now: now,
      );

      final decision = prediction.buildPrimaryActionDecision(now: now);
      final draft = prediction.buildQuickCreateDraft(now: now);

      expect(prediction.hasClients, isFalse);
      expect(decision.mode, equals(InvoiceAutomationMode.manualForm));
      expect(draft.clientId, equals('client-quick-general'));
      expect(draft.clientName, equals('General Client'));
      expect(draft.service, equals('General Service'));
      expect(draft.amount, equals(0.0));
      expect(draft.dueDays, equals(30));
    });

    test(
      'runs end-to-end with high confidence and fully correct prediction',
      () async {
        final now = DateTime(2026, 4, 3, 10);
        final client = _client(
          id: 'e2e-client',
          name: 'E2E Client',
          createdAt: now.subtract(const Duration(days: 500)),
        );

        final invoices = <Invoice>[
          for (var i = 0; i < 10; i++)
            _invoice(
              id: 'e2e-$i',
              client: client,
              service: 'Premium Support',
              amount: 500,
              createdAt: now.subtract(Duration(days: i + 1)),
              dueDays: 14,
            ),
        ];

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(
          invoiceCreationLearningProvider.notifier,
        );

        final prediction = SmartInvoicePrediction.fromData(
          invoices: invoices,
          clients: <Client>[client],
          learning: container.read(invoiceCreationLearningProvider),
          adaptiveState: _adaptiveState(),
          now: now,
        );

        final decision = prediction.buildPrimaryActionDecision(now: now);
        final draft = decision.draft;

        expect(decision.mode, equals(InvoiceAutomationMode.instant));
        expect(decision.confidenceScore, greaterThanOrEqualTo(0.80));
        expect(draft, isNotNull);
        expect(draft!.usedFallbackClient, isFalse);
        expect(draft.usedFallbackService, isFalse);
        expect(draft.usedFallbackAmount, isFalse);
        expect(draft.usedFallbackDueDays, isFalse);

        final actualInvoice = Invoice(
          id: 'e2e-actual',
          invoiceNumber: 'INV-E2E',
          clientId: draft.clientId,
          clientName: draft.clientName,
          service: draft.service,
          amount: draft.amount,
          dueDate: draft.dueDate,
          status: InvoiceStatus.draft,
          createdAt: now,
        );

        await notifier.recordPredictionOutcome(
          predictedClientId: draft.clientId,
          predictedService: draft.service,
          predictedAmount: draft.amount,
          predictedDueDate: draft.dueDate,
          actualInvoice: actualInvoice,
        );

        final result = container
            .read(invoiceCreationLearningProvider)
            .predictionHistory
            .last;

        expect(result.clientAccuracy, equals(1.0));
        expect(result.serviceAccuracy, equals(1.0));
        expect(result.amountAccuracy, equals(1.0));
        expect(result.dueDateAccuracy, equals(1.0));
        expect(result.accuracyScore, closeTo(1.0, 0.000001));
      },
    );
  });
}

Client _client({
  required String id,
  required String name,
  required DateTime createdAt,
}) {
  return Client(
    id: id,
    name: name,
    email: '$id@example.com',
    phone: '0000000000',
    createdAt: createdAt,
  );
}

Invoice _invoice({
  required String id,
  required Client client,
  required String service,
  required double amount,
  required DateTime createdAt,
  required int dueDays,
  InvoiceStatus status = InvoiceStatus.draft,
}) {
  final createdDateOnly = DateTime(
    createdAt.year,
    createdAt.month,
    createdAt.day,
  );
  return Invoice(
    id: id,
    invoiceNumber: 'INV-$id',
    clientId: client.id,
    clientName: client.name,
    service: service,
    amount: amount,
    dueDate: createdDateOnly.add(Duration(days: dueDays)),
    status: status,
    createdAt: createdAt,
  );
}

AdaptiveSystemState _adaptiveState({
  AdaptiveActionKey? lastAction,
  DateTime? lastActionAt,
}) {
  return AdaptiveSystemState(
    tabUsageCounts: const <String, int>{},
    actionUsageCounts: const <String, int>{},
    lastActionKey: lastAction?.name,
    lastActionAt: lastActionAt,
    lastActivityAt: lastActionAt,
    lastReminderSentAt: null,
    lastReminderOpportunityAt: null,
    ignoredReminderCount: 0,
  );
}

InvoiceCreationLearningState _learningState({
  String? lastClientId,
  String? lastViewedClientId,
  DateTime? lastViewedClientAt,
  Map<String, InvoiceCreationClientMemory>? clientMemories,
  PredictionModelWeights? predictionWeights,
  List<PredictionResult>? predictionHistory,
}) {
  return InvoiceCreationLearningState(
    lastClientId: lastClientId,
    dueDaysUsageCounts: const <String, int>{},
    amountUsageCounts: const <String, int>{},
    clientMemories:
        clientMemories ?? const <String, InvoiceCreationClientMemory>{},
    clientPredictionFeedback: const <String, PredictionFeedback>{},
    servicePredictionFeedback: const <String, PredictionFeedback>{},
    amountPredictionFeedback: const <String, PredictionFeedback>{},
    dueDaysPredictionFeedback: const <String, PredictionFeedback>{},
    lastViewedClientId: lastViewedClientId,
    lastViewedClientAt: lastViewedClientAt,
    predictionWeights:
        predictionWeights ?? const PredictionModelWeights.initial(),
    predictionHistory: predictionHistory ?? const <PredictionResult>[],
    openDetailAfterQuickCreate: false,
  );
}

PredictionResult _wrongPredictionResult(DateTime at) {
  return PredictionResult(
    predictedClientId: 'wrong-client',
    predictedService: 'wrong-service',
    predictedAmount: 10,
    predictedDueDate: at,
    actualClientId: 'actual-client',
    actualService: 'actual-service',
    actualAmount: 100,
    actualDueDate: DateTime(
      at.year,
      at.month,
      at.day,
    ).add(const Duration(days: 7)),
    clientAccuracy: 0.0,
    serviceAccuracy: 0.0,
    amountAccuracy: 0.0,
    dueDateAccuracy: 0.0,
    accuracyScore: 0.0,
    createdAt: at,
  );
}

SmartInvoicePrediction _manualPrediction({
  required Client client,
  required double clientConfidence,
  required double serviceConfidence,
  required double amountConfidence,
  required double dueDateConfidence,
  required double recencyConfidence,
  double recentAccuracyAverage = 0.60,
  double confidenceAdjustment = 0.0,
  bool oneTapTemporarilyDisabled = false,
}) {
  final suggestion = SmartClientSuggestion(
    client: client,
    clientConfidence: clientConfidence,
    service: 'Service',
    serviceConfidence: serviceConfidence,
    amount: 100,
    amountConfidence: amountConfidence,
    amountReason: 'typical',
    suggestedDueDays: 7,
    dueDaysConfidence: dueDateConfidence,
    recencyConfidence: recencyConfidence,
    overallConfidence: 1.0,
    latestInvoice: null,
  );

  return SmartInvoicePrediction(
    suggestedClient: client,
    suggestedClientReason: 'manual',
    suggestedClientConfidence: clientConfidence,
    leadingClient: client,
    leadingClientReason: 'manual',
    leadingClientConfidence: clientConfidence,
    preferredDueDays: 7,
    preferredDueDaysConfidence: dueDateConfidence,
    defaultDueDays: 7,
    quickAmount: 100,
    quickAmountReason: 'typical',
    quickAmountConfidence: amountConfidence,
    firstAvailableClient: client,
    hasInvoiceHistory: true,
    predictionWeights: const PredictionModelWeights.initial(),
    recentAccuracyAverage: recentAccuracyAverage,
    confidenceAdjustment: confidenceAdjustment,
    oneTapTemporarilyDisabled: oneTapTemporarilyDisabled,
    suggestionsByClient: <String, SmartClientSuggestion>{client.id: suggestion},
    clientConfidenceById: <String, double>{client.id: clientConfidence},
  );
}
