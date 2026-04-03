abstract interface class NotificationService {
  Future<void> sendSms({required String phone, required String message});

  Future<void> sendWhatsApp({required String phone, required String message});
}
