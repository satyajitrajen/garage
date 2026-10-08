import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/api_exception.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/models/customer.dart';
import 'package:garage_manager/models/vehicle.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/screens/customers/add_customer_screen.dart';
import 'package:garage_manager/screens/job_cards/create_job_card_screen.dart';
import 'package:garage_manager/screens/vehicles/add_vehicle_dialog.dart';
import 'package:garage_manager/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ServerIdentityProvider extends GarageProvider {
  ServerIdentityProvider() : super(MockGarageRepository());

  int customerCreates = 0;
  int vehicleCreates = 0;
  bool failVehicle = false;
  Completer<void>? vehiclePending;

  @override
  Future<Customer> addCustomer(Customer customer) {
    customerCreates++;
    return super.addCustomer(customer.copyWith(id: 'server-customer'));
  }

  @override
  Future<Vehicle> addVehicle(Vehicle vehicle) async {
    vehicleCreates++;
    if (vehiclePending != null) await vehiclePending!.future;
    if (failVehicle) {
      throw const ApiException(503, 'unavailable', 'Vehicle save unavailable');
    }
    if (getCustomerById(vehicle.customerId) == null) {
      throw const ApiException(404, 'not_found', 'Customer not found');
    }
    return super.addVehicle(vehicle.copyWith(id: 'server-vehicle'));
  }
}

Finder field(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(TextFormField),
).first;

Future<void> fill(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), value);
}

Future<void> press(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
}

Future<void> openForm(
  WidgetTester tester,
  GarageProvider provider,
  Widget form, {
  bool dialog = false,
  ValueChanged<Object?>? onResult,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await provider.load();
  addTearDown(provider.dispose);
  await tester.pumpWidget(ChangeNotifierProvider<GarageProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          final result = dialog
              ? await showDialog<Object>(context: context, builder: (_) => form)
              : await Navigator.push<Object>(context, MaterialPageRoute(builder: (_) => form));
          onResult?.call(result);
        },
        child: const Text('Open form'),
      ))),
    ),
  ));
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
}

Future<void> fillVehicle(WidgetTester tester, {bool customerForm = false}) async {
  await fill(tester, customerForm ? 'Vehicle Registration Number *' : 'Registration Number *', 'MH12AB1234');
  await fill(tester, 'Make *', 'Toyota');
  await fill(tester, 'Model *', 'Etios');
  await fill(tester, customerForm ? 'KM Reading *' : 'KM *', '42000');
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('new vehicle returns the saved server identity', (tester) async {
    final provider = ServerIdentityProvider();
    Object? result;
    await openForm(tester, provider, const AddVehicleDialog(customerId: 'c_1'),
        dialog: true, onResult: (value) => result = value);
    await fillVehicle(tester);
    await press(tester, 'Save Vehicle');
    await tester.pumpAndSettle();
    expect((result as Vehicle).id, 'server-vehicle');
    expect(provider.getVehicleById((result as Vehicle).id), isNotNull);
  });

  testWidgets('vehicle save blocks duplicate taps and permits retry after failure', (tester) async {
    final provider = ServerIdentityProvider()
      ..vehiclePending = Completer<void>()
      ..failVehicle = true;
    await openForm(tester, provider, const AddVehicleDialog(customerId: 'c_1'), dialog: true);
    await fillVehicle(tester);
    await press(tester, 'Save Vehicle');
    await tester.tap(find.text('Save Vehicle'));
    await tester.pump();
    expect(provider.vehicleCreates, 1);
    provider.vehiclePending!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AddVehicleDialog), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    provider.failVehicle = false;
    await press(tester, 'Save Vehicle');
    await tester.pumpAndSettle();
    expect(provider.vehicleCreates, 2);
    expect(find.byType(AddVehicleDialog), findsNothing);
  });

  for (final invalid in ['abc', '-1', '1.5']) {
    testWidgets('vehicle rejects invalid odometer $invalid', (tester) async {
      final provider = ServerIdentityProvider();
      await openForm(tester, provider, const AddVehicleDialog(customerId: 'c_1'), dialog: true);
      await fillVehicle(tester);
      await fill(tester, 'KM *', invalid);
      await press(tester, 'Save Vehicle');
      expect(provider.vehicleCreates, 0);
      expect(find.byType(AddVehicleDialog), findsOneWidget);
    });
  }

  testWidgets('customer and vehicle flow uses server IDs for the new job', (tester) async {
    final provider = ServerIdentityProvider();
    await openForm(tester, provider, const AddCustomerScreen());
    await fill(tester, 'Customer Full Name *', 'Test Customer');
    await fill(tester, 'Mobile Number *', '9876543210');
    await fillVehicle(tester, customerForm: true);
    await press(tester, 'Save & Start Job Card');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final jobForm = tester.widget<CreateJobCardScreen>(find.byType(CreateJobCardScreen));
    expect(jobForm.customer!.id, 'server-customer');
    expect(jobForm.vehicle!.id, 'server-vehicle');
    expect(jobForm.vehicle!.customerId, 'server-customer');
  });

  testWidgets('vehicle failure retries without creating the customer twice', (tester) async {
    final provider = ServerIdentityProvider()..failVehicle = true;
    await openForm(tester, provider, const AddCustomerScreen());
    await fill(tester, 'Customer Full Name *', 'Test Customer');
    await fill(tester, 'Mobile Number *', '9876543210');
    await fillVehicle(tester, customerForm: true);
    await press(tester, 'Save & Start Job Card');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(provider.customerCreates, 1);
    provider.failVehicle = false;
    await press(tester, 'Save & Start Job Card');
    await tester.pumpAndSettle();
    expect(provider.customerCreates, 1);
    expect(find.byType(CreateJobCardScreen), findsOneWidget);
  });
}
