# Graph Report - reminder  (2026-04-22)

## Corpus Check
- 257 files · ~128,754 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1982 nodes · 2606 edges · 55 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 13 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter_riverpod/flutter_riverpod.dart` - 81 edges
2. `package:flutter/material.dart` - 67 edges
3. `../../core/theme/app_colors.dart` - 38 edges
4. `package:flutter/foundation.dart` - 34 edges
5. `package:hive/hive.dart` - 22 edges
6. `package:flutter_test/flutter_test.dart` - 18 edges
7. `../../features/invoices/domain/entities/invoice.dart` - 17 edges
8. `../../../subscription/presentation/controllers/subscription_controller.dart` - 17 edges
9. `../../core/utils/formatters.dart` - 17 edges
10. `../../../../shared/components/glass_card.dart` - 17 edges

## Surprising Connections (you probably didn't know these)
- `OnCreate()` --calls--> `RegisterPlugins()`  [INFERRED]
  windows\runner\flutter_window.cpp → windows\flutter\generated_plugin_registrant.cc
- `OnCreate()` --calls--> `Show()`  [INFERRED]
  windows\runner\flutter_window.cpp → windows\runner\win32_window.cpp
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows\runner\main.cpp → windows\runner\utils.cpp
- `wWinMain()` --calls--> `SetQuitOnClose()`  [INFERRED]
  windows\runner\main.cpp → windows\runner\win32_window.cpp
- `my_application_dispose()` --calls--> `dispose`  [INFERRED]
  linux\runner\my_application.cc → lib\shared\widgets\phone_input_field.dart

## Communities

### Community 0 - "Community 0"
Cohesion: 0.01
Nodes (193): expectLater, isBusiness, isPro, main, _MockBillingService, buildInvoice, Invoice, main (+185 more)

### Community 1 - "Community 1"
Cohesion: 0.01
Nodes (153): app_colors.dart, app_empty_state.dart, app_failure_state.dart, ../../../auth/domain/entities/auth_session.dart, ../../../auth/presentation/controllers/auth_controller.dart, AppFeedbackService, showSnackBar, AppColors (+145 more)

### Community 2 - "Community 2"
Cohesion: 0.02
Nodes (123): AppException, ClientRepositoryImpl, ClientsController, _validatedClient, ValidationException, buildSmartReminderText, DashboardLocalDatasource, ExpenseRepositoryImpl (+115 more)

### Community 3 - "Community 3"
Cohesion: 0.02
Nodes (122): build, ClientTile, Icon, Padding, SizedBox, build, Container, DashboardSummaryCard (+114 more)

### Community 4 - "Community 4"
Cohesion: 0.02
Nodes (90): app.dart, HiveStorage, registerAdapters, AppFormatters, currency, formatCurrencyGroups, formatPerCurrencyTotals, Function (+82 more)

### Community 5 - "Community 5"
Cohesion: 0.02
Nodes (88): CashFlowService, MonthlyCashFlow, _removeFileOnly, UserProfileImageService, border, _BrandAssetField, build, Column (+80 more)

### Community 6 - "Community 6"
Cohesion: 0.03
Nodes (70): WorkspaceMembersNotifier, WorkspaceOwnerStorage, add, addChange, _amountFeedbackKey, _amountKey, _AmountSuggestion, _amountWithinTolerance (+62 more)

### Community 7 - "Community 7"
Cohesion: 0.03
Nodes (75): AlertDialog, _applyClientSuggestion, _applySelectedClient, _applySmartValues, border, _BottomSheetHeader, build, _buildAddClientView (+67 more)

### Community 8 - "Community 8"
Cohesion: 0.03
Nodes (71): build, Consumer, InvoiceReminderApp, Stack, _ActionRow, AppScaffold, border, build (+63 more)

### Community 9 - "Community 9"
Cohesion: 0.03
Nodes (66): copyWith, InvoiceModel, InvoiceModelAdapter, InvoiceStatusAdapter, read, RecurringIntervalAdapter, _statusFromJson, write (+58 more)

### Community 10 - "Community 10"
Cohesion: 0.03
Nodes (66): AddClientRoute, addSection, addSuggestion, AnimatedBuilder, AnimatedScale, AnimatedSwitcher, build, _buildAnimatedDashboardSection (+58 more)

### Community 11 - "Community 11"
Cohesion: 0.03
Nodes (57): IdGenerator, nextId, CacheException, ClientsLocalDatasource, _ensureUniqueClient, _normalizeEmail, _normalizePhone, ValidationException (+49 more)

### Community 12 - "Community 12"
Cohesion: 0.03
Nodes (52): ./analytics_service.dart, EmailInvoiceService, _logEmailSent, getFinalMessage, getFirmMessage, getFriendlyMessage, WhatsAppReminderService, ClientModel (+44 more)

### Community 13 - "Community 13"
Cohesion: 0.04
Nodes (50): ../adaptive/adaptive_system_controller.dart, canAddClient, canCreateInvoice, FreeTierLimitService, getNextInvoiceNumber, InvoiceNumberingService, OneTapInvoiceService, calculatePendingPayments (+42 more)

### Community 14 - "Community 14"
Cohesion: 0.04
Nodes (48): AuthLocalDatasource, AuthSessionModel, Exception, _sessionFromUser, AddClientScreen, _AddClientScreenState, build, _buildBorder (+40 more)

### Community 15 - "Community 15"
Cohesion: 0.04
Nodes (42): add, _amountFeedbackKey, _buildClientSuggestion, buildDraftForClient, buildPrimaryActionDecision, buildQuickCreateDraft, _clamp01, _ClientAccumulator (+34 more)

### Community 16 - "Community 16"
Cohesion: 0.05
Nodes (38): AndroidBillingService, StateError, AndroidBillingService, BillingCatalogResult, IOSBillingService, UnsupportedError, IOSBillingService, BillingServiceInterface (+30 more)

### Community 17 - "Community 17"
Cohesion: 0.06
Nodes (26): AddClientUseCase, DeleteClientUseCase, GetClientsUseCase, UpdateClientUseCase, DashboardSummaryModel, DashboardRepositoryImpl, DashboardSummaryModel, DashboardController (+18 more)

### Community 18 - "Community 18"
Cohesion: 0.06
Nodes (34): AppShellScaffold, ClientDetailScreen, EditInvoiceScreen, EmailSentScreen, GoRouter, InvoiceDetailScreen, ReminderFlowScreen, ResetPasswordScreen (+26 more)

### Community 19 - "Community 19"
Cohesion: 0.06
Nodes (33): AnimatedBuilder, build, _buildDots, _buildFixedCta, _buildPage, _CardData, ClipRRect, Column (+25 more)

### Community 20 - "Community 20"
Cohesion: 0.06
Nodes (26): border, build, _CountryCodeOption, _decoration, didUpdateWidget, dispose, _fullPhone, Function (+18 more)

### Community 21 - "Community 21"
Cohesion: 0.09
Nodes (25): FlutterWindow(), OnCreate(), RegisterPlugins(), wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16(), Create() (+17 more)

### Community 22 - "Community 22"
Cohesion: 0.07
Nodes (25): AddClientRoute, AddExpenseRoute, AppRouteSpec, ClientDetailRoute, ClientsTabRoute, CreateInvoiceRoute, DashboardTabRoute, EditInvoiceRoute (+17 more)

### Community 23 - "Community 23"
Cohesion: 0.09
Nodes (19): AuthSessionModel, AuthRepositoryImpl, FirebaseAuthService, AuthController, AuthViewState, build, _clearWorkspaceOwner, copyWith (+11 more)

### Community 24 - "Community 24"
Cohesion: 0.1
Nodes (18): OnboardingPageModel, OnboardingRepositoryImpl, build, copyWith, nextPage, OnboardingController, OnboardingState, setPage (+10 more)

### Community 25 - "Community 25"
Cohesion: 0.11
Nodes (15): Payment, PaymentModel, PaymentModelAdapter, read, toEntity, write, calculateNextDate, copyWith (+7 more)

### Community 26 - "Community 26"
Cohesion: 0.22
Nodes (7): GetAppPreferencesUseCase, GetProfileUseCase, SaveAppPreferencesUseCase, SaveProfileUseCase, ../entities/app_preferences.dart, ../entities/profile.dart, ../repositories/settings_repository.dart

### Community 27 - "Community 27"
Cohesion: 0.22
Nodes (3): AppDelegate, FlutterAppDelegate, FlutterImplicitEngineDelegate

### Community 28 - "Community 28"
Cohesion: 0.25
Nodes (5): LoginUseCase, LogoutUseCase, SignUpUseCase, ../entities/auth_session.dart, ../repositories/auth_repository.dart

### Community 29 - "Community 29"
Cohesion: 0.25
Nodes (5): AddExpenseUseCase, DeleteExpenseUseCase, GetExpensesUseCase, ../entities/expense.dart, ../repositories/expense_repository.dart

### Community 30 - "Community 30"
Cohesion: 0.29
Nodes (5): buildPreviewMessage, SendReminderUseCase, ../entities/reminder.dart, ../entities/reminder_message_type.dart, ../repositories/reminder_repository.dart

### Community 31 - "Community 31"
Cohesion: 0.33
Nodes (5): Client, copyWith, hasValidInternationalPhone, isValidEmail, normalizePhone

### Community 32 - "Community 32"
Cohesion: 0.33
Nodes (5): SubscriptionGateDecision, SubscriptionGateException, SubscriptionState, SubscriptionUsage, toString

### Community 33 - "Community 33"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 34 - "Community 34"
Cohesion: 0.4
Nodes (2): RunnerTests, XCTestCase

### Community 35 - "Community 35"
Cohesion: 0.4
Nodes (4): AppException, CacheException, toString, ValidationException

### Community 36 - "Community 36"
Cohesion: 0.4
Nodes (4): Failure, NetworkFailure, UnknownFailure, ValidationFailure

### Community 37 - "Community 37"
Cohesion: 0.4
Nodes (3): GetDashboardSummaryUseCase, ../entities/dashboard_summary.dart, ../repositories/dashboard_repository.dart

### Community 38 - "Community 38"
Cohesion: 0.4
Nodes (4): copyWith, hasValidInternationalPhone, isValidEmail, UserProfile

### Community 39 - "Community 39"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 40 - "Community 40"
Cohesion: 0.5
Nodes (3): MemberNotFoundException, toString, WorkspaceLimitException

### Community 41 - "Community 41"
Cohesion: 0.5
Nodes (3): copyWith, Expense, expense_category.dart

### Community 42 - "Community 42"
Cohesion: 0.67
Nodes (1): MainActivity

### Community 43 - "Community 43"
Cohesion: 0.67
Nodes (2): FlutterSceneDelegate, SceneDelegate

### Community 44 - "Community 44"
Cohesion: 0.67
Nodes (2): copyWith, LineItem

### Community 45 - "Community 45"
Cohesion: 0.67
Nodes (2): InvoiceTemplateRepository, ../entities/invoice_template.dart

### Community 46 - "Community 46"
Cohesion: 0.67
Nodes (2): ../../../auth/domain/repositories/auth_repository.dart, CompleteOnboardingUseCase

### Community 47 - "Community 47"
Cohesion: 0.67
Nodes (2): AppPreferences, copyWith

### Community 48 - "Community 48"
Cohesion: 1.0
Nodes (1): AppConstants

### Community 49 - "Community 49"
Cohesion: 1.0
Nodes (1): AlwaysOnlineNetworkInfo

### Community 50 - "Community 50"
Cohesion: 1.0
Nodes (1): Payment

### Community 51 - "Community 51"
Cohesion: 1.0
Nodes (1): AuthSession

### Community 52 - "Community 52"
Cohesion: 1.0
Nodes (1): DashboardSummary

### Community 53 - "Community 53"
Cohesion: 1.0
Nodes (1): ../entities/onboarding_page.dart

### Community 54 - "Community 54"
Cohesion: 1.0
Nodes (1): Reminder

## Knowledge Gaps
- **1469 isolated node(s):** `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `InvoiceReminderApp`, `build`, `Consumer` (+1464 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 34`** (5 nodes): `RunnerTests.swift`, `RunnerTests.swift`, `RunnerTests`, `.testExample()`, `XCTestCase`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 39`** (4 nodes): `handle_new_rx_page()`, `__lldb_init_module()`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_lldb_helper.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 42`** (3 nodes): `MainActivity.kt`, `MainActivity`, `.configureFlutterEngine()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 43`** (3 nodes): `FlutterSceneDelegate`, `SceneDelegate.swift`, `SceneDelegate`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 44`** (3 nodes): `copyWith`, `LineItem`, `line_item.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 45`** (3 nodes): `InvoiceTemplateRepository`, `../entities/invoice_template.dart`, `invoice_template_repository.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 46`** (3 nodes): `../../../auth/domain/repositories/auth_repository.dart`, `CompleteOnboardingUseCase`, `complete_onboarding_usecase.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 47`** (3 nodes): `AppPreferences`, `copyWith`, `app_preferences.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 48`** (2 nodes): `AppConstants`, `app_constants.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 49`** (2 nodes): `AlwaysOnlineNetworkInfo`, `network_info.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 50`** (2 nodes): `Payment`, `payment.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 51`** (2 nodes): `AuthSession`, `auth_session.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 52`** (2 nodes): `DashboardSummary`, `dashboard_summary.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 53`** (2 nodes): `../entities/onboarding_page.dart`, `onboarding_repository.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 54`** (2 nodes): `Reminder`, `reminder.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter_riverpod/flutter_riverpod.dart` connect `Community 6` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 15`, `Community 16`, `Community 17`, `Community 18`, `Community 19`, `Community 23`, `Community 24`?**
  _High betweenness centrality (0.416) - this node is a cross-community bridge._
- **Why does `package:flutter/material.dart` connect `Community 1` to `Community 0`, `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 7`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 13`, `Community 14`, `Community 19`, `Community 20`, `Community 24`?**
  _High betweenness centrality (0.171) - this node is a cross-community bridge._
- **Why does `package:flutter/foundation.dart` connect `Community 4` to `Community 2`, `Community 5`, `Community 6`, `Community 11`, `Community 12`, `Community 13`, `Community 14`, `Community 16`, `Community 18`, `Community 23`?**
  _High betweenness centrality (0.089) - this node is a cross-community bridge._
- **What connects `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `InvoiceReminderApp` to the rest of the system?**
  _1469 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.01 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.01 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._