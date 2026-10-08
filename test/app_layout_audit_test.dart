import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:garage_manager/data/api/api_client.dart';
import 'package:garage_manager/data/api/auth_models.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/models/customer.dart';
import 'package:garage_manager/models/invoice.dart';
import 'package:garage_manager/models/job_card.dart';
import 'package:garage_manager/models/quotation.dart';
import 'package:garage_manager/models/vehicle.dart';
import 'package:garage_manager/providers/auth_provider.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/screens/auth/forgot_password_screen.dart';
import 'package:garage_manager/screens/auth/garage_switcher.dart';
import 'package:garage_manager/screens/auth/login_screen.dart';
import 'package:garage_manager/screens/auth/register_screen.dart';
import 'package:garage_manager/screens/auth/reset_password_screen.dart';
import 'package:garage_manager/screens/auth/verify_email_screen.dart';
import 'package:garage_manager/screens/billing/billing_screen.dart';
import 'package:garage_manager/screens/customers/add_customer_screen.dart';
import 'package:garage_manager/screens/customers/customer_detail_screen.dart';
import 'package:garage_manager/screens/customers/customers_list_screen.dart';
import 'package:garage_manager/screens/dashboard/dashboard_screen.dart';
import 'package:garage_manager/screens/expenses/add_expense_screen.dart';
import 'package:garage_manager/screens/expenses/expenses_list_screen.dart';
import 'package:garage_manager/screens/invoices/create_invoice_screen.dart';
import 'package:garage_manager/screens/invoices/invoice_preview_screen.dart';
import 'package:garage_manager/screens/invoices/invoices_list_screen.dart';
import 'package:garage_manager/screens/job_cards/create_job_card_screen.dart';
import 'package:garage_manager/screens/job_cards/job_card_detail_screen.dart';
import 'package:garage_manager/screens/job_cards/job_cards_list_screen.dart';
import 'package:garage_manager/screens/main_navigation_screen.dart';
import 'package:garage_manager/screens/maintenance/add_maintenance_screen.dart';
import 'package:garage_manager/screens/more/more_menu_screen.dart';
import 'package:garage_manager/screens/payments/payment_collection_screen.dart';
import 'package:garage_manager/screens/quotations/create_quotation_screen.dart';
import 'package:garage_manager/screens/quotations/quotation_detail_screen.dart';
import 'package:garage_manager/screens/quotations/quotations_list_screen.dart';
import 'package:garage_manager/screens/staff/add_staff_screen.dart';
import 'package:garage_manager/screens/staff/staff_attendance_screen.dart';
import 'package:garage_manager/screens/staff/staff_list_screen.dart';
import 'package:garage_manager/screens/staff/staff_salary_screen.dart';
import 'package:garage_manager/screens/team/members_screen.dart';
import 'package:garage_manager/screens/vehicles/add_vehicle_dialog.dart';
import 'package:garage_manager/screens/vehicles/vehicle_selection_screen.dart';
import 'package:garage_manager/screens/workflow/quick_service_wizard.dart';
import 'package:garage_manager/theme/app_theme.dart';

