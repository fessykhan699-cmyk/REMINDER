import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_async_state_view.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/load_more_button.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
import '../../../subscription/presentation/widgets/usage_limit_nudge_card.dart';
import '../../../invoices/data/models/invoice_model.dart';
import '../../data/models/client_model.dart';
import '../../domain/entities/client.dart';
import '../controllers/clients_controller.dart';
import '../widgets/client_tile.dart';

class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  int _visibleItemCount = AppConstants.defaultPageSize;

  Widget _buildClientsList({
    required List<Client> clients,
    required SubscriptionState subscription,
    required SubscriptionUsage usage,
    required bool hasMore,
    required VoidCallback onLoadMore,
  }) {
    final showNudge = !subscription.isPro;
    final itemCount = clients.length + (showNudge ? 1 : 0) + (hasMore ? 1 : 0);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: appListViewPadding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showNudge && index == 0) {
          return UsageLimitNudgeCard(
            usage: usage,
            focus: UsageLimitFocus.clients,
            onUpgrade: () {
              const UpgradeToProRoute().push(context);
            },
          );
        }

        final dataIndex = index - (showNudge ? 1 : 0);
        if (hasMore && dataIndex == clients.length) {
          return Padding(
            padding: appCardPadding,
            child: Center(child: LoadMoreButton(onPressed: onLoadMore)),
          );
        }

        final client = clients[dataIndex];
        return ClientTile(
          client: client,
          onTap: () => ClientDetailRoute(client.id).push(context),
          onLongPress: () async {
            await _deleteClient(client);
          },
        );
      },
    );
  }

  List<Client> _sortedClients(Box<ClientModel> box) {
    final clients = box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return clients.toList(growable: false);
  }

  Future<void> _openAddClient() async {
    final decision = await ref
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.addClient);
    if (!decision.isAllowed) {
      if (!mounted) {
        return;
      }
      final upgraded = await promptUpgradeForDecision(context, decision);
      if (!upgraded || !mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }
    await const AddClientRoute().push(context);
  }

  void _loadMoreClients(int totalCount) {
    setState(() {
      _visibleItemCount = math.min(
        totalCount,
        _visibleItemCount + AppConstants.defaultPageSize,
      );
    });
  }

  Future<void> _deleteClient(Client client) async {
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

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(clientsControllerProvider.notifier)
          .deleteClient(client.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${client.name} deleted.')));
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(clientsControllerProvider);
    final controller = ref.read(clientsControllerProvider.notifier);
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
    final usage = ref.watch(subscriptionUsageProvider);
    final invoiceCount = Hive.isBoxOpen(HiveStorage.invoicesBoxName)
        ? Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName).length
        : 0;
    final hasClientsBox = Hive.isBoxOpen(HiveStorage.clientsBoxName);
    final emptyMessage = invoiceCount > 0
        ? 'Add a client to keep your future invoices organized.'
        : 'Add your first client to start invoicing faster.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            tooltip: 'New Client',
            onPressed: _openAddClient,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: hasClientsBox
                  ? ValueListenableBuilder<Box<ClientModel>>(
                      valueListenable: HiveStorage.clientsBox.listenable(),
                      builder: (context, box, _) {
                        final clients = _sortedClients(box);
                        if (clients.isEmpty) {
                          return AppEmptyState(
                            title: 'No clients yet',
                            message: emptyMessage,
                            action: FilledButton.icon(
                              onPressed: _openAddClient,
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Add Client'),
                            ),
                          );
                        }

                        final visibleCount = math.min(
                          clients.length,
                          _visibleItemCount,
                        );
                        final visibleClients = clients
                            .take(visibleCount)
                            .toList(growable: false);
                        return _buildClientsList(
                          clients: visibleClients,
                          subscription: subscription,
                          usage: usage,
                          hasMore: clients.length > visibleCount,
                          onLoadMore: () => _loadMoreClients(clients.length),
                        );
                      },
                    )
                  : AppAsyncStateView<List<Client>>(
                      state: controllerState,
                      onRetry: controller.loadInitial,
                      emptyTitle: 'No clients yet',
                      emptyMessage: emptyMessage,
                      emptyAction: FilledButton.icon(
                        onPressed: _openAddClient,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Add Client'),
                      ),
                      isEmpty: (data) => data.isEmpty,
                      builder: (clients) {
                        return _buildClientsList(
                          clients: clients,
                          subscription: subscription,
                          usage: usage,
                          hasMore: controller.hasMore,
                          onLoadMore: controller.loadMore,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
