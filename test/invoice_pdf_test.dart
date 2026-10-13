import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/garage_profile.dart';
import 'package:garage_manager/models/invoice.dart';
import 'package:garage_manager/models/maintenance_item.dart';
import 'package:garage_manager/utils/invoice_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a PDF bill with mixed GST rates', () async {
    final invoice = Invoice(
      id: 'inv-1',
      invoiceNumber: 'INV-2026-0101',
      customerId: 'c-1',
      vehicleId: 'v-1',
      kmReading: 45200,
      perItemTax: true,
      items: [
        MaintenanceItem(
          id: 'i-1',
          name: 'Brake pads',
          category: ItemCategory.custom,
          unitPrice: 2400,
          taxPercent: 18,
        ),
        MaintenanceItem(
          id: 'i-2',
          name: 'Tyre',
          category: ItemCategory.custom,
          unitPrice: 5200,
          taxPercent: 28,
        ),
      ],
    );
    const profile = GarageProfile(
      name: 'NT Garage',
      tagline: '',
      addressLine: 'Shop 4, MG Road',
      city: 'Pune',
      phone: '98765 43210',
      email: '',
      gstin: '27ABCDE1234F1Z5',
      upiId: 'ntgarage@upi',
    );

    final bytes = await InvoicePdf.build(invoice: invoice, profile: profile);

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
    expect(InvoicePdf.fileName(invoice), 'Bill-INV-2026-0101.pdf');
  });
}
