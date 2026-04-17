import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../adaptive/adaptive_system_controller.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../features/invoices/presentation/controllers/invoice_creation_learning_controller.dart';
import '../../features/invoices/presentation/controllers/invoice_prediction_engine.dart';
import '../../features/settings/presentation/controllers/app_preferences_controller.dart';
import '../../features/subscription/domain/entities/subscription_state.dart';
import '../../features/subscription/presentation/controllers/subscription_controller.dart';
import '../../features/subscription/presentation/widgets/upgrade_prompt_sheet.dart';

class AppShellScaffold extends ConsumerStatefulWidget {
  const AppShellScaffold({
    super.key,
    required this.navigationShell,
    required this.currentLocation,
  });

  final StatefulNavigationShell navigationShell;
  final String currentLocation;

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  int? _lastTrackedBranchIndex;
  List<AdaptiveTabKey>? _cachedTabOrder;
  List<_AdaptiveNavItem>? _cachedNavItems;

  static final _clientIdRegExp = RegExp(r'^/clients/([^/]+)$');
  static const _navBorderDecoration = BoxDecoration(
    color: AppColors.backgroundPrimary,
    border: Border(
      top: BorderSide(color: Color(0x1FC8A96A)), // AppColors.accent (0xFFC8A96A) at alpha 0.12
    ),
  );

  @override
  void initState() {
    super.initState();
    _lastTrackedBranchIndex = widget.navigationShell.currentIndex;
    _recordCurrentTabVisit();
    _recordLocationContext();
  }

  @override
  void didUpdateWidget(covariant AppShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _lastTrackedBranchIndex = widget.navigationShell.currentIndex;
      _recordCurrentTabVisit();
    }
    if (oldWidget.currentLocation != widget.currentLocation) {
      _recordLocationContext();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _recordCurrentTabVisit() async {
    final branchIndex = _lastTrackedBranchIndex;
    if (branchIndex == null) {
      return;
    }

    await ref
        .read(adaptiveSystemProvider.notifier)
        .recordTabVisit(_tabForBranchIndex(branchIndex));
  }

  Future<void> _recordLocationContext() async {
    final viewedClientId = _extractViewedClientId(widget.currentLocation);
    if (viewedClientId == null) {
      return;
    }

    await ref
        .read(invoiceCreationLearningProvider.notifier)
        .recordViewedClient(viewedClientId);
  }

  void _onDestinationSelected(int branchIndex) {
    widget.navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == widget.navigationShell.currentIndex,
    );
  }

  AdaptiveTabKey _tabForBranchIndex(int branchIndex) {
    switch (branchIndex) {
      case 0:
        return AdaptiveTabKey.dashboard;
      case 1:
        return AdaptiveTabKey.invoices;
      case 2:
        return AdaptiveTabKey.clients;
      case 3:
        return AdaptiveTabKey.settings;
      default:
        return AdaptiveTabKey.dashboard;
    }
  }

  int _branchIndexForTab(AdaptiveTabKey tab) {
    switch (tab) {
      case AdaptiveTabKey.dashboard:
        return 0;
      case AdaptiveTabKey.invoices:
        return 1;
      case AdaptiveTabKey.clients:
        return 2;
      case AdaptiveTabKey.settings:
        return 3;
    }
  }

  List<_AdaptiveNavItem> _buildNavigationItems(AdaptiveSystemState state) {
    final tabs = state.orderedTabs;
    if (_cachedTabOrder != null &&
        _cachedNavItems != null &&
        _listsEqual(_cachedTabOrder!, tabs)) {
      return _cachedNavItems!;
    }
    _cachedTabOrder = tabs;
    _cachedNavItems = tabs.map(_navigationItemForTab).toList(growable: false);
    return _cachedNavItems!;
  }

