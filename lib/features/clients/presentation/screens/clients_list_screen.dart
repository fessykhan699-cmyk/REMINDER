import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../shared/widgets/app_async_state_view.dart';
import '../../domain/entities/client.dart';
import '../controllers/clients_controller.dart';
import '../widgets/client_tile.dart';

class ClientsListScreen extends ConsumerWidget {
  const ClientsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientsControllerProvider);
    final controller = ref.read(clientsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: RefreshIndicator(
        onRefresh: controller.loadInitial,
        child: AppAsyncStateView<List<Client>>(
          state: state,
          onRetry: controller.loadInitial,
          emptyTitle: 'No clients yet',
          emptyMessage: 'Add your first client to start invoicing faster.',
          isEmpty: (data) => data.isEmpty,
          builder: (clients) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
              itemCount: clients.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
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
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => const AddClientRoute().push(context),
        label: const Text('Add Client'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
