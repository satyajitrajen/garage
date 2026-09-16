import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/api/model_json.dart';

const settingsWire = {
  'garage_id': 'g-1',
  'profile': {
    'name': 'NT Garage & Body Shop',
    'tagline': 'Body repair done right',
    'address_line': '12 MG Road',
    'city': 'Pune',
    'phone': '020-1234',
    'email': 'hello@ntgarage.in',
    'gstin': '27AAAAA0000A1Z5',
    'upi_id': 'ntgarage@upi',
  },
  'default_tax_percent': 18,
  'tax_percent_options': [0, 12, 18, 28],
  'invoice_due_days': 7,
  'quotation_validity_options': [7, 15, 30],
  'working_days_per_month': 26,
  'promised_delivery_hours': 6,
  'invoice_notes': 'Thanks!',
  'invoice_terms': 'Warranty 30 days.',
  'default_received_by': 'Cashier',
};

void main() {
  test('profile parses snake_case keys', () {
    final p = profileFromJson(settingsWire['profile'] as Map<String, dynamic>);
    expect(p.name, 'NT Garage & Body Shop');
    expect(p.addressLine, '12 MG Road');
    expect(p.upiId, 'ntgarage@upi');
    expect(p.gstin, '27AAAAA0000A1Z5');
  });

  test('config parses snake_case keys with integral doubles', () {
    final c = appConfigFromSettings(settingsWire);
    expect(c.defaultTaxPercent, 18.0);
    expect(c.taxPercentOptions, [0.0, 12.0, 18.0, 28.0]);
    expect(c.invoiceDueDays, 7);
    expect(c.quotationValidityOptions, [7, 15, 30]);
    expect(c.workingDaysPerMonth, 26);
    expect(c.promisedDeliveryHours, 6);
    expect(c.invoiceNotes, 'Thanks!');
    expect(c.defaultReceivedBy, 'Cashier');
  });
}
