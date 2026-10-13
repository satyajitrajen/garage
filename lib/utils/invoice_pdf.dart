import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/garage_profile.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/vehicle.dart';
import 'currency_formatter.dart';
import 'date_formatter.dart';
import 'grouped_number.dart';
import 'gst_lines.dart';
import 'quantity_formatter.dart';

/// Builds an A4 PDF of a bill, laid out like the on-screen preview.
///
/// Uses the bundled Poppins font: the PDF base fonts have no ₹ glyph.
class InvoicePdf {
  InvoicePdf._();

  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _loadFonts() async {
    _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
  }

  /// File name for the shared PDF, e.g. `Bill-INV-2026-0101.pdf`.
  static String fileName(Invoice invoice) => 'Bill-${invoice.invoiceNumber}.pdf';

  static Future<Uint8List> build({
    required Invoice invoice,
    required GarageProfile profile,
    Customer? customer,
    Vehicle? vehicle,
  }) async {
    await _loadFonts();
    final money = CurrencyFormatter.format;
    const ink = PdfColor.fromInt(0xFF171717);
    const muted = PdfColor.fromInt(0xFF656565);
    const line = PdfColor.fromInt(0xFFE8E8E8);
    final hasGstin = profile.gstin.trim().isNotEmpty;

    pw.TextStyle t(double size, {bool bold = false, PdfColor color = ink}) =>
        pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : null, color: color);

    pw.Widget sumRow(String label, String value, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: t(bold ? 11 : 9.5, bold: bold, color: bold ? ink : muted)),
              pw.Text(value, style: t(bold ? 11 : 9.5, bold: bold)),
            ],
          ),
        );

    final doc = pw.Document(
      title: '${hasGstin ? 'Tax Invoice' : 'Bill'} ${invoice.invoiceNumber}',
      author: profile.name,
      theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!),
    );

    final address = [profile.addressLine.trim(), profile.city.trim()]
        .where((s) => s.isNotEmpty)
        .join(', ');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        // Header: garage on the left, document title on the right.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(profile.name, style: t(16, bold: true)),
                  if (address.isNotEmpty) pw.Text(address, style: t(9, color: muted)),
                  if (profile.phone.trim().isNotEmpty)
                    pw.Text('Phone ${profile.phone}', style: t(9, color: muted)),
                  if (hasGstin) pw.Text('GSTIN ${profile.gstin}', style: t(9, color: muted)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(hasGstin ? 'TAX INVOICE' : 'BILL', style: t(13, bold: true)),
                pw.Text(invoice.invoiceNumber, style: t(10)),
                pw.Text(AppDateFormatter.formatDate(invoice.invoiceDate), style: t(9, color: muted)),
                if (invoice.dueDate != null)
                  pw.Text('Due ${AppDateFormatter.formatDate(invoice.dueDate!)}',
                      style: t(9, color: muted)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(color: line),
        pw.SizedBox(height: 8),

        // Billed to / vehicle.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('BILLED TO', style: t(8, bold: true, color: muted)),
                  pw.Text(customer?.name ?? '-', style: t(11, bold: true)),
                  if (customer != null && customer.phone.trim().isNotEmpty)
                    pw.Text(customer.phone, style: t(9, color: muted)),
                  if (customer?.gstin?.trim().isNotEmpty ?? false)
                    pw.Text('GSTIN ${customer!.gstin}', style: t(9, color: muted)),
                ],
              ),
            ),
            if (vehicle != null)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('VEHICLE', style: t(8, bold: true, color: muted)),
                  pw.Text(vehicle.registrationNumber, style: t(11, bold: true)),
                  pw.Text(vehicle.displayName, style: t(9, color: muted)),
                  pw.Text('${groupDigits(invoice.kmReading)} km', style: t(9, color: muted)),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 16),

        // Line items.
        pw.TableHelper.fromTextArray(
          border: null,
          headerStyle: t(8.5, bold: true, color: muted),
          cellStyle: t(9.5),
          headerDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: line)),
          ),
          rowDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.5)),
          ),
          cellAlignments: const {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
          },
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.6),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(1.8),
          },
          headers: const ['ITEM', 'QTY', 'RATE', 'GST', 'AMOUNT'],
          data: [
            for (final item in invoice.items)
              [
                [item.name, ?item.discountLabel].join(' • '),
                '${formatQuantity(item.quantity)} ${item.unit}',
                money(item.unitPrice),
                '${item.taxPercent.toStringAsFixed(item.taxPercent % 1 == 0 ? 0 : 1)}%',
                money(item.taxableAmount),
              ],
          ],
        ),
        pw.SizedBox(height: 12),

        // Totals, right-aligned.
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 230,
            child: pw.Column(
              children: [
                sumRow('Subtotal', money(invoice.grossSubtotal)),
                if (invoice.discountAmount > 0)
                  sumRow('Discount', '- ${money(invoice.discountAmount)}'),
                for (final l in gstLines(invoice.taxBreakdown, split: hasGstin))
                  sumRow(l.key, money(l.value)),
                pw.Divider(color: line),
                sumRow('Total', money(invoice.grandTotal), bold: true),
                if (invoice.totalPaidAmount > 0) sumRow('Paid', money(invoice.totalPaidAmount)),
                if (invoice.totalPaidAmount > 0)
                  sumRow('Balance due', money(invoice.balanceDue), bold: true),
              ],
            ),
          ),
        ),

        if (profile.upiId.trim().isNotEmpty && invoice.balanceDue > 0) ...[
          pw.SizedBox(height: 16),
          pw.Text('Pay by UPI: ${profile.upiId}', style: t(9.5, bold: true)),
        ],
        if (invoice.notes?.trim().isNotEmpty ?? false) ...[
          pw.SizedBox(height: 14),
          pw.Text('NOTES', style: t(8, bold: true, color: muted)),
          pw.Text(invoice.notes!.trim(), style: t(9)),
        ],
        if (invoice.termsAndConditions?.trim().isNotEmpty ?? false) ...[
          pw.SizedBox(height: 10),
          pw.Text('TERMS', style: t(8, bold: true, color: muted)),
          pw.Text(invoice.termsAndConditions!.trim(), style: t(8.5, color: muted)),
        ],
        pw.SizedBox(height: 24),
        pw.Center(child: pw.Text('Thank you for your business', style: t(9, color: muted))),
      ],
    ));

    return doc.save();
  }
}
