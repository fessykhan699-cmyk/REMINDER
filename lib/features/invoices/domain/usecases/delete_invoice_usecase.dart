import '../../../reminders/domain/repositories/reminder_repository.dart';
import '../repositories/invoice_repository.dart';

class DeleteInvoiceUseCase {
  const DeleteInvoiceUseCase(this._invoiceRepository, this._reminderRepository);

  final InvoiceRepository _invoiceRepository;
  final ReminderRepository _reminderRepository;

  Future<void> call(String invoiceId) async {
    await _reminderRepository.deleteByInvoiceId(invoiceId);
    await _invoiceRepository.deleteInvoice(invoiceId);
  }
}
