import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/main.dart';

void main() {
  testWidgets('Nexory Garage App loads dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NexoryGarageApp());
    await tester.pumpAndSettle();

    expect(find.text('Nexory Garage'), findsWidgets);
  });
}