// This is deliberately a failing regression audit when the app overflows.
// No FlutterError filtering, expected-error assertions, network, or skipped cases.
// Font fetching is disabled; these are Flutter widget-test font metrics, not
// claims about native-device rendering or pixel-perfect Inter typography.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalFontFetching = GoogleFonts.config.allowRuntimeFetching;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadProportionalFonts();
  });
  tearDownAll(() {
    GoogleFonts.config.allowRuntimeFetching = originalFontFetching;
  });

  const sizes = [Size(320, 640), Size(390, 844)];
  const scales = [1.0, 1.3];

  for (final scenario in _scenarios) {
    for (final size in sizes) {
      for (final scale in scales) {
        for (final keyboard in [false, if (scenario.keyboardField != null) true]) {
          final description = '${scenario.name} | '
              '${size.width.toInt()}x${size.height.toInt()} | '
              'text=$scale | keyboard=${keyboard ? 260 : 0}';
          testWidgets(description, (tester) async {
            final garage = GarageProvider(MockGarageRepository());
            await garage.load();
            expect(garage.loadError, isNull);
            expect(garage.isLoading, isFalse);
            final fixture = _Fixture(garage);
            final unexpectedRequests = <String>[];
            final client = ApiClient(
              baseUrl: 'https://layout-audit.invalid',
              httpClient: MockClient((request) async {
                unexpectedRequests.add('${request.method} ${request.url}');
                throw StateError('No HTTP calls are allowed in the layout audit');
              }),
            );
            final auth = _AuditAuth(garage, client);
            addTearDown(() {
              expect(unexpectedRequests, isEmpty,
                  reason: 'All identity/billing/team data must remain offline');
              client.close();
              auth.dispose();
              garage.dispose();
            });
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetViewInsets);

            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<GarageProvider>.value(value: garage),
                  ChangeNotifierProvider<AuthProvider>.value(value: auth),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                  home: scenario.build(fixture),
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (scenario.open != null) {
              await scenario.open!(tester, fixture);
              await tester.pumpAndSettle();
            }
            if (keyboard) {
              final field = scenario.keyboardField!();
              expect(field, findsOneWidget,
                  reason: 'Keyboard cases must focus a real input');
              await tester.ensureVisible(field);
              await tester.showKeyboard(field);
              tester.view.viewInsets = const FakeViewPadding(bottom: 260);
              await tester.pumpAndSettle();
              expect(tester.testTextInput.isVisible, isTrue);
              // Scaffold consumes the inset for its body (resizeToAvoidBottomInset),
              // so assert on the view-level MediaQuery, not the field's.
              expect(
                  MediaQuery.of(tester.element(find.byType(Scaffold).first))
                      .viewInsets
                      .bottom,
                  260);
            }
            // Render validation messages too, without submitting API requests or
            // mutating fixture records. Layout assertions remain ordinary failures.
            if (scenario.validate) {
              for (final form in tester.stateList<FormState>(find.byType(Form))) {
                form.validate();
              }
              await tester.pumpAndSettle();
            }
            await _sweepVerticalContent(tester);
            if (scenario.exercise != null) {
              await scenario.exercise!(tester, fixture);
              await tester.pumpAndSettle();
              await _sweepVerticalContent(tester);
            }
            expect(tester.takeException(), isNull, reason: description);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          });
        }
      }
    }
  }
}

class _Fixture {
  _Fixture(this.garage);
  final GarageProvider garage;
  Vehicle get vehicle => garage.vehicles.first;
  Customer get customer => garage.getCustomerById(vehicle.customerId)!;
  JobCard get job => garage.jobCards.firstWhere((job) => job.items.isNotEmpty);
  Quotation get quote => garage.quotations.firstWhere((quote) => quote.items.isNotEmpty);
  Invoice get unpaid => garage.invoices.firstWhere((invoice) => invoice.balanceDue > 0);
}

// AuthProvider's constructor only wires collaborators. init()/storage are never
// used. Every operation exercised by these screens is overridden locally.
class _AuditAuth extends AuthProvider {
  _AuditAuth(this.garage, ApiClient client) : super(client: client);
  final GarageProvider garage;

