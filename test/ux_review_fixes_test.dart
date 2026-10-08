import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/models/maintenance_item.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/utils/grouped_number.dart';

void main() {
  group('digit grouping', () {
    test('Indian grouping', () {
      expect(groupDigits(0), '0');
      expect(groupDigits(999), '999');
      expect(groupDigits(45000), '45,000');
      expect(groupDigits(123456), '1,23,456');
      expect(groupDigits(12345678), '1,23,45,678');
    });

    test('parse ignores commas', () {
      expect(parseGroupedInt('1,23,456'), 123456);
      expect(parseGroupedInt(' 45,000 '), 45000);
      expect(parseGroupedInt('1.5'), isNull);
    });

    test('formatter groups digits and leaves invalid input alone', () {
      const f = GroupedDigitsInputFormatter();
      TextEditingValue type(String text) => f.formatEditUpdate(
            TextEditingValue.empty,
            TextEditingValue(
                text: text, selection: TextSelection.collapsed(offset: text.length)),
          );
      expect(type('45000').text, '45,000');
      expect(type('45000').selection.end, 6);
      expect(type('-1').text, '-1');
      expect(type('1.5').text, '1.5');
    });
  });

  group('default promised delivery', () {
    DateTime at(int day, int hour, [int minute = 0]) =>
        DateTime(2026, 10, day, hour, minute);

    test('rounds up to the next whole hour', () {
      expect(GarageProvider.promisedDeliveryFrom(at(8, 9, 20), 6), at(8, 16));
    });

    test('evening jobs roll to 10 AM next day instead of the small hours', () {
      expect(GarageProvider.promisedDeliveryFrom(at(7, 21, 15), 6), at(8, 10));
      expect(GarageProvider.promisedDeliveryFrom(at(8, 16), 6), at(9, 10));
    });

    test('early-morning results move to opening time', () {
      expect(GarageProvider.promisedDeliveryFrom(at(8, 1), 6), at(8, 10));
    });

    test('19:00 exactly is still within hours', () {
      expect(GarageProvider.promisedDeliveryFrom(at(8, 13), 6), at(8, 19));
    });
  });

  test('discount label', () {
    MaintenanceItem item(double d) => MaintenanceItem(
        id: 'i', name: 'x', category: ItemCategory.sparePart, unitPrice: 100,
        discountPercent: d);
    expect(item(0).discountLabel, isNull);
    expect(item(10.000000001).discountLabel, '10% off');
    expect(item(12.5).discountLabel, '12.5% off');
  });
}
