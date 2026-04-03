import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../adaptive/adaptive_system_controller.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/invoices/presentation/controllers/invoices_controller.dart';
import '../../features/reminders/domain/entities/reminder.dart';
import '../../features/reminders/presentation/controllers/reminders_controller.dart';

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

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold>
    with WidgetsBindingObserver {
  final ValueNotifier<bool> _isFabExpanded = ValueNotifier<bool>(false);
  final ValueNotifier<_PredictedFabAction> _predictedAction =
      ValueNotifier<_PredictedFabAction>(
        const _PredictedFabAction.newInvoice(),
      );

  int? _lastTrackedBranchIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastTrackedBranchIndex = widget.navigationShell.currentIndex;
    _recordCurrentTabVisit();
    _refreshPrediction(
      ref.read(invoicesControllerProvider).valueOrNull,
      ref.read(adaptiveSystemProvider),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPrediction(
        ref.read(invoicesControllerProvider).valueOrNull,
        ref.read(adaptiveSystemProvider),
      );
    }
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
      _collapseFab();
      _refreshPrediction(
        ref.read(invoicesControllerProvider).valueOrNull,
        ref.read(adaptiveSystemProvider),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isFabExpanded.dispose();
    _predictedAction.dispose();
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

  void _refreshPrediction(
    List<Invoice>? invoices,
    AdaptiveSystemState adaptiveState,
  ) {
    if (invoices == null) {
      return;
    }

    final nextAction = _predictPrimaryAction(invoices, adaptiveState);
    if (_predictedAction.value != nextAction) {
      _predictedAction.value = nextAction;
    }
  }

  _PredictedFabAction _predictPrimaryAction(
    List<Invoice> invoices,
    AdaptiveSystemState adaptiveState,
  ) {
    final now = DateTime.now();
    Invoice? highestOverdue;
    Invoice? dueSoonCandidate;
    var unpaidCount = 0;

    for (final invoice in invoices) {
      if (invoice.status == InvoiceStatus.paid) {
        continue;
      }

      unpaidCount++;

      final isOverdue =
          invoice.status == InvoiceStatus.overdue ||
          invoice.dueDate.isBefore(now);
      if (isOverdue) {
        if (highestOverdue == null ||
            invoice.amount > highestOverdue.amount ||
            (invoice.amount == highestOverdue.amount &&
                invoice.dueDate.isBefore(highestOverdue.dueDate))) {
          highestOverdue = invoice;
        }
        continue;
      }

      final remainingTime = invoice.dueDate.difference(now);
      if (!remainingTime.isNegative &&
          remainingTime <= const Duration(hours: 24) &&
          (dueSoonCandidate == null ||
              invoice.dueDate.isBefore(dueSoonCandidate.dueDate) ||
              (invoice.dueDate.isAtSameMomentAs(dueSoonCandidate.dueDate) &&
                  invoice.amount > dueSoonCandidate.amount))) {
        dueSoonCandidate = invoice;
      }
    }

    if (highestOverdue != null) {
      return _PredictedFabAction.sendReminder(highestOverdue);
    }

    if (dueSoonCandidate != null) {
      return _PredictedFabAction.remindDueSoon(dueSoonCandidate);
    }

    if (unpaidCount > 3) {
      return const _PredictedFabAction.reviewPayments();
    }

    final preferredAction = adaptiveState.preferredFabAction;
    switch (preferredAction) {
      case AdaptiveActionKey.addClient:
        return const _PredictedFabAction.addClient();
      case AdaptiveActionKey.sendReminder:
        final reminderTarget = _pickReminderCandidate(invoices);
        if (reminderTarget != null) {
          return _PredictedFabAction.sendReminder(reminderTarget);
        }
      case AdaptiveActionKey.newInvoice:
      case AdaptiveActionKey.reviewPayments:
      case AdaptiveActionKey.markPaid:
      case null:
        break;
    }

    return const _PredictedFabAction.newInvoice();
  }

  void _toggleFab() {
    _isFabExpanded.value = !_isFabExpanded.value;
  }

  void _collapseFab() {
    if (_isFabExpanded.value) {
      _isFabExpanded.value = false;
    }
  }

  void _onDestinationSelected(int branchIndex) {
    _collapseFab();
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
    return state.orderedTabs.map(_navigationItemForTab).toList(growable: false);
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

  bool _isSettingsLocation(String location) {
    return location.startsWith(SettingsTabRoute.routePath);
  }

  String? _extractReminderInvoiceId(String location) {
    final match = RegExp(r'^/invoices/([^/]+)/reminder$').firstMatch(location);
    return match?.group(1);
  }

  String? _extractInvoiceRouteId(String location) {
    final editMatch = RegExp(r'^/invoices/edit/([^/]+)$').firstMatch(location);
    if (editMatch != null) {
      return editMatch.group(1);
    }

    final detailMatch = RegExp(r'^/invoices/([^/]+)$').firstMatch(location);
    if (detailMatch == null) {
      return null;
    }

    final invoiceId = detailMatch.group(1);
    if (invoiceId == null || invoiceId == 'create') {
      return null;
    }

    return invoiceId;
  }

  Invoice? _pickReminderCandidate(List<Invoice> invoices) {
    final unpaid = invoices
        .where((invoice) => invoice.status != InvoiceStatus.paid)
        .toList(growable: false);

    if (unpaid.isEmpty) {
      return null;
    }

    final sorted = [...unpaid]
      ..sort((a, b) {
        final amountCompare = b.amount.compareTo(a.amount);
        if (amountCompare != 0) {
          return amountCompare;
        }
        return a.dueDate.compareTo(b.dueDate);
      });

    return sorted.first;
  }

  Future<void> _openNewInvoice(BuildContext context) async {
    _collapseFab();
    await const CreateInvoiceRoute().push(context);
  }

  Future<void> _openNewClient(BuildContext context) async {
    _collapseFab();
    await const AddClientRoute().push(context);
  }

  Future<void> _openReviewPayments() async {
    _collapseFab();
    await ref
        .read(adaptiveSystemProvider.notifier)
        .recordAction(AdaptiveActionKey.reviewPayments);
    widget.navigationShell.goBranch(1, initialLocation: true);
  }

  String? _resolveReminderTargetInvoiceId({String? preferredInvoiceId}) {
    if (preferredInvoiceId != null) {
      return preferredInvoiceId;
    }

    final reminderInvoiceId = _extractReminderInvoiceId(widget.currentLocation);
    if (reminderInvoiceId != null) {
      return reminderInvoiceId;
    }

    final currentInvoiceId = _extractInvoiceRouteId(widget.currentLocation);
    if (currentInvoiceId != null) {
      return currentInvoiceId;
    }

    final invoices = ref.read(invoicesControllerProvider).valueOrNull;
    return _pickReminderCandidate(invoices ?? const <Invoice>[])?.id;
  }

  Future<void> _handleSendReminder(
    BuildContext context, {
    String? preferredInvoiceId,
  }) async {
    final targetInvoiceId = _resolveReminderTargetInvoiceId(
      preferredInvoiceId: preferredInvoiceId,
    );
    _collapseFab();

    if (targetInvoiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No unpaid invoices available for reminders.'),
        ),
      );
      return;
    }

    final activeReminderInvoiceId = _extractReminderInvoiceId(
      widget.currentLocation,
    );
    if (activeReminderInvoiceId == targetInvoiceId) {
      final reminderState = ref.read(
        reminderFlowControllerProvider(targetInvoiceId),
      );
      if (reminderState.invoice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reminder is still preparing. Try again in a moment.',
            ),
          ),
        );
        return;
      }

      await ref
          .read(reminderFlowControllerProvider(targetInvoiceId).notifier)
          .sendReminder(ReminderChannel.whatsapp);
      return;
    }

    await ReminderFlowRoute(targetInvoiceId).push(context);
  }

  List<_FabMenuAction> _buildFabActions(
    BuildContext context,
    _PredictedFabAction prediction,
  ) {
    final actions = <_FabMenuAction>[];

    void addAction(_FabMenuAction action) {
      final alreadyExists = actions.any((item) => item.id == action.id);
      if (!alreadyExists) {
        actions.add(action);
      }
    }

    switch (prediction.kind) {
      case _PredictedFabActionKind.sendReminder:
        addAction(
          _FabMenuAction(
            id: _FabMenuActionId.sendReminder,
            label: 'Send Reminder',
            icon: Icons.notifications_active_outlined,
            isHighlighted: true,
            onSelected: () => _handleSendReminder(
              context,
              preferredInvoiceId: prediction.targetInvoiceId,
            ),
          ),
        );
      case _PredictedFabActionKind.remindDueSoon:
        addAction(
          _FabMenuAction(
            id: _FabMenuActionId.remindDueSoon,
            label: 'Remind Due Soon',
            icon: Icons.notifications_none_rounded,
            isHighlighted: true,
            onSelected: () => _handleSendReminder(
              context,
              preferredInvoiceId: prediction.targetInvoiceId,
            ),
          ),
        );
      case _PredictedFabActionKind.reviewPayments:
        addAction(
          _FabMenuAction(
            id: _FabMenuActionId.reviewPayments,
            label: 'Review Payments',
            icon: Icons.checklist_rounded,
            isHighlighted: true,
            onSelected: _openReviewPayments,
          ),
        );
      case _PredictedFabActionKind.addClient:
        addAction(
          _FabMenuAction(
            id: _FabMenuActionId.addClient,
            label: 'Add Client',
            icon: Icons.person_add_alt_1_rounded,
            isHighlighted: true,
            onSelected: () => _openNewClient(context),
          ),
        );
      case _PredictedFabActionKind.newInvoice:
        addAction(
          _FabMenuAction(
            id: _FabMenuActionId.newInvoice,
            label: 'New Invoice',
            icon: Icons.receipt_long_outlined,
            isHighlighted: true,
            onSelected: () => _openNewInvoice(context),
          ),
        );
    }

    addAction(
      _FabMenuAction(
        id: _FabMenuActionId.newInvoice,
        label: 'New Invoice',
        icon: Icons.receipt_long_outlined,
        onSelected: () => _openNewInvoice(context),
      ),
    );
    addAction(
      _FabMenuAction(
        id: _FabMenuActionId.addClient,
        label: 'Add Client',
        icon: Icons.person_add_alt_1_rounded,
        onSelected: () => _openNewClient(context),
      ),
    );
    addAction(
      _FabMenuAction(
        id: _FabMenuActionId.sendReminder,
        label: 'Send Reminder',
        icon: Icons.send_rounded,
        onSelected: () => _handleSendReminder(context),
      ),
    );

    return actions;
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    if (_isSettingsLocation(widget.currentLocation) ||
        widget.navigationShell.currentIndex == 3) {
      return null;
    }

    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final fabBottomPadding = safeAreaBottom > 20 ? safeAreaBottom : 20.0;

    return ValueListenableBuilder<_PredictedFabAction>(
      valueListenable: _predictedAction,
      builder: (context, prediction, child) {
        return Padding(
          padding: EdgeInsets.only(right: 20, bottom: fabBottomPadding),
          child: _ShellContextFab(
            prediction: prediction,
            actions: _buildFabActions(context, prediction),
            isExpandedListenable: _isFabExpanded,
            onToggleExpanded: _toggleFab,
          ),
        );
      },
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

    ref.listen<AsyncValue<List<Invoice>>>(invoicesControllerProvider, (
      previous,
      next,
    ) {
      _refreshPrediction(next.valueOrNull, ref.read(adaptiveSystemProvider));
    });
    ref.listen<AdaptiveSystemState>(adaptiveSystemProvider, (previous, next) {
      _refreshPrediction(
        ref.read(invoicesControllerProvider).valueOrNull,
        next,
      );
    });

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.navigationShell,
          ValueListenableBuilder<bool>(
            valueListenable: _isFabExpanded,
            builder: (context, isExpanded, child) {
              return IgnorePointer(
                ignoring: !isExpanded,
                child: AnimatedOpacity(
                  opacity: isExpanded ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _collapseFab,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            border: Border(
              top: BorderSide(color: AppColors.accent.withValues(alpha: 0.12)),
            ),
          ),
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

enum _PredictedFabActionKind {
  newInvoice,
  addClient,
  sendReminder,
  remindDueSoon,
  reviewPayments,
}

class _PredictedFabAction {
  const _PredictedFabAction({
    required this.kind,
    required this.label,
    required this.icon,
    this.targetInvoiceId,
  });

  const _PredictedFabAction.newInvoice()
    : kind = _PredictedFabActionKind.newInvoice,
      label = 'New Invoice',
      icon = Icons.add,
      targetInvoiceId = null;

  const _PredictedFabAction.addClient()
    : kind = _PredictedFabActionKind.addClient,
      label = 'Add Client',
      icon = Icons.person_add_alt_1_rounded,
      targetInvoiceId = null;

  const _PredictedFabAction.reviewPayments()
    : kind = _PredictedFabActionKind.reviewPayments,
      label = 'Review Payments',
      icon = Icons.checklist_rounded,
      targetInvoiceId = null;

  factory _PredictedFabAction.sendReminder(Invoice invoice) {
    return _PredictedFabAction(
      kind: _PredictedFabActionKind.sendReminder,
      label: 'Send Reminder',
      icon: Icons.notifications_active_outlined,
      targetInvoiceId: invoice.id,
    );
  }

  factory _PredictedFabAction.remindDueSoon(Invoice invoice) {
    return _PredictedFabAction(
      kind: _PredictedFabActionKind.remindDueSoon,
      label: 'Remind Due Soon',
      icon: Icons.notifications_none_rounded,
      targetInvoiceId: invoice.id,
    );
  }

  final _PredictedFabActionKind kind;
  final String label;
  final IconData icon;
  final String? targetInvoiceId;

  bool get isPredicted => kind != _PredictedFabActionKind.newInvoice;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is _PredictedFabAction &&
        other.kind == kind &&
        other.label == label &&
        other.icon == icon &&
        other.targetInvoiceId == targetInvoiceId;
  }

  @override
  int get hashCode => Object.hash(kind, label, icon, targetInvoiceId);
}

enum _FabMenuActionId {
  newInvoice,
  addClient,
  sendReminder,
  remindDueSoon,
  reviewPayments,
}

class _FabMenuAction {
  const _FabMenuAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onSelected,
    this.isHighlighted = false,
  });

  final _FabMenuActionId id;
  final String label;
  final IconData icon;
  final Future<void> Function() onSelected;
  final bool isHighlighted;
}

class _ShellContextFab extends StatefulWidget {
  const _ShellContextFab({
    required this.prediction,
    required this.actions,
    required this.isExpandedListenable,
    required this.onToggleExpanded,
  });

  final _PredictedFabAction prediction;
  final List<_FabMenuAction> actions;
  final ValueListenable<bool> isExpandedListenable;
  final VoidCallback onToggleExpanded;

  @override
  State<_ShellContextFab> createState() => _ShellContextFabState();
}

class _ShellContextFabState extends State<_ShellContextFab>
    with TickerProviderStateMixin {
  bool _isPressed = false;
  late bool _isExpanded = widget.isExpandedListenable.value;

  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final AnimationController _expandController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: _isExpanded ? 1 : 0,
  );
  late final Animation<double> _entryOpacity = CurvedAnimation(
    parent: _entryController,
    curve: Curves.easeOut,
  );
  late final Animation<double> _entryOffset = Tween<double>(
    begin: 20,
    end: 0,
  ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
  late final Animation<double> _morphScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0.95,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 50,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.95,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 50,
    ),
  ]).animate(_expandController);
  late final Animation<double> _iconTurns = Tween<double>(
    begin: 0,
    end: 0.125,
  ).animate(CurvedAnimation(parent: _expandController, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    widget.isExpandedListenable.addListener(_handleExpandedChanged);
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) {
        return;
      }
      _entryController.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _ShellContextFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpandedListenable != widget.isExpandedListenable) {
      oldWidget.isExpandedListenable.removeListener(_handleExpandedChanged);
      _isExpanded = widget.isExpandedListenable.value;
      widget.isExpandedListenable.addListener(_handleExpandedChanged);
      _expandController.value = _isExpanded ? 1 : 0;
    }
  }

  @override
  void dispose() {
    widget.isExpandedListenable.removeListener(_handleExpandedChanged);
    _entryController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  void _handleExpandedChanged() {
    final nextExpanded = widget.isExpandedListenable.value;
    if (_isExpanded == nextExpanded) {
      return;
    }

    _isExpanded = nextExpanded;
    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  void _setPressed(bool value) {
    if (_isPressed == value) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    const baseBackgroundColor = Color(0xE51A1D22);
    const borderRadius = BorderRadius.all(Radius.circular(16));
    final borderColor = AppColors.accent.withValues(
      alpha: widget.prediction.isPredicted ? 0.60 : 0.45,
    );
    final foregroundColor = AppColors.textPrimary;
    final iconColor = foregroundColor.withValues(alpha: 0.92);
    final fillColor = _isPressed
        ? Color.alphaBlend(
            Colors.black.withValues(alpha: 0.05),
            baseBackgroundColor,
          )
        : baseBackgroundColor;
    final pressDuration = Duration(milliseconds: _isPressed ? 120 : 160);

    return FadeTransition(
      opacity: _entryOpacity,
      child: AnimatedBuilder(
        animation: _entryOffset,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _entryOffset.value),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < widget.actions.length; index++)
              _ShellFabMenuActionItem(
                action: widget.actions[index],
                animation: CurvedAnimation(
                  parent: _expandController,
                  curve: Interval(
                    index * 0.14,
                    (index * 0.14) + 0.70 > 1 ? 1.0 : (index * 0.14) + 0.70,
                    curve: Curves.easeOut,
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: _expandController,
              builder: (context, child) {
                final baseScale = _morphScale.value;
                final pressedScale = _isPressed ? 0.96 : 1.0;
                return Transform.scale(
                  scale: baseScale * pressedScale,
                  child: child,
                );
              },
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTapDown: (_) => _setPressed(true),
                  onTapUp: (_) => _setPressed(false),
                  onTapCancel: () => _setPressed(false),
                  onTap: () async {
                    await HapticFeedback.lightImpact();
                    widget.onToggleExpanded();
                  },
                  borderRadius: borderRadius,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  child: AnimatedContainer(
                    duration: pressDuration,
                    curve: Curves.easeOut,
                    height: 56,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: borderRadius,
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 168),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _iconTurns,
                              child: Icon(
                                widget.prediction.icon,
                                size: 18,
                                color: iconColor,
                              ),
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _iconTurns.value * 6.283185307179586,
                                  child: child,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.prediction.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: foregroundColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellFabMenuActionItem extends StatelessWidget {
  const _ShellFabMenuActionItem({
    required this.action,
    required this.animation,
  });

  final _FabMenuAction action;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.accent.withValues(
      alpha: action.isHighlighted ? 0.42 : 0.25,
    );
    final iconColor = action.isHighlighted
        ? AppColors.textPrimary
        : AppColors.textPrimary.withValues(alpha: 0.92);
    final textColor = action.isHighlighted
        ? AppColors.textPrimary
        : AppColors.textPrimary.withValues(alpha: 0.92);

    return AnimatedBuilder(
      animation: animation,
      child: SizedBox(
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await HapticFeedback.lightImpact();
              await action.onSelected();
            },
            borderRadius: BorderRadius.circular(14),
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xE51A1D22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 184),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(action.icon, size: 18, color: iconColor),
                      const SizedBox(width: 12),
                      Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: action.isHighlighted
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final value = animation.value;
        return IgnorePointer(
          ignoring: value == 0,
          child: Align(
            alignment: Alignment.centerRight,
            heightFactor: value,
            child: Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 20),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 12 * value),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
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