  @override
  bool get isInitializing => false;
  @override
  bool get isBusy => false;
  @override
  bool get isAuthenticated => true;
  @override
  bool get isOwner => true;
  @override
  bool can(String permission) => true;
  @override
  AuthUser get user => AuthUser(
        id: 'audit-owner',
        name: garage.staff.first.name,
        email: 'owner@example.invalid',
      );
  @override
  String get garageId => 'audit-garage';
  @override
  List<Membership> get memberships => [
        Membership(
          garageId: garageId,
          garageName: garage.profile.name,
          role: 'owner',
          permissions: const [],
          isActive: true,
        ),
      ];
  @override
  Membership get currentMembership => memberships.single;
  @override
  Future<Map<String, dynamic>> fetchBilling() async => {
        'status': 'trialing',
        'plan_tier': 'trial',
        'trial_ends_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      };
  @override
  Future<List<Map<String, dynamic>>> fetchMembers() async => [
        for (final staff in garage.staff)
          {
            'name': staff.name,
            'email': staff.email ?? 'staff@example.invalid',
            'role': 'staff',
            'is_active': staff.isActive,
            'permissions': ['staff.manage'],
          },
      ];
  @override
  Future<void> inviteMember({
    required String email,
    String role = 'staff',
    List<String>? permissions,
  }) async {}
  @override
  Future<List<Map<String, dynamic>>> fetchInvites() async => [
        {
          'id': 'inv-1',
          'email': 'new.mechanic@example.invalid',
          'role': 'staff',
          'permissions': ['jobcards.manage'],
          'expires_at':
              DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        },
      ];
  @override
  Future<Map<String, dynamic>> startCheckout({required String plan}) async =>
      {'configured': false, 'message': 'Offline audit checkout', 'plan': plan};
  @override
  Future<void> cancelBilling() async {}
  @override
  Future<void> logout() async {}
  @override
  Future<void> selectGarage(String id) async {}
  @override
  Future<void> forgot({required String email}) async {}
  @override
  Future<void> requestVerify({required String email}) async {}
  @override
  Future<void> verify({required String token}) async {}
  @override
  Future<void> reset({required String token, required String password}) async {}
  @override
  Future<void> login({required String email, required String password}) async {}
  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String garageName,
  }) async {}
}

typedef _Action = Future<void> Function(WidgetTester tester, _Fixture fixture);

class _Scenario {
  const _Scenario(this.name, this.build, {
    this.open,
    this.exercise,
    this.keyboardField,
    this.validate = false,
  });
  final String name;
  final Widget Function(_Fixture) build;
  final _Action? open;
  final _Action? exercise;
  final Finder Function()? keyboardField;
  final bool validate;
}

Finder _input(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
      description: 'TextField labelled "$label"',
    );

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

// Jump in overlapping viewport-sized increments, rather than only checking the
// first frame or the bottom. Lazy list rows get built and painted along the way.
// PageView/TabBar horizontal scrolling is intentionally handled via tab taps.
Future<void> _sweepVerticalContent(WidgetTester tester) async {
  final scrollables = tester.stateList<ScrollableState>(find.byType(Scrollable)).toList();
  for (final state in scrollables) {
    if (!state.mounted || axisDirectionToAxis(state.axisDirection) != Axis.vertical) {
      continue;
    }
    final position = state.position;
    if (!position.hasContentDimensions || position.viewportDimension <= 0) continue;
    position.jumpTo(position.minScrollExtent);
    await tester.pumpAndSettle();
    // Bounded by content, not a fixed count: a keyboard + sheet can leave a
    // viewport only a few dozen pixels tall.
    for (var step = 0; step < 1000; step++) {
      if (!state.mounted || position.pixels >= position.maxScrollExtent) break;
      position.jumpTo((position.pixels + position.viewportDimension * .8)
          .clamp(position.minScrollExtent, position.maxScrollExtent));
      await tester.pumpAndSettle();
    }
    expect(position.pixels, closeTo(position.maxScrollExtent, .1),
        reason: 'The audit must reach the end of scrollable content');
  }
}

Future<void> _tabs(WidgetTester tester, _Fixture fixture) async {
  final count = find.byType(Tab).evaluate().length;
  for (var index = 1; index < count; index++) {
    await _tap(tester, find.byType(Tab).at(index));
    await _sweepVerticalContent(tester);
  }
}

Future<void> _chooseLineItem(WidgetTester tester, _Fixture fixture) async {
  final legacy = find.text('Add Items');
  await _tap(tester,
      legacy.evaluate().isNotEmpty ? legacy : find.widgetWithText(OutlinedButton, 'Add'));
  final name = fixture.garage.catalog.first.name;
  final tile = find.ancestor(of: find.text(name).first, matching: find.byType(InkWell));
  await _tap(tester, tile.first);
  await _tap(tester, find.text('Done (1 item)'));
  expect(find.byType(AddMaintenanceScreen), findsNothing);
}

