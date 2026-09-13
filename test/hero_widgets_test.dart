import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/theme/app_theme.dart';
import 'package:garage_manager/widgets/book_service_card.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BookServiceCard renders rows, chips and CTA', (tester) async {
    final provider = GarageProvider(MockGarageRepository());
    await provider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<GarageProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: BookServiceCard()),
        ),
      ),
    );

    expect(find.text('Book a Service'), findsOneWidget);
    expect(find.text('Select customer'), findsOneWidget);
    expect(find.text('Quick Service'), findsOneWidget);
    expect(find.text('New Job Card'), findsOneWidget);
    expect(find.text('Start Quick Service'), findsOneWidget);
  });
}