  static bool _listsEqual(List<AdaptiveTabKey> a, List<AdaptiveTabKey> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  _AdaptiveNavItem _navigationItemForTab(AdaptiveTabKey tab) {
    switch (tab) {
      case AdaptiveTabKey.dashboard:
        return _AdaptiveNavItem(
          tab: tab,
          branchIndex: _branchIndexForTab(tab),
          destination: const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Dashboard',
          ),
        );
      case AdaptiveTabKey.invoices:
        return _AdaptiveNavItem(
          tab: tab,
          branchIndex: _branchIndexForTab(tab),
          destination: const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Invoices',
          ),
        );
      case AdaptiveTabKey.clients:
        return _AdaptiveNavItem(
          tab: tab,
          branchIndex: _branchIndexForTab(tab),
          destination: const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Clients',
          ),
        );
      case AdaptiveTabKey.settings:
        return _AdaptiveNavItem(
          tab: tab,
          branchIndex: _branchIndexForTab(tab),
          destination: const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        );
    }
  }

  String? _extractViewedClientId(String location) {
    final match = _clientIdRegExp.firstMatch(location);
    final clientId = match?.group(1);
    if (clientId == null || clientId == 'add') {
      return null;
    }
    return clientId;
  }

  Future<void> _openNewInvoiceWithMode(
    BuildContext context, {
    required InvoiceCreateLaunchMode launchMode,
  }) async {
    final launchModeNotifier = ref.read(
      invoiceCreateLaunchModeProvider.notifier,
    );
    launchModeNotifier.state = launchMode;

    try {
      await const CreateInvoiceRoute().push(context);
    } finally {
      launchModeNotifier.state = InvoiceCreateLaunchMode.assisted;
    }
  }

  Future<bool> _ensureFeatureAccess(
    BuildContext context,
    SubscriptionGateFeature feature,
  ) async {
    final decision = await ref
        .read(subscriptionGatekeeperProvider)
        .evaluate(feature);
    if (decision.isAllowed) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }
    return promptUpgradeForDecision(context, decision);
  }

  Future<void> _handleFabTap(BuildContext context) async {
    await HapticFeedback.lightImpact();
    if (!context.mounted) {
      return;
    }

    final action = await _showFabActionSheet(context);
    if (!context.mounted || action == null) {
      return;
    }

    await _handleFabSheetAction(context, action);
  }

  Future<_FabSheetAction?> _showFabActionSheet(BuildContext context) {
    return showModalBottomSheet<_FabSheetAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.backgroundSecondary,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('Create Invoice'),
                onTap: () {
                  Navigator.of(sheetContext).pop(_FabSheetAction.createInvoice);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('Add Client'),
                onTap: () {
                  Navigator.of(sheetContext).pop(_FabSheetAction.addClient);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_rounded),
                title: const Text('Send Reminder'),
                onTap: () {
                  Navigator.of(sheetContext).pop(_FabSheetAction.sendReminder);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleFabSheetAction(
    BuildContext context,
    _FabSheetAction action,
  ) async {
    switch (action) {
      case _FabSheetAction.createInvoice:
        final canCreateInvoice = await _ensureFeatureAccess(
          context,
          SubscriptionGateFeature.createInvoice,
        );
        if (!canCreateInvoice || !context.mounted) {
          return;
        }

        final preferences = ref
            .read(appPreferencesControllerProvider)
            .valueOrNull;
        if (!context.mounted) {
          return;
        }
        await _openNewInvoiceWithMode(
          context,
          launchMode: preferences?.oneTapInvoiceEnabled ?? true
              ? InvoiceCreateLaunchMode.assisted
              : InvoiceCreateLaunchMode.manual,
        );
        return;
      case _FabSheetAction.addClient:
        final canAddClient = await _ensureFeatureAccess(
          context,
          SubscriptionGateFeature.addClient,
        );
        if (!canAddClient || !context.mounted) {
          return;
        }

        if (!context.mounted) {
          return;
        }
        await const AddClientRoute().push(context);
        return;
      case _FabSheetAction.sendReminder:
        if (!context.mounted) {
          return;
        }
        const InvoicesTabRoute().go(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Open an invoice to send a reminder.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
    }
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    if (widget.currentLocation.startsWith(SettingsTabRoute.routePath)) {
      return null;
    }

    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final fabBottomPadding = safeAreaBottom + 80.0;

    return Padding(
      padding: EdgeInsets.only(right: 20, bottom: fabBottomPadding),
      child: FloatingActionButton(
        heroTag: 'new_invoice_fab',
        tooltip: 'Quick actions',
        onPressed: () => _handleFabTap(context),
        shape: const CircleBorder(),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adaptiveState = ref.watch(adaptiveSystemProvider);
    final navigationItems = _buildNavigationItems(adaptiveState);
    final selectedIndex = navigationItems.indexWhere(
      (item) => item.branchIndex == widget.navigationShell.currentIndex,
    );
    final navigationKey = navigationItems
        .map((item) => item.tab.name)
        .join('|');

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: widget.navigationShell,
      floatingActionButton: _buildFloatingActionButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: _navBorderDecoration,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final offsetAnimation =
                  Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  );

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: NavigationBar(
              key: ValueKey(navigationKey),
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (index) {
                _onDestinationSelected(navigationItems[index].branchIndex);
              },
              destinations: navigationItems
                  .map((item) => item.destination)
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdaptiveNavItem {
  const _AdaptiveNavItem({
    required this.tab,
    required this.branchIndex,
    required this.destination,
  });

  final AdaptiveTabKey tab;
  final int branchIndex;
  final NavigationDestination destination;
}

enum _FabSheetAction { createInvoice, addClient, sendReminder }