Widget _dialogHost(Widget Function(BuildContext) dialog) => Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () => showDialog<void>(context: context, builder: dialog),
        child: const Text('Open audit dialog'),
      )),
    );

final _scenarios = <_Scenario>[
  _Scenario('Dashboard', (_) => const DashboardScreen()),
  _Scenario('Main navigation', (_) => const MainNavigationScreen(),
    exercise: (tester, _) async {
      for (final label in ['Jobs', 'Clients', 'Bills', 'More', 'Home']) {
        await _tap(tester, find.text(label));
        await _sweepVerticalContent(tester);
      }
    }),
  _Scenario('More menu', (_) => const MoreMenuScreen()),
  _Scenario('Customers list', (_) => const CustomersListScreen()),
  _Scenario('Customer selection', (_) => const CustomersListScreen(isSelectionMode: true)),
  _Scenario('Customer detail tabs', (f) => CustomerDetailScreen(customer: f.customer), exercise: _tabs),
  _Scenario('Add customer with vehicle', (_) => const AddCustomerScreen(),
    keyboardField: () => _input('Customer Full Name *'), validate: true),
  _Scenario('Add customer separate WhatsApp', (_) => const AddCustomerScreen(),
    open: (tester, _) => _tap(tester, find.byType(CheckboxListTile).first),
    keyboardField: () => _input('WhatsApp Number'), validate: true),
  _Scenario('Edit customer', (f) => AddCustomerScreen(customerToEdit: f.customer),
    keyboardField: () => _input('Customer Full Name *'), validate: true),
  _Scenario('Vehicle selection', (f) => VehicleSelectionScreen(customer: f.customer)),
  _Scenario('Add vehicle dialog', (f) => _dialogHost((_) => AddVehicleDialog(customerId: f.customer.id)),
    open: (tester, _) => _tap(tester, find.text('Open audit dialog')),
    keyboardField: () => _input('Registration Number *'), validate: true),
  _Scenario('Edit vehicle dialog', (f) => _dialogHost((_) => AddVehicleDialog(customerId: f.customer.id, vehicleToEdit: f.vehicle)),
    open: (tester, _) => _tap(tester, find.text('Open audit dialog')),
    keyboardField: () => _input('Registration Number *'), validate: true),
  _Scenario('Job cards list tabs', (_) => const JobCardsListScreen(), exercise: _tabs),
  _Scenario('Job card detail', (f) => JobCardDetailScreen(jobCardId: f.job.id)),
  _Scenario('Create job card', (f) => CreateJobCardScreen(customer: f.customer, vehicle: f.vehicle),
    keyboardField: () => _input('Current KM *'), validate: true),
  _Scenario('Edit job card with items', (f) => CreateJobCardScreen(existing: f.job),
    keyboardField: () => _input('Supervisor Diagnostic Remarks'), validate: true),
  _Scenario('Edit billed job card locked items', (f) => CreateJobCardScreen(existing: f.job, itemsLocked: true),
    keyboardField: () => _input('Supervisor Diagnostic Remarks'), validate: true),
  _Scenario('Quotations list tabs', (_) => const QuotationsListScreen(), exercise: _tabs),
  _Scenario('Quotation detail', (f) => QuotationDetailScreen(quotationId: f.quote.id)),
  _Scenario('Create quotation', (f) => CreateQuotationScreen(customer: f.customer, vehicle: f.vehicle),
    keyboardField: () => _input('Quotation Notes / Terms'), validate: true),
  _Scenario('Edit quotation with items', (f) => CreateQuotationScreen(
      customer: f.garage.getCustomerById(f.quote.customerId)!,
      vehicle: f.garage.getVehicleById(f.quote.vehicleId)!, existing: f.quote),
    keyboardField: () => _input('Quotation Notes / Terms'), validate: true),
  _Scenario('Invoices list tabs', (_) => const InvoicesListScreen(), exercise: _tabs),
  _Scenario('Invoice preview unpaid', (f) => InvoicePreviewScreen(invoiceId: f.unpaid.id)),
  _Scenario('Invoice preview paid', (f) => InvoicePreviewScreen(invoiceId: f.garage.invoices.firstWhere((i) => i.status == InvoiceStatus.paid).id)),
  _Scenario('Create invoice', (f) => CreateInvoiceScreen(customer: f.customer, vehicle: f.vehicle),
    keyboardField: () => _input('Invoice Notes / Customer Remarks'), validate: true),
  _Scenario('Create invoice with selected item', (f) => CreateInvoiceScreen(customer: f.customer, vehicle: f.vehicle),
    open: _chooseLineItem,
    keyboardField: () => _input('Invoice Notes / Customer Remarks'), validate: true),
  _Scenario('Payment collection', (f) => PaymentCollectionScreen(invoice: f.unpaid),
    keyboardField: () => _input('Amount Received (₹) *'), validate: true),
  _Scenario('Partial cash payment', (f) => PaymentCollectionScreen(invoice: f.unpaid),
    open: (tester, _) async {
      await _tap(tester, find.text('Partial Payment'));
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Cash'));
    }, keyboardField: () => _input('Cash Receipt / Handover Note (Optional)'), validate: true),
  _Scenario('Payment receipt dialog', (f) => PaymentCollectionScreen(invoice: f.unpaid),
    open: (tester, f) async {
      await _tap(tester, find.text('Confirm & Record Payment'));
      expect(find.text('Payment Received!'), findsOneWidget);
      expect(f.garage.getInvoiceById(f.unpaid.id), isNotNull);
    }),
  _Scenario('Maintenance catalogue tabs', (_) => const AddMaintenanceScreen(), exercise: _tabs),
  _Scenario('Maintenance selected items', (f) => AddMaintenanceScreen(initialItems: f.job.items), exercise: _tabs),
  _Scenario('Maintenance custom item sheet', (_) => const AddMaintenanceScreen(),
    open: (tester, _) => _tap(tester, find.text('Custom Item')),
    keyboardField: () => _input('Item / Job Description *')),
  _Scenario('Expenses list', (_) => const ExpensesListScreen()),
  _Scenario('Add expense', (_) => const AddExpenseScreen(),
    keyboardField: () => find.byType(TextField).first, validate: true),
  _Scenario('Edit expense', (f) => AddExpenseScreen(existing: f.garage.expenses.first),
    keyboardField: () => find.byType(TextField).first, validate: true),
  _Scenario('Staff list', (_) => const StaffListScreen()),
  _Scenario('Add staff', (_) => const AddStaffScreen(),
    keyboardField: () => find.byType(TextField).first, validate: true),
  _Scenario('Edit staff', (f) => AddStaffScreen(staffToEdit: f.garage.staff.first),
    keyboardField: () => find.byType(TextField).first, validate: true),
  _Scenario('Staff attendance', (f) => StaffAttendanceScreen(staff: f.garage.staff.first)),
  _Scenario('Staff payroll', (f) => StaffSalaryScreen(staff: f.garage.staff.first)),
  _Scenario('Salary advance dialog', (f) => StaffSalaryScreen(staff: f.garage.staff.first),
    open: (tester, _) => _tap(tester, find.byTooltip('Record Advance')),
    keyboardField: () => _input('Advance Amount (₹) *')),
  _Scenario('Payroll staff picker sheet', (_) => const MoreMenuScreen(),
    open: (tester, _) async {
      final tile = find.text('Attendance & payroll');
      await tester.scrollUntilVisible(tile, 200,
          scrollable: find.byType(Scrollable).first);
      await _tap(tester, tile);
    }),
  _Scenario('Quick service customer step', (_) => const QuickServiceWizard()),
  _Scenario('Quick service vehicle step', (f) => QuickServiceWizard(initialCustomer: f.customer)),
  _Scenario('Quick service items step', (f) => QuickServiceWizard(initialCustomer: f.customer, initialVehicle: f.vehicle),
    keyboardField: () => _input('Odometer (KM)')),
  _Scenario('Quick service populated items', (f) => QuickServiceWizard(initialCustomer: f.customer, initialVehicle: f.vehicle),
    open: _chooseLineItem, keyboardField: () => _input('Discount (₹)')),
  _Scenario('Quick service bill step', (f) => QuickServiceWizard(initialCustomer: f.customer, initialVehicle: f.vehicle),
    open: (tester, f) async {
      final count = f.garage.invoices.length;
      await _chooseLineItem(tester, f);
      await _tap(tester, find.text('Generate Bill'));
      expect(f.garage.invoices.length, count + 1);
      expect(find.text('Job Card & Bill Generated!'), findsOneWidget);
    }),
  _Scenario('Login', (_) => const LoginScreen(),
    keyboardField: () => _input('Email'), validate: true),
  _Scenario('Register', (_) => const RegisterScreen(),
    keyboardField: () => _input('Password (min 8 characters)'), validate: true),
  _Scenario('Forgot password', (_) => const ForgotPasswordScreen(),
    keyboardField: () => _input('Email'), validate: true),
  _Scenario('Reset password', (_) => const ResetPasswordScreen(),
    keyboardField: () => _input('New password (min 8)'), validate: true),
  _Scenario('Verify email', (_) => const VerifyEmailScreen(),
    keyboardField: () => _input('Verification token'), validate: true),
  _Scenario('Billing with fake auth', (_) => const BillingScreen()),
  _Scenario('Team with fake auth', (_) => const MembersScreen()),
  _Scenario('Team invite dialog with fake auth', (_) => const MembersScreen(),
    open: (tester, _) => _tap(tester, find.text('Invite')),
    keyboardField: () => _input('Email')),
  _Scenario('Garage switcher sheet with fake auth', (_) => Scaffold(
      body: Builder(builder: (context) => TextButton(
        onPressed: () => GarageSwitcherSheet.show(context),
        child: const Text('Switch garage'),
      ))),
    open: (tester, _) => _tap(tester, find.text('Switch garage'))),
  _Scenario('Home search results', (_) => const DashboardScreen(),
    open: (tester, _) async {
      await tester.enterText(find.byType(TextField).first, 'MH');
      await tester.pumpAndSettle();
    }),
  _Scenario('Home new job card picks a customer', (_) => const DashboardScreen(),
    open: (tester, f) async {
      await _tap(tester, find.text('New job card'));
      expect(find.byType(CustomersListScreen), findsOneWidget);
    }),
];

