import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/app_async_state_view.dart';
import '../../../invoices/presentation/controllers/invoices_controller.dart';
import '../../domain/entities/client.dart';
import '../controllers/clients_controller.dart';
import '../widgets/client_tile.dart';

class ClientsListScreen extends ConsumerWidget {
  const ClientsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientsControllerProvider);
    final invoicesState = ref.watch(invoicesControllerProvider);
    final controller = ref.read(clientsControllerProvider.notifier);
    final invoiceCount = invoicesState.valueOrNull?.length ?? 0;
    final emptyMessage = invoiceCount > 0
        ? 'Add a client to keep your future invoices organized.'
        : 'Add your first client to start invoicing faster.';

    Future<void> deleteClient(Client client) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delete client?'),
            content: Text('Remove ${client.name} from your saved clients?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !context.mounted) {
        return;
      }

      try {
        await controller.deleteClient(client.id);
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${client.name} deleted.')));
      } on AppException catch (error) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: RefreshIndicator(
        onRefresh: controller.loadInitial,
        child: AppAsyncStateView<List<Client>>(
          state: state,
          onRetry: controller.loadInitial,
          emptyTitle: 'No clients yet',
          emptyMessage: emptyMessage,
          isEmpty: (data) => data.isEmpty,
          builder: (clients) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
              itemCount: clients.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == clients.length) {
                  if (!controller.hasMore) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: controller.loadMore,
                      child: const Text('Load more'),
                    ),
                  );
                }

                final client = clients[index];
                return ClientTile(
                  client: client,
                  onTap: () => ClientDetailRoute(client.id).push(context),
                  onLongPress: () async {
                    await deleteClient(client);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
