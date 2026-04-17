// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reminder/features/clients/domain/entities/client.dart';
import 'package:reminder/features/clients/domain/repositories/client_repository.dart';
import 'package:reminder/features/invoices/domain/entities/invoice.dart';
import 'package:reminder/features/settings/domain/entities/app_preferences.dart';
import 'package:reminder/features/settings/domain/entities/profile.dart';
import 'package:reminder/features/settings/domain/repositories/settings_repository.dart';
import 'package:reminder/features/settings/domain/usecases/get_profile_usecase.dart';
import 'package:reminder/shared/services/invoice_pdf_export_service.dart';
import 'package:reminder/shared/services/invoice_pdf_profile_hook.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;
  late InvoicePdfExportService service;
  late Invoice invoice;

  setUp(() async {
    originalPathProvider = PathProviderPlatform.instance;
    tempDir = await Directory.systemTemp.createTemp('invoice_pdf_smoke_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

    service = InvoicePdfExportService(
      profileHook: InvoicePdfProfileHook(
        GetProfileUseCase(_FakeSettingsRepository()),
      ),
      clientRepository: _FakeClientRepository(),
    );

    invoice = Invoice(
      id: 'INV/TEST-001',
      invoiceNumber: 'INV-001',
      clientId: 'client-001',
      clientName: 'Acme Studio',
      service: 'Design',
      amount: 550,
      dueDate: DateTime(2026, 4, 20),
      status: InvoiceStatus.draft,
      createdAt: DateTime(2026, 4, 5),
      currencyCode: 'USD',
      taxPercent: 10,
    );
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates and saves a local invoice pdf file', () async {
    final document = await service.generateInvoicePdfDocument(
      invoice,
      includeWatermark: true,
      isPro: false,
      saveLocally: true,
    );

    expect(document.bytes, isNotEmpty);
    expect(document.filename, 'invoice_inv_test-001.pdf');
    expect(document.savedFilePath, isNotNull);

    final savedFile = File(document.savedFilePath!);
    expect(await savedFile.exists(), isTrue);
    expect(savedFile.parent.path.endsWith('invoice_pdfs'), isTrue);
    expect(await savedFile.length(), document.bytes.length);
  });

  test('changes output when the watermark flag changes', () async {
    final freeDocument = await service.generateInvoicePdfDocument(
      invoice,
      includeWatermark: true,
      isPro: false,
    );
    final proDocument = await service.generateInvoicePdfDocument(
      invoice,
      includeWatermark: false,
      isPro: true,
    );

    expect(freeDocument.bytes, isNot(equals(proDocument.bytes)));
  });
}

class _FakeClientRepository implements ClientRepository {
  @override
  Future<Client> addClient(Client client) async => client;

  @override
  Future<void> deleteClient(String id) async {}

  @override
  Future<Client?> getClientById(String id) async {
    return Client(
      id: id,
      name: 'Acme Studio',
      email: 'billing@acme.test',
      phone: '+15551234567',
      createdAt: DateTime(2026, 4, 1),
    );
  }

  @override
  Future<List<Client>> getClients({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    return const <Client>[];
  }

  @override
  Future<Client> updateClient(Client client) async => client;
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<AppPreferences> getAppPreferences() async {
    return const AppPreferences.defaults();
  }

  @override
  Future<UserProfile> getProfile() async {
    return const UserProfile(
      name: 'John Doe',
      email: 'john@invoiceflow.test',
      businessName: 'Invoice Flow Studio',
      phone: '+15557654321',
      address: '45 Market Street, Suite 9',
    );
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

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationCachePath() async => documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => documentsPath;

  @override
  Future<String?> getDownloadsPath() async => documentsPath;

  @override
  Future<List<String>?> getExternalCachePaths() async => <String>[
    documentsPath,
  ];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => <String>[documentsPath];

  @override
  Future<String?> getLibraryPath() async => documentsPath;

  @override
  Future<String?> getTemporaryPath() async => documentsPath;
}
