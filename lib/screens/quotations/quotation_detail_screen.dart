import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/quotation.dart';
import '../../models/maintenance_item.dart';
import '../../models/invoice.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/quantity_formatter.dart';
import '../../widgets/status_badge.dart';
import '../job_cards/job_card_detail_screen.dart';
import '../invoices/invoice_preview_screen.dart';

class QuotationDetailScreen extends StatelessWidget {
  final String quotationId;

  const QuotationDetailScreen({super.key, required this.quotationId});

  Future<void> _convertJobCard(BuildContext context, Quotation quote) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    final jobCard = await provider.convertQuotationToJobCard(quote);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Converted to Job Card #${jobCard.jobCardNumber}!'),
        backgroundColor: AppColors.paid,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => JobCardDetailScreen(jobCardId: jobCard.id),
      ),
    );
  }

  Future<void> _convertInvoice(BuildContext context, Quotation quote) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    final invoice = await provider.addInvoice(
      Invoice(
        id: const Uuid().v4(),
        invoiceNumber: provider.generateInvoiceNumber(),
        customerId: quote.customerId,
        vehicleId: quote.vehicleId,
        kmReading: quote.kmReading,
        items: quote.items,
        discountAmount: quote.overallDiscount,
        taxPercent: quote.taxPercent,
        invoiceDate: DateTime.now(),
      ),
    );

    await provider.updateQuotationStatus(quote.id, QuotationStatus.converted);

    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePreviewScreen(invoiceId: invoice.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final quote = provider.quotations.where((q) => q.id == quotationId).firstOrNull;

    if (quote == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estimate Details')),
        body: const Center(child: Text('Quotation not found')),
      );
    }

    final customer = provider.getCustomerById(quote.customerId);
    final vehicle = provider.getVehicleById(quote.vehicleId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Conversion is only allowed while the estimate is still open
    // (draft/sent/approved). Already-converted or rejected estimates must
    // not spawn duplicate job cards / invoices.
    final canConvert = quote.status == QuotationStatus.draft ||
        quote.status == QuotationStatus.sent ||
        quote.status == QuotationStatus.approved;

    return Scaffold(
      appBar: AppBar(
        title: Text(quote.quotationNumber, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Estimate',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing Estimate PDF to customer WhatsApp...')),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusBadge.fromQuotationStatus(quote.status),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Estimate Slip Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Workshop Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nexory Garage',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'ESTIMATE / QUOTATION',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            quote.quotationNumber,
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            AppDateFormatter.formatDate(quote.createdAt),
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Customer & Vehicle block
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ESTIMATE FOR:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(customer?.name ?? '', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(customer?.phone ?? '', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('VEHICLE:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(vehicle?.registrationNumber ?? '', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                          Text('${vehicle?.displayName ?? ""} • ${quote.kmReading} KM', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text('DESCRIPTION', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text('QTY', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('RATE', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('AMOUNT', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Line Items
                  ...quote.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                Text(
                                  item.isLabour ? 'Labour' : 'Part (${item.category.displayName})',
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(formatQuantity(item.quantity), textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(CurrencyFormatter.format(item.unitPrice), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 13)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(CurrencyFormatter.format(item.taxableAmount), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),

                  // Summary
                  _buildSummaryLine('Parts Subtotal', CurrencyFormatter.format(quote.partsSubtotal), isDark),
                  _buildSummaryLine('Labour Subtotal', CurrencyFormatter.format(quote.labourSubtotal), isDark),
                  if (quote.overallDiscount > 0)
                    _buildSummaryLine('Discount', '- ${CurrencyFormatter.format(quote.overallDiscount)}', isDark, color: AppColors.paid),
                  _buildSummaryLine('Estimated Taxes (${quote.taxPercent.toInt()}%)', CurrencyFormatter.format(quote.totalTaxAmount), isDark),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Net Estimated Total:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(
                        CurrencyFormatter.format(quote.grandTotal),
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Validity banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Valid until ${AppDateFormatter.formatDate(quote.validUntil)} (${quote.validityDays} days)',
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Conversion Actions
            if (canConvert)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _convertJobCard(context, quote),
                      icon: const Icon(Icons.assignment_turned_in_rounded),
                      label: const Text('Convert to Job Card'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _convertInvoice(context, quote),
                      icon: const Icon(Icons.receipt_rounded),
                      label: const Text('Direct Invoice'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'This estimate is ${quote.status.displayName.toLowerCase()} — no further actions',
                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, String val, bool isDark, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(val, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: color ?? (isDark ? Colors.white : AppColors.textPrimary))),
        ],
      ),
    );
  }
}
