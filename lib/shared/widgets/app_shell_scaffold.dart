import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../adaptive/adaptive_system_controller.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_generator.dart';
import '../../features/clients/domain/entities/client.dart';
import '../../features/clients/presentation/controllers/clients_controller.dart';
import '../../features/invoices/domain/entities/invoice.dart';
import '../../features/invoices/presentation/controllers/invoice_creation_learning_controller.dart';
import '../../features/invoices/presentation/controllers/invoices_controller.dart';

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
  final ValueNotifier<_PredictedFabAction> _predictedAction =
      ValueNotifier<_PredictedFabAction>(
        const _PredictedFabAction.newInvoice(),
      );

  int? _lastTrackedBranchIndex;
  DateTime? _lastQuickCreateAt;
  String? _lastQuickCreateSignature;
  bool _isQuickCreating = false;
  int _quickCreateSuccessTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastTrackedBranchIndex = widget.navigationShell.currentIndex;
    ref.read(clientsControllerProvider);
    ref.read(invoiceCreationLearningProvider);
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
      _refreshPrediction(
        ref.read(invoicesControllerProvider).valueOrNull,
        ref.read(adaptiveSystemProvider),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final nextAction = _predictPrimaryAction(
      invoices ?? const <Invoice>[],
      adaptiveState,
    );
    if (_predictedAction.value != nextAction) {
      _predictedAction.value = nextAction;
    }
  }

  _PredictedFabAction _predictPrimaryAction(
    List<Invoice> invoices,
    AdaptiveSystemState adaptiveState,
  ) {
    return const _PredictedFabAction.newInvoice();
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

  Future<void> _openNewInvoice(BuildContext context) async {
    await const CreateInvoiceRoute().push(context);
  }

  CreateInvoiceIntelligence _buildCreateInvoiceIntelligence() {
    final invoices =
        ref.read(invoicesControllerProvider).valueOrNull ?? const <Invoice>[];
    final clients =
        ref.read(clientsControllerProvider).valueOrNull ?? const <Client>[];
    final learning = ref.read(invoiceCreationLearningProvider);

    return CreateInvoiceIntelligence.fromData(
      invoices: invoices,
      clients: clients,
      learning: learning,
    );
  }

  bool _isDuplicateQuickCreate(QuickCreateInvoiceDraft draft, DateTime now) {
    final lastQuickCreateAt = _lastQuickCreateAt;
    if (lastQuickCreateAt == null || _lastQuickCreateSignature == null) {
      return false;
    }

    return now.difference(lastQuickCreateAt) < const Duration(seconds: 2) &&
        _lastQuickCreateSignature == draft.dedupeSignature;
  }

  String _formatQuickCreateAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return '\$${amount.toStringAsFixed(0)}';
    }
    return AppFormatters.currency(amount);
  }

  void _triggerQuickCreateSuccess() {
    if (!mounted) {
      return;
    }

    setState(() {
      _quickCreateSuccessTick += 1;
    });
  }

  Future<void> _undoQuickCreate(BuildContext context, Invoice invoice) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(invoicesControllerProvider.notifier)
          .deleteInvoice(invoice.id);

      if (!mounted) {
        return;
      }

      if (_extractInvoiceRouteId(widget.currentLocation) == invoice.id) {
        widget.navigationShell.goBranch(1, initialLocation: true);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to undo the quick invoice right now.'),
        ),
      );
    }
  }

  Future<void> _handleQuickCreate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final learning = ref.read(invoiceCreationLearningProvider);
    final draft = _buildCreateInvoiceIntelligence().buildQuickDraft();
    final now = DateTime.now();

    if (_isQuickCreating || _isDuplicateQuickCreate(draft, now)) {
      return;
    }

    _isQuickCreating = true;
    _lastQuickCreateAt = now;
    _lastQuickCreateSignature = draft.dedupeSignature;

    try {
      final createdInvoice = await ref
          .read(invoicesControllerProvider.notifier)
          .createInvoice(
            Invoice(
              id: IdGenerator.nextId('inv'),
              clientId: draft.clientId,
              clientName: draft.clientName,
              service: draft.service,
              amount: draft.amount,
              dueDate: draft.dueDate,
              status: InvoiceStatus.pending,
              createdAt: now,
            ),
          );

      if (!mounted) {
        return;
      }

      _triggerQuickCreateSuccess();
      await HapticFeedback.selectionClick();

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Invoice created for ${createdInvoice.clientName} • ${_formatQuickCreateAmount(createdInvoice.amount)}',
            ),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                _undoQuickCreate(this.context, createdInvoice);
              },
            ),
          ),
        );

      if (learning.openDetailAfterQuickCreate) {
        if (!context.mounted) {
          return;
        }
        await InvoiceDetailRoute(createdInvoice.id).push(context);
      }
    } catch (_) {
      _lastQuickCreateAt = null;
      _lastQuickCreateSignature = null;

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to create a quick invoice right now.'),
        ),
      );
    } finally {
      _isQuickCreating = false;
    }
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
            successTick: _quickCreateSuccessTick,
            onPrimaryTap: () => _handleQuickCreate(context),
            onPrimaryLongPress: () => _openNewInvoice(context),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final adaptiveState = ref.watch(adaptiveSystemProvider);
    ref.watch(clientsControllerProvider);
    ref.watch(invoiceCreationLearningProvider);
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
      body: widget.navigationShell,
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

class _PredictedFabAction {
  const _PredictedFabAction.newInvoice()
    : label = 'Quick Invoice',
      icon = Icons.add;

  final String label;
  final IconData icon;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is _PredictedFabAction &&
        other.label == label &&
        other.icon == icon;
  }

  @override
  int get hashCode => Object.hash(label, icon);
}

class _ShellContextFab extends StatefulWidget {
  const _ShellContextFab({
    required this.prediction,
    required this.successTick,
    required this.onPrimaryTap,
    required this.onPrimaryLongPress,
  });

  final _PredictedFabAction prediction;
  final int successTick;
  final Future<void> Function() onPrimaryTap;
  final Future<void> Function() onPrimaryLongPress;

  @override
  State<_ShellContextFab> createState() => _ShellContextFabState();
}

class _ShellContextFabState extends State<_ShellContextFab>
    with TickerProviderStateMixin {
  bool _isPressed = false;
  bool _showSuccess = false;

  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _entryOpacity = CurvedAnimation(
    parent: _entryController,
    curve: Curves.easeOut,
  );
  late final Animation<double> _entryOffset = Tween<double>(
    begin: 20,
    end: 0,
  ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
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
    if (oldWidget.successTick != widget.successTick) {
      setState(() {
        _showSuccess = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || widget.successTick != oldWidget.successTick + 1) {
          return;
        }

        setState(() {
          _showSuccess = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
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
    final borderColor = AppColors.accent.withValues(alpha: 0.45);
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
        child: Transform.scale(
          scale: _isPressed ? 0.95 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              onTap: () async {
                await HapticFeedback.lightImpact();
                await widget.onPrimaryTap();
              },
              onLongPress: () async {
                _setPressed(false);
                await HapticFeedback.mediumImpact();
                await widget.onPrimaryLongPress();
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: _showSuccess
                              ? const Icon(
                                  Icons.check_rounded,
                                  key: ValueKey('fab-success'),
                                  size: 18,
                                  color: AppColors.textPrimary,
                                )
                              : Icon(
                                  widget.prediction.icon,
                                  key: const ValueKey('fab-default'),
                                  size: 18,
                                  color: iconColor,
                                ),
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
