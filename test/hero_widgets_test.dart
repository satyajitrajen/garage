import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/screens/invoices/invoice_preview_screen.dart';
import 'package:garage_manager/theme/app_theme.dart';
import 'package:garage_manager/widgets/book_service_card.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

    await tester.tap(find.text('New Job Card'));
    await tester.pump();
    expect(find.text('Create Job Card'), findsOneWidget);
  });

  testWidgets('Invoice preview renders ticket QR and PNR pill', (tester) async {
    final provider = GarageProvider(MockGarageRepository());
    await provider.load();
    final invoice = provider.invoices.first;

    await tester.pumpWidget(
      ChangeNotifierProvider<GarageProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: InvoicePreviewScreen(invoiceId: invoice.id),
        ),
      ),
    );

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Awaiting Payment'), findsOneWidget);
    expect(find.textContaining(invoice.invoiceNumber), findsWidgets);
  });
}
