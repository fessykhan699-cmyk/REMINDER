import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/clients/presentation/screens/add_client_screen.dart';
import '../../features/clients/presentation/screens/client_detail_screen.dart';
import '../../features/clients/presentation/screens/clients_list_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/invoices/presentation/screens/create_invoice_screen.dart';
import '../../features/invoices/presentation/screens/edit_invoice_screen.dart';
import '../../features/invoices/presentation/screens/invoice_detail_screen.dart';
import '../../features/invoices/presentation/screens/invoices_list_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/reminders/presentation/screens/reminder_flow_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../shared/widgets/app_shell_scaffold.dart';
import '../constants/app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: const SplashRoute().location,
    routes: [
      GoRoute(
        path: SplashRoute.routePath,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: OnboardingRoute.routePath,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: LoginRoute.routePath,
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: DashboardTabRoute.routePath,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: InvoicesTabRoute.routePath,
                builder: (context, state) => const InvoicesListScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const CreateInvoiceScreen(),
                  ),
                  GoRoute(
                    path: 'edit/:invoiceId',
                    builder: (context, state) {
                      final invoiceId = state.pathParameters['invoiceId'] ?? '';
                      return EditInvoiceScreen(invoiceId: invoiceId);
                    },
                  ),
                  GoRoute(
                    path: ':invoiceId/reminder',
                    builder: (context, state) {
                      final invoiceId = state.pathParameters['invoiceId'] ?? '';
                      return ReminderFlowScreen(invoiceId: invoiceId);
                    },
                  ),
                  GoRoute(
                    path: ':invoiceId',
                    builder: (context, state) {
                      final invoiceId = state.pathParameters['invoiceId'] ?? '';
                      return InvoiceDetailScreen(invoiceId: invoiceId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ClientsTabRoute.routePath,
                builder: (context, state) => const ClientsListScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const AddClientScreen(),
                  ),
                  GoRoute(
                    path: ':clientId',
                    builder: (context, state) {
                      final clientId = state.pathParameters['clientId'] ?? '';
                      return ClientDetailScreen(clientId: clientId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: SettingsTabRoute.routePath,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      final atSplash = location == SplashRoute.routePath;
      final atOnboarding = location == OnboardingRoute.routePath;
      final atLogin = location == LoginRoute.routePath;

      if (authState.status == AuthStatus.initializing) {
        return atSplash ? null : SplashRoute.routePath;
      }

      if (!authState.onboardingCompleted) {
        return atOnboarding ? null : OnboardingRoute.routePath;
      }

      if (authState.status == AuthStatus.unauthenticated) {
        return atLogin ? null : LoginRoute.routePath;
      }

      if (authState.status == AuthStatus.authenticated &&
          (atSplash || atOnboarding || atLogin)) {
        return DashboardTabRoute.routePath;
      }

      return null;
    },
  );
});
