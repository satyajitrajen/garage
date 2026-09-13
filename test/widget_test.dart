import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/main.dart';
import 'package:garage_manager/widgets/book_service_card.dart';

void main() {
  testWidgets('Nexory Garage App loads dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NexoryGarageApp());
    await tester.pumpAndSettle();

    expect(find.text('Nexory Garage & Body Shop'), findsWidgets);

    // New home structure (spec §5): booking-first stack.
    expect(find.byType(BookServiceCard), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Collection'), findsOneWidget);
    expect(find.text('Expenses'), findsWidgets); // Today card + module tile
    expect(find.textContaining('₹'), findsWidgets);
    expect(find.text('Live Floor'), findsOneWidget);
    // The mock seed has active job cards, so the strip renders — not the
    // empty card.
    expect(find.text('All clear — no vehicles in workshop'), findsNothing);
    expect(find.text('Workshop Modules'), findsOneWidget);

    // Deleted sections stay deleted.
    expect(find.text('Live Bay Activity'), findsNothing);
    expect(find.text('Weekly Revenue vs Expenses'), findsNothing);
  });
}
