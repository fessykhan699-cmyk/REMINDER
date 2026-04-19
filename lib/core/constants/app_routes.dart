import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const String teamMembers = '/team-members';
}

sealed class AppRouteSpec {
  const AppRouteSpec();

  String get path;
  String get location;

  void go(BuildContext context) => context.go(location);

  Future<T?> push<T>(BuildContext context) => context.push<T>(location);
}

final class SplashRoute extends AppRouteSpec {
  const SplashRoute();

  static const String routePath = '/';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class OnboardingRoute extends AppRouteSpec {
  const OnboardingRoute();

  static const String routePath = '/onboarding';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class LoginRoute extends AppRouteSpec {
  const LoginRoute();

  static const String routePath = '/login';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class EmailVerificationRoute extends AppRouteSpec {
  const EmailVerificationRoute();

  static const String routePath = '/verify-email';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class DashboardTabRoute extends AppRouteSpec {
  const DashboardTabRoute();

  static const String routePath = '/dashboard';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class InvoicesTabRoute extends AppRouteSpec {
  const InvoicesTabRoute();

  static const String routePath = '/invoices';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class ClientsTabRoute extends AppRouteSpec {
  const ClientsTabRoute();

  static const String routePath = '/clients';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class SettingsTabRoute extends AppRouteSpec {
  const SettingsTabRoute();

  static const String routePath = '/settings';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class ExpensesTabRoute extends AppRouteSpec {
  const ExpensesTabRoute();

  static const String routePath = '/expenses';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class AddClientRoute extends AppRouteSpec {
  const AddClientRoute();

  static const String routePath = '/clients/add';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class ClientDetailRoute extends AppRouteSpec {
  const ClientDetailRoute(this.clientId);

  static const String routePath = '/clients/:clientId';
  final String clientId;

  @override
  String get path => routePath;

  @override
  String get location => '/clients/$clientId';
}

final class CreateInvoiceRoute extends AppRouteSpec {
  const CreateInvoiceRoute();

  static const String routePath = '/invoices/create';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class InvoiceDetailRoute extends AppRouteSpec {
  const InvoiceDetailRoute(this.invoiceId);

  static const String routePath = '/invoices/:invoiceId';
  final String invoiceId;

  @override
  String get path => routePath;

  @override
  String get location => '/invoices/$invoiceId';
}

final class EditInvoiceRoute extends AppRouteSpec {
  const EditInvoiceRoute(this.invoiceId);

  static const String routePath = '/invoices/edit/:invoiceId';
  final String invoiceId;

  @override
  String get path => routePath;

  @override
  String get location => '/invoices/edit/$invoiceId';
}

final class ReminderFlowRoute extends AppRouteSpec {
  const ReminderFlowRoute(this.invoiceId);

  static const String routePath = '/invoices/:invoiceId/reminder';
  final String invoiceId;

  @override
  String get path => routePath;

  @override
  String get location => '/invoices/$invoiceId/reminder';
}

final class UpgradeToProRoute extends AppRouteSpec {
  const UpgradeToProRoute();

  static const String routePath = '/upgrade';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class AddExpenseRoute extends AppRouteSpec {
  const AddExpenseRoute();

  static const String routePath = '/expenses/add';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class TeamMembersRoute extends AppRouteSpec {
  const TeamMembersRoute();

  static const String routePath = AppRoutes.teamMembers;

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class ForgotPasswordRoute extends AppRouteSpec {
  const ForgotPasswordRoute();

  static const String routePath = '/forgot-password';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class ResetPasswordRoute extends AppRouteSpec {
  const ResetPasswordRoute({this.code});

  static const String routePath = '/reset-password';
  final String? code;

  @override
  String get path => routePath;

  @override
  String get location {
    if (code != null) {
      return '$routePath?oobCode=$code';
    }
    return routePath;
  }
}

final class SignUpRoute extends AppRouteSpec {
  const SignUpRoute();

  static const String routePath = '/signup';

  @override
  String get path => routePath;

  @override
  String get location => routePath;
}

final class EmailSentRoute extends AppRouteSpec {
  const EmailSentRoute({required this.email});

  static const String routePath = '/email-sent';
  final String email;

  @override
  String get path => routePath;

  @override
  String get location => '$routePath?email=$email';
}