/// flutter_test renders unknown families with the Ahem font, where every
/// glyph is a full-em square: roughly twice as wide as Inter, so every row
/// "overflows". Register the SDK's bundled Roboto (metrics within a few % of
/// Inter; the 1.3x text-scale cases cover the difference) under the exact
/// family names the app resolves. The tester ignores fontFamilyFallback, so
/// each google_fonts variant name (`Poppins_regular`, `Poppins_700`, ...) is
/// registered individually, plus the Material theme default 'Roboto'.
Future<void> _loadProportionalFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  ByteData? read(String name) {
    final f = File('$dir/$name');
    return f.existsSync() ? ByteData.sublistView(f.readAsBytesSync()) : null;
  }

  String robotoFor(int weight) => switch (weight) {
        <= 300 => 'roboto-light.ttf',
        400 => 'roboto-regular.ttf',
        500 => 'roboto-medium.ttf',
        <= 700 => 'roboto-bold.ttf',
        _ => 'roboto-black.ttf',
      };

  Future<void> register(String family, String file) async {
    final data = read(file) ?? read('roboto-regular.ttf');
    if (data == null) return;
    await (FontLoader(family)..addFont(Future.value(data))).load();
  }

  for (var w = 100; w <= 900; w += 100) {
    await register(w == 400 ? 'Poppins_regular' : 'Poppins_$w', robotoFor(w));
  }
  await register('Poppins', 'roboto-regular.ttf');
  final roboto = FontLoader('Roboto');
  for (final w in [300, 400, 500, 700, 900]) {
    final data = read(robotoFor(w));
    if (data != null) roboto.addFont(Future.value(data));
  }
  await roboto.load();
  final icons = read('materialicons-regular.otf');
  if (icons != null) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
  }
}
