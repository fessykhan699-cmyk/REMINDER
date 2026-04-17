import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/clients_controller.dart';
import '../../domain/entities/client.dart';

/// Managed search query state for the clients screen.
final clientSearchQueryProvider = StateProvider<String>((ref) => "");

/// Provides a filtered list of clients based on the current search query.
/// This is derived from the main clientsControllerProvider.
final filteredClientsProvider = Provider<AsyncValue<List<Client>>>((ref) {
  final query = ref.watch(clientSearchQueryProvider).trim().toLowerCase();
  final clientsAsync = ref.watch(clientsControllerProvider);

  try {
    return clientsAsync.whenData((clients) {
      if (query.isEmpty) {
        return clients;
      }

      return clients.where((client) {
        final matchesName = client.name.toLowerCase().contains(query);
        final matchesEmail = client.email.toLowerCase().contains(query);
        final matchesPhone = client.phone.toLowerCase().contains(query);
        
        return matchesName || matchesEmail || matchesPhone;
      }).toList();
    });
  } catch (error, stackTrace) {
    debugPrint('Client search filtering error: $error');
    debugPrintStack(stackTrace: stackTrace);
    // Return the original list on error as per requirements
    return clientsAsync;
  }
});
