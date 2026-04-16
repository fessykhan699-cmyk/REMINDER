import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firestore_sync_service.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';

/// Singleton FirestoreSyncService instance.
final firestoreSyncServiceProvider = Provider<FirestoreSyncService>(
  (ref) => FirestoreSyncService(),
);

/// The current authenticated user ID, or null if not logged in.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).session?.userId;
});
