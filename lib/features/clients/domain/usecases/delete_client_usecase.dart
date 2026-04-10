import '../../../invoices/domain/repositories/invoice_repository.dart';
import '../../../reminders/domain/repositories/reminder_repository.dart';
import '../repositories/client_repository.dart';

class DeleteClientUseCase {
  const DeleteClientUseCase(
    this._clientRepository,
    this._invoiceRepository,
    this._reminderRepository,
  );

  final ClientRepository _clientRepository;
  final InvoiceRepository _invoiceRepository;
  final ReminderRepository _reminderRepository;

  Future<void> call(String clientId) async {
    await _reminderRepository.deleteByClientId(clientId);
    await _invoiceRepository.deleteByClientId(clientId);
    await _clientRepository.deleteClient(clientId);
  }
}
