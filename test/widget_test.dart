import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/main.dart';

void main() {
  testWidgets('NT Garage App loads the home screen', (WidgetTester tester) async {
    // Repository seam: boot the mock shell directly so the test never touches
    // ApiClient, AuthProvider.init or secure storage (no network).
    await tester.pumpWidget(NTGarageApp(repository: MockGarageRepository()));
    await tester.pumpAndSettle();

    expect(find.text('NT Garage & Body Shop'), findsWidgets);

    // Home leads with search and the two ways to start work.
    expect(find.text('Search plate, phone or name'), findsOneWidget);
    expect(find.text('New job card'), findsOneWidget);
    expect(find.text('Quick bill'), findsOneWidget);
    expect(find.text('Collected today'), findsOneWidget);
    expect(find.textContaining('In the workshop'), findsOneWidget);

    // Template sections stay deleted.
    expect(find.text('Workshop Modules'), findsNothing);
    expect(find.text('Book a Service'), findsNothing);

    // Searching a plate lists the vehicle.
    await tester.enterText(find.byType(TextField).first, 'MH 02');
    await tester.pumpAndSettle();
    expect(find.text('MH 02 CZ 4421'), findsOneWidget);
    expect(find.text('New job card'), findsNothing);
  });
}
