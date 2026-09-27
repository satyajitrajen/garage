import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/screens/invoices/invoice_preview_screen.dart';
import 'package:garage_manager/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Invoice reads as a tax invoice with a pay-by-UPI QR', (tester) async {
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

    expect(find.text('Tax invoice'), findsOneWidget);
    expect(find.text('Billed to'), findsOneWidget);
    // Unpaid bill + a configured UPI ID: the QR asks for the exact balance.
    expect(invoice.balanceDue, greaterThan(0));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('Scan to pay'), findsOneWidget);
    expect(find.textContaining(invoice.invoiceNumber), findsWidgets);
  });
}
