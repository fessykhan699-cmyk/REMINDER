import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/components/app_scaffold.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../invoices/data/models/invoice_model.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../subscription/presentation/widgets/upgrade_prompt_sheet.dart';
import '../../../subscription/presentation/widgets/usage_limit_nudge_card.dart';

import '../../domain/entities/client.dart';
import '../controllers/clients_controller.dart';
import '../providers/client_search_provider.dart';
import '../widgets/client_tile.dart';

class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  int _visibleItemCount = AppConstants.defaultPageSize;

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void dispose() {
    _entryCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _staggeredItem({required int index, required Widget child}) {
    final begin = (index * 0.10).clamp(0.0, 0.80);
    return AnimatedBuilder(
      animation: _entryCtrl,
      child: child,
      builder: (context, stableChild) {
        final progress = Curves.easeOut.transform(
          Interval(begin, 1.0).transform(_entryCtrl.value),
        );
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * 8),
            child: stableChild,
          ),
        );
      },
    );
  }



  Future<void> _openAddClient() async {
    final decision = await ref
        .read(subscriptionGatekeeperProvider)
        .evaluate(SubscriptionGateFeature.addClient);
    if (!decision.isAllowed) {
      if (!mounted) return;
      final upgraded = await promptUpgradeForDecision(context, decision);
      if (!upgraded || !mounted) return;
    }
    if (!mounted) return;
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

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(clientsControllerProvider.notifier)
          .deleteClient(client.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${client.name} deleted.')),
      );
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
    final usage = ref.watch(subscriptionUsageProvider);
    final invoiceCount = Hive.isBoxOpen(HiveStorage.invoicesBoxName)
        ? Hive.box<InvoiceModel>(HiveStorage.invoicesBoxName).length
        : 0;
    final emptyMessage = invoiceCount > 0
        ? 'Add a client to keep your future invoices organized.'
        : 'Add your first client to start invoicing faster.';

    final clientsAsync = ref.watch(filteredClientsProvider);
    final searchQuery = ref.watch(clientSearchQueryProvider);

    return AppScaffold(
      extendBody: true,
      body: SafeArea(
        child: clientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (clients) {
            final visibleCount = math.min(clients.length, _visibleItemCount);
            final visibleClients = clients.take(visibleCount).toList(growable: false);
            final showNudge = !subscription.isPro;
            final hasMore = clients.length > visibleCount;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      spacingMD,
                      spacingMD,
                      spacingMD,
                      spacingXS,
                    ),
                    child: _staggeredItem(
                      index: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              'Clients',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'New Client',
                            onPressed: _openAddClient,
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  AppColors.accent.withValues(alpha: 0.14),
                              foregroundColor: AppColors.textPrimary,
                              shape: const CircleBorder(),
                            ),
                            icon: const Icon(
                              Icons.person_add_alt_1_outlined,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Search Bar ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: spacingMD,
                      vertical: spacingSM,
                    ),
                    child: _staggeredItem(
                      index: 1,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          ref.read(clientSearchQueryProvider.notifier).state = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name, email, or phone',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(clientSearchQueryProvider.notifier).state = "";
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                if (clients.isEmpty && searchQuery.isNotEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(spacingLG),
                        child: Text(
                          'No clients match your search',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (clients.isEmpty && searchQuery.isEmpty)
                  SliverFillRemaining(
                    child: AppEmptyState(
                      title: 'No clients yet',
                      message: emptyMessage,
                      action: FilledButton.icon(
                        onPressed: _openAddClient,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Add Client'),
                      ),
                    ),
                  )
                else ...[
                  // ── Usage nudge ──
                  if (showNudge)
                    SliverToBoxAdapter(
                      child: _staggeredItem(
                        index: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: spacingMD,
                            vertical: spacingSM,
                          ),
                          child: UsageLimitNudgeCard(
                            usage: usage,
                            focus: UsageLimitFocus.clients,
                            onUpgrade: () {
                              const UpgradeToProRoute().push(context);
                            },
                          ),
                        ),
                      ),
                    ),

                  // ── Client list ──
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final client = visibleClients[index];
                        return _staggeredItem(
                          index: index + (showNudge ? 3 : 2),
                          child: ClientTile(
                            client: client,
                            onTap: () => ClientDetailRoute(client.id).push(context),
                            onLongPress: () async {
                              await _deleteClient(client);
                            },
                          ),
                        );
                      },
                      childCount: visibleClients.length,
                    ),
                  ),

                  // ── Load more ──
                  if (hasMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: appCardPadding,
                        child: Center(
                          child: TextButton(
                            onPressed: () => _loadMoreClients(clients.length),
                            child: const Text('Load more'),
                          ),
                        ),
                      ),
                    ),

                  // ── Bottom padding ──
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 100,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
