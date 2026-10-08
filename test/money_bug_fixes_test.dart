import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/models/customer.dart';
import 'package:garage_manager/models/invoice.dart';
import 'package:garage_manager/models/maintenance_item.dart';
import 'package:garage_manager/models/quotation.dart';
import 'package:garage_manager/models/staff.dart';
import 'package:garage_manager/models/vehicle.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/utils/gst_lines.dart';

MaintenanceItem _item(String name, double price, double rate) => MaintenanceItem(
      id: name,
      name: name,
      category: ItemCategory.sparePart,
      unitPrice: price,
      taxPercent: rate,
    );

void main() {
  // Brake pads 1800 @18% + tyre 4400 @28%: the case the emulator test caught.
  final items = [_item('Brake pads', 1800, 18), _item('Tyre', 4400, 28)];

  group('per-item GST', () {
    test('invoice taxes each line at its own rate', () {
      final inv = Invoice(
        id: 'i', invoiceNumber: 'INV', customerId: 'c', vehicleId: 'v',
        kmReading: 0, items: items, perItemTax: true,
      );
      expect(inv.taxBreakdown.keys, [18.0, 28.0]);
      expect(inv.taxBreakdown[18.0], closeTo(324, 1e-9));
      expect(inv.taxBreakdown[28.0], closeTo(1232, 1e-9));
      expect(inv.grandTotal, closeTo(7756, 1e-9));
      expect(inv.cgstAmount + inv.sgstAmount, closeTo(1556, 1e-9));
    });

    test('document discount is spread pro-rata before tax', () {
      final inv = Invoice(
        id: 'i', invoiceNumber: 'INV', customerId: 'c', vehicleId: 'v',
        kmReading: 0, items: items, discountAmount: 620, perItemTax: true,
      );
      // Taxable 5580 (90% of gross), so each rate's tax is 90% too. Must match
      // the backend's InvoiceMoney.Grand for the same inputs (6980.4).
      expect(inv.totalTaxAmount, closeTo(1400.4, 1e-9));
      expect(inv.grandTotal, closeTo(6980.4, 1e-9));
    });

    test('estimate, job card lines and invoice agree', () {
      final quote = Quotation(
        id: 'q', quotationNumber: 'EST', customerId: 'c', vehicleId: 'v',
        kmReading: 0, items: items, perItemTax: true,
      );
      final jobCardTotal = items.fold(0.0, (sum, i) => sum + i.totalAmount);
      expect(quote.grandTotal, closeTo(jobCardTotal, 1e-9));
    });

    test('legacy documents keep the single document rate', () {
      final inv = Invoice(
        id: 'i', invoiceNumber: 'INV', customerId: 'c', vehicleId: 'v',
        kmReading: 0, items: items, taxPercent: 18,
      );
      expect(inv.perItemTax, isFalse);
      expect(inv.grandTotal, closeTo(6200 * 1.18, 1e-9));
    });

    test('estimate discount carries into job card lines', () {
      final quote = Quotation(
        id: 'q', quotationNumber: 'EST', customerId: 'c', vehicleId: 'v',
        kmReading: 0, items: items, overallDiscount: 620, perItemTax: true,
      );
      final jobItems =
          GarageProvider.itemsWithDocumentDiscount(quote.items, quote.overallDiscount);
      final jobCardTotal = jobItems.fold(0.0, (sum, i) => sum + i.totalAmount);
      expect(quote.grandTotal, closeTo(6980.4, 1e-6));
      expect(jobCardTotal, closeTo(quote.grandTotal, 1e-6));
      // An invoice built from the job card (no document discount) agrees too.
      final inv = Invoice(
        id: 'i', invoiceNumber: 'INV', customerId: 'c', vehicleId: 'v',
        kmReading: 0, items: jobItems, perItemTax: true,
      );
      expect(inv.grandTotal, closeTo(6980.4, 1e-6));
    });

    test('gstLines splits each rate into CGST and SGST', () {
      expect(
        gstLines({18.0: 324.0, 28.0: 1232.0})
            .map((e) => '${e.key}=${e.value}')
            .toList(),
        ['CGST (9%)=162.0', 'SGST (9%)=162.0', 'CGST (14%)=616.0', 'SGST (14%)=616.0'],
      );
    });
  });

  group('provider guards', () {
    late GarageProvider provider;

    setUp(() async {
      provider = GarageProvider(MockGarageRepository());
      await provider.load();
    });

    test('salary for a month can only be disbursed once', () async {
      final staff = await provider.addStaff(Staff(
        id: 'pay-staff',
        name: 'Suresh Patil',
        role: StaffRole.values.first,
        phone: '9123456780',
        monthlySalary: 18000,
      ));
      final before = provider.expenses.length;
      await provider.disburseSalary(
          staffId: staff.id, month: 10, year: 2026, netPayable: 16000);
      expect(provider.isSalaryDisbursed(staff.id, 10, 2026), isTrue);
      expect(provider.isSalaryDisbursed(staff.id, 11, 2026), isFalse);

      await expectLater(
        provider.disburseSalary(
            staffId: staff.id, month: 10, year: 2026, netPayable: 16000),
        throwsA(isA<Exception>()),
      );
      expect(provider.expenses.length, before + 1);
    });

    test('duplicate registration numbers are rejected', () async {
      await provider.addCustomer(Customer(id: 'dup-c', name: 'Ravi', phone: '9876543210'));
      Vehicle vehicle(String id, String plate) => Vehicle(
            id: id, customerId: 'dup-c', registrationNumber: plate,
            make: 'Maruti', model: 'Swift', fuelType: FuelType.petrol, currentKm: 1,
          );
      final first = await provider.addVehicle(vehicle('dup-1', 'MH 12 ZZ 4321'));

      expect(() => provider.addVehicle(vehicle('dup-2', 'mh12-zz-4321')),
          throwsA(isA<Exception>()));
      // Editing a vehicle without changing its plate is fine.
      await provider.updateVehicle(first);
      expect(provider.vehicleWithRegistration('MH12ZZ4321')?.id, 'dup-1');
      expect(provider.vehicleWithRegistration('MH12ZZ4321', excludeId: 'dup-1'), isNull);
    });
  });
}
