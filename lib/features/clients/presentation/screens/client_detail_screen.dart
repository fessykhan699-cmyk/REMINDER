import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_failure_state.dart';
import '../../domain/entities/client.dart';
import '../controllers/clients_controller.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientState = ref.watch(clientDetailProvider(clientId));

    return Scaffold(
      appBar: AppBar(title: const Text('Client Detail')),
      body: clientState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => AppFailureState(
          message: error.toString(),
          onRetry: () => ref.invalidate(clientDetailProvider(clientId)),
        ),
        data: (client) {
          if (client == null) {
            return const Center(child: Text('Client not found'));
          }
          return _DetailView(client: client);
        },
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(client.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Email'),
          subtitle: Text(client.email),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Phone'),
          subtitle: Text(client.phone),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Created At'),
          subtitle: Text(AppFormatters.shortDate(client.createdAt)),
        ),
      ],
    );
  }
}
