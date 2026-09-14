import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/model_json.dart';
import 'package:garage_manager/models/customer.dart';
import 'package:garage_manager/models/maintenance_item.dart';
import 'package:garage_manager/models/staff.dart';
import 'package:garage_manager/models/vehicle.dart';

void main() {
  group('MaintenanceItem codec', () {
    test('round-trips with integral floats from Go', () {
      const wire = {
        'id': 'it-1',
        'name': 'Engine Oil',
        'category': 'fluids',
        'unitPrice': 450,
        'quantity': 2,
        'unit': 'Ltr',
        'discountPercent': 0,
        'taxPercent': 18,
        'isLabour': false,
        'partNumber': null,
        'notes': null,
        'assignedStaffId': null,
      };
      final item = maintenanceItemFromJson(wire);
      expect(item.unitPrice, 450.0);
      expect(item.quantity, 2.0);
      expect(item.taxPercent, 18.0);
      expect(item.category, ItemCategory.fluids);
      final back = maintenanceItemToJson(item);
      expect(back['unitPrice'], 450.0);
      expect(back['category'], 'fluids');
    });

    test('round-trips assigned staff and part number', () {
      final item = MaintenanceItem(
        id: 'it-2',
        name: 'Brake Pads',
        category: ItemCategory.sparePart,
        unitPrice: 1200,
        partNumber: 'BP-99',
        assignedStaffId: 'st-1',
      );
      final back = maintenanceItemToJson(item);
      final reparsed = maintenanceItemFromJson(back);
      expect(reparsed.partNumber, 'BP-99');
      expect(reparsed.assignedStaffId, 'st-1');
      expect(reparsed.isLabour, isFalse);
    });
  });

  group('Customer codec', () {
    test('round-trips with nullable fields null on the wire', () {
      const wire = {
        'id': 'c-1',
        'name': 'Ravi Kumar',
        'phone': '9876543210',
        'whatsappNumber': null,
        'email': null,
        'address': null,
        'gstin': null,
        'notes': null,
        'createdAt': '2026-09-13T04:30:00Z',
      };
      final c = customerFromJson(wire);
      expect(c.whatsappNumber, isNull);
      expect(c.createdAt.isUtc, isFalse);
      expect(c.createdAt.isAtSameMomentAs(DateTime.parse('2026-09-13T04:30:00Z')), isTrue);
      final back = customerToJson(c);
      expect(back['name'], 'Ravi Kumar');
      expect(back['phone'], '9876543210');
      expect(back['createdAt'], isA<String>());
    });

    test('keeps populated optional fields', () {
      final c = Customer(
        id: 'c-2',
        name: 'Ada',
        phone: '1',
        email: 'a@b.c',
        gstin: 'GST123',
      );
      final reparsed = customerFromJson(customerToJson(c));
      expect(reparsed.email, 'a@b.c');
      expect(reparsed.gstin, 'GST123');
      expect(reparsed.effectiveWhatsApp, '1');
    });
  });

  group('Vehicle codec', () {
    test('parses day-grained lastServiceDate and nullable year', () {
      const wire = {
        'id': 'v-1',
        'customerId': 'c-1',
        'registrationNumber': 'MH 12 AB 1234',
        'make': 'Maruti Suzuki',
        'model': 'Swift',
        'variant': null,
        'year': 2021,
        'fuelType': 'diesel',
        'currentKm': 45000,
        'color': null,
        'chassisNumber': null,
        'engineNumber': null,
        'createdAt': '2026-09-13T04:30:00Z',
        'lastServiceDate': '2026-09-01',
      };
      final v = vehicleFromJson(wire);
      expect(v.fuelType, FuelType.diesel);
      expect(v.year, 2021);
      expect(v.lastServiceDate, DateTime(2026, 9, 1));
      final back = vehicleToJson(v);
      expect(back['lastServiceDate'], '2026-09-01');
      expect(back['fuelType'], 'diesel');
    });

    test('round-trips nulls for year and lastServiceDate', () {
      final v = Vehicle(
        id: 'v-2',
        customerId: 'c-1',
        registrationNumber: 'AP 9 X 1',
        make: 'Hyundai',
        model: 'Creta',
        currentKm: 100,
      );
      final back = vehicleToJson(v);
      expect(back['year'], isNull);
      expect(back['lastServiceDate'], isNull);
      final reparsed = vehicleFromJson(back);
      expect(reparsed.year, isNull);
      expect(reparsed.lastServiceDate, isNull);
      expect(reparsed.fuelType, FuelType.petrol);
    });
  });

  group('Staff codec', () {
    test('round-trips with day-grained joiningDate and role enum', () {
      final s = Staff(
        id: 'st-1',
        name: 'Bala',
        role: StaffRole.headMechanic,
        phone: '999',
        monthlySalary: 22000,
        joiningDate: DateTime(2026, 8, 15),
      );
      final back = staffToJson(s);
      expect(back['role'], 'headMechanic');
      expect(back['joiningDate'], '2026-08-15');
      expect(back['monthlySalary'], 22000.0);
      final reparsed = staffFromJson(back);
      expect(reparsed.role, StaffRole.headMechanic);
      expect(reparsed.joiningDate, DateTime(2026, 8, 15));
      expect(reparsed.isActive, isTrue);
    });
  });

  group('Attendance + advance codecs', () {
    test('attendance round-trips status and day date', () {
      final r = AttendanceRecord(
        id: 'a-1',
        staffId: 'st-1',
        date: DateTime(2026, 9, 12),
        status: AttendanceStatus.halfDay,
        notes: 'left early',
      );
      final back = attendanceToJson(r);
      expect(back['status'], 'halfDay');
      expect(back['date'], '2026-09-12');
      final reparsed = attendanceFromJson(back);
      expect(reparsed.status, AttendanceStatus.halfDay);
      expect(reparsed.date, DateTime(2026, 9, 12));
    });

    test('advance round-trips amount and deducted flag', () {
      final a = SalaryAdvance(
        id: 'adv-1',
        staffId: 'st-1',
        amount: 1500,
        date: DateTime(2026, 9, 3),
        reason: 'family',
      );
      final back = salaryAdvanceToJson(a);
      expect(back['amount'], 1500.0);
      expect(back['isDeducted'], isFalse);
      final reparsed = salaryAdvanceFromJson(back);
      expect(reparsed.amount, 1500.0);
      expect(reparsed.isDeducted, isFalse);
    });
  });
}
