import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/api_exception.dart';
import 'package:garage_manager/data/garage_repository.dart';
import 'package:garage_manager/models/staff.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/screens/staff/add_staff_screen.dart';
import 'package:garage_manager/theme/app_theme.dart';
import 'package:provider/provider.dart';

class _StaffRepository implements GarageRepository {
  final created = <Staff>[];
  final updated = <Staff>[];
  Future<Staff> Function(Staff)? save;

  @override
  Future<Staff> createStaff(Staff staff) async {
    created.add(staff);
    return save == null ? staff : await save!(staff);
  }

  @override
  Future<Staff> updateStaff(Staff staff) async {
    updated.add(staff);
    return save == null ? staff : await save!(staff);
  }

  List<Staff> get requests => [...created, ...updated];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected repository call: ${invocation.memberName}');
}

Staff _existingStaff() => Staff(
  id: 'staff-123',
  name: 'Ramesh Sharma',
  role: StaffRole.autoElectrician,
  phone: '9876543210',
  email: 'ramesh@example.com',
  monthlySalary: 24000.75,
  joiningDate: DateTime(2020, 3, 4),
  isActive: false,
  address: '12 Workshop Road',
  emergencyContact: '9123456780',
);

Finder _field(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(TextFormField),
).first;

Future<void> _openForm(
  WidgetTester tester,
  _StaffRepository repository, {
  Staff? staff,
}) async {
  // Give the form room without changing production layout or testing devices.
  tester.view.physicalSize = const Size(800, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = GarageProvider(repository);
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<GarageProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => AddStaffScreen(staffToEdit: staff),
                ),
              ),
              child: const Text('Open staff form'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open staff form'));
  await tester.pumpAndSettle();
  if (staff == null) {
    await tester.enterText(_field('Staff Full Name *'), 'Ramesh Sharma');
    await tester.enterText(_field('Phone Number *'), '9876543210');
    await tester.enterText(_field('Monthly Base Salary (₹) *'), '24000.75');
  }
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(ElevatedButton));
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
}

void main() {
  for (final editing in [false, true]) {
    final mode = editing ? 'edit' : 'create';

    testWidgets('$mode prevents duplicate saves while request is pending', (
      tester,
    ) async {
      final pending = Completer<Staff>();
      final repository = _StaffRepository()..save = (_) => pending.future;
      await _openForm(tester, repository, staff: editing ? _existingStaff() : null);
      await tester.ensureVisible(find.byType(ElevatedButton));
      // Two taps before rebuilding also exercise the synchronous saving guard.
      await tester.tap(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(repository.requests, hasLength(1));
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
      expect(find.byType(AddStaffScreen), findsOneWidget);

      pending.complete(repository.requests.single);
      await tester.pumpAndSettle();
      expect(find.byType(AddStaffScreen), findsNothing);
      expect(find.text('Open staff form'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final apiError in [true, false]) {
      testWidgets('$mode shows ${apiError ? 'API' : 'generic'} error and allows retry without popping', (
        tester,
      ) async {
        final repository = _StaffRepository();
        repository.save = (_) async {
          if (apiError) {
            throw const ApiException(0, 'network_error', '');
          }
          throw StateError('Internal repository details');
        };
        await _openForm(tester, repository, staff: editing ? _existingStaff() : null);
        await _submit(tester);

        expect(find.byType(AddStaffScreen), findsOneWidget);
        expect(
          find.text(apiError
              ? 'Could not reach the server. Check your connection.'
              : 'Failed to save staff. Please try again.'),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsOneWidget);
        expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
        expect(tester.widget<TextFormField>(_field('Staff Full Name *')).controller!.text, 'Ramesh Sharma');
        expect(repository.requests, hasLength(1));
        expect(tester.takeException(), isNull);

        repository.save = null;
        await _submit(tester);
        expect(repository.requests, hasLength(2));
        expect(find.byType(AddStaffScreen), findsNothing);
        expect(find.text('Open staff form'), findsOneWidget);
      });
    }

    testWidgets('$mode uses the authoritative saved staff in confirmation', (
      tester,
    ) async {
      final repository = _StaffRepository()
        ..save = (staff) async => staff.copyWith(name: 'Server Name');
      await _openForm(tester, repository, staff: editing ? _existingStaff() : null);
      await _submit(tester);

      expect(repository.requests, hasLength(1));
      expect(editing ? repository.updated : repository.created, hasLength(1));
      expect(find.byType(AddStaffScreen), findsNothing);
      expect(
        find.text(editing
            ? 'Staff Server Name updated!'
            : 'Employee Server Name added to team!'),
        findsOneWidget,
      );
    });
  }

  testWidgets('edit clears optional fields while preserving unedited data', (
    tester,
  ) async {
    final staff = _existingStaff();
    final repository = _StaffRepository();
    await _openForm(tester, repository, staff: staff);
    await tester.enterText(_field('Email Address (Optional)'), '   ');
    await tester.enterText(_field('Residential Address'), '');
    await _submit(tester);

    expect(repository.created, isEmpty);
    final saved = repository.updated.single;
    expect(saved.email, isNull);
    expect(saved.address, isNull);
    expect(saved.id, staff.id);
    expect(saved.joiningDate, staff.joiningDate);
    expect(saved.isActive, isFalse);
    expect(saved.emergencyContact, staff.emergencyContact);
    expect(saved.name, staff.name);
    expect(saved.phone, staff.phone);
    expect(saved.role, staff.role);
    expect(saved.monthlySalary, staff.monthlySalary);
  });

  for (final salary in ['', 'abc', '-1', '0', 'NaN', 'Infinity', '-Infinity', '1e309']) {
    testWidgets('rejects invalid salary "$salary" before calling repository', (
      tester,
    ) async {
      final repository = _StaffRepository();
      await _openForm(tester, repository);
      await tester.enterText(_field('Monthly Base Salary (₹) *'), salary);
      await _submit(tester);

      expect(repository.requests, isEmpty);
      expect(find.byType(AddStaffScreen), findsOneWidget);
      expect(find.text(salary.isEmpty ? 'Enter salary' : 'Invalid salary amount'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
