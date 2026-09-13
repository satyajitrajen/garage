import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/quotation.dart';
import '../../models/maintenance_item.dart';
import '../../models/invoice.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/contact_actions.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/quantity_formatter.dart';
import '../../widgets/status_badge.dart';
import '../job_cards/job_card_detail_screen.dart';
import '../invoices/invoice_preview_screen.dart';
import 'create_quotation_screen.dart';
import '../../theme/app_text.dart';

class QuotationDetailScreen extends StatelessWidget {
  final String quotationId;

  const QuotationDetailScreen({super.key, required this.quotationId});

  Future<void> _convertJobCard(BuildContext context, Quotation quote) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    try {
      final jobCard = await provider.convertQuotationToJobCard(quote);
      if (!context.mounted) return;

      showAppSnackBar(
        context,
        'Converted to Job Card #${jobCard.jobCardNumber}!',
        type: SnackBarType.success,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JobCardDetailScreen(jobCardId: jobCard.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _convertInvoice(BuildContext context, Quotation quote) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    try {
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
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _editQuotation(BuildContext context, Quotation quote) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    final customer = provider.getCustomerById(quote.customerId);
    final vehicle = provider.getVehicleById(quote.vehicleId);
    if (customer == null || vehicle == null) {
      showAppSnackBar(
        context,
        'Customer or vehicle for this estimate no longer exists',
        type: SnackBarType.error,
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateQuotationScreen(
          customer: customer,
          vehicle: vehicle,
          existing: quote,
        ),
      ),
    );
    // The quotation is re-read from the provider on every build, so the
    // notifyListeners() fired by updateQuotation refreshes this screen.
  }

  Future<void> _approveQuotation(BuildContext context, Quotation quote) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    try {
      await provider.updateQuotationStatus(quote.id, QuotationStatus.approved);
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        'Estimate #${quote.quotationNumber} approved',
        type: SnackBarType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _declineQuotation(BuildContext context, Quotation quote) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final palette = dialogCtx.palette;
        return AlertDialog(
          title: const Text('Decline Estimate?'),
          content: Text(
              'Mark estimate #${quote.quotationNumber} as declined by the customer? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Keep Estimate'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.pending,
                foregroundColor: palette.onPrimary,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await provider.updateQuotationStatus(quote.id, QuotationStatus.rejected);
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        'Estimate #${quote.quotationNumber} declined',
        type: SnackBarType.error,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    }
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
    final profile = provider.profile;
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(quote.quotationNumber, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Estimate',
            onPressed: () {
              final lines = [
                '${profile.name} — Estimate ${quote.quotationNumber}',
                'Customer: ${customer?.name ?? '-'}',
                if (vehicle != null) 'Vehicle: ${vehicle.registrationNumber}',
                'Estimated Total: ${CurrencyFormatter.format(quote.grandTotal)}',
                'Valid until ${AppDateFormatter.formatDate(quote.validUntil)} (${quote.validityDays} days)',
              ];
              ContactActions.shareText(
                context,
                title: 'Estimate ${quote.quotationNumber}',
                text: lines.join('\n'),
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
                color: palette.paperBg,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                border: Border.all(
                  color: palette.border,
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
                      // Expanded + ellipsis so long profile strings shrink the
                      // left column instead of overflowing the letterhead row.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: AppText.title,
                                fontWeight: FontWeight.w800,
                                color: palette.primary,
                              ),
                            ),
                            if (profile.tagline.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                profile.tagline.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: AppText.label,
                                  fontWeight: FontWeight.w500,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              'ESTIMATE / QUOTATION',
                              style: GoogleFonts.inter(
                                fontSize: AppText.label,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: palette.textMuted,
                              ),
                            ),
                            Text(
                              'GSTIN: ${profile.gstin}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: AppText.label,
                                color: palette.textMuted,
                              ),
                            ),
                            Text(
                              '${profile.addressLine}, ${profile.city}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: AppText.label,
                                color: palette.textMuted,
                              ),
                            ),
                            Text(
                              'Phone: ${profile.phone}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: AppText.label,
                                color: palette.textMuted,
                              ),
                            ),
                            if (profile.email.trim().isNotEmpty)
                              Text(
                                'Email: ${profile.email.trim()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: AppText.label,
                                  color: palette.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            quote.quotationNumber,
                            style: GoogleFonts.inter(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            AppDateFormatter.formatDate(quote.createdAt),
                            style: GoogleFonts.inter(fontSize: AppText.label, color: palette.textMuted),
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
                          Text('ESTIMATE FOR:', style: GoogleFonts.inter(fontSize: AppText.label, fontWeight: FontWeight.w600, color: palette.textMuted)),
                          const SizedBox(height: 2),
                          Text(customer?.name ?? '', style: GoogleFonts.inter(fontSize: AppText.subtitle, fontWeight: FontWeight.w700)),
                          Text(customer?.phone ?? '', style: GoogleFonts.inter(fontSize: AppText.caption, color: palette.textSecondary)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('VEHICLE:', style: GoogleFonts.inter(fontSize: AppText.label, fontWeight: FontWeight.w600, color: palette.textMuted)),
                          const SizedBox(height: 2),
                          Text(vehicle?.registrationNumber ?? '', style: GoogleFonts.inter(fontSize: AppText.subtitle, fontWeight: FontWeight.w700)),
                          Text('${vehicle?.displayName ?? ""} • ${quote.kmReading} KM', style: GoogleFonts.inter(fontSize: AppText.caption, color: palette.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.paperHeaderBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text('DESCRIPTION', style: GoogleFonts.inter(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text('QTY', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('RATE', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('AMOUNT', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
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
                                Text(item.name, style: GoogleFonts.inter(fontSize: AppText.body, fontWeight: FontWeight.w600)),
                                Text(
                                  item.isLabour ? 'Labour' : 'Part (${item.category.displayName})',
                                  style: GoogleFonts.inter(fontSize: AppText.label, color: palette.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(formatQuantity(item.quantity), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: AppText.caption)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(CurrencyFormatter.format(item.unitPrice), textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: AppText.caption)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(CurrencyFormatter.format(item.taxableAmount), textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: AppText.body, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),

                  // Summary
                  _buildSummaryLine('Parts Subtotal', CurrencyFormatter.format(quote.partsSubtotal), palette),
                  _buildSummaryLine('Labour Subtotal', CurrencyFormatter.format(quote.labourSubtotal), palette),
                  if (quote.overallDiscount > 0)
                    _buildSummaryLine('Discount', '- ${CurrencyFormatter.format(quote.overallDiscount)}', palette, color: palette.paid),
                  _buildSummaryLine('Estimated Taxes (${quote.taxPercent.toInt()}%)', CurrencyFormatter.format(quote.totalTaxAmount), palette),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Net Estimated Total:', style: GoogleFonts.inter(fontSize: AppText.title, fontWeight: FontWeight.w800)),
                      Text(
                        CurrencyFormatter.format(quote.grandTotal),
                        style: GoogleFonts.inter(fontSize: AppText.headline, fontWeight: FontWeight.w900, color: palette.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Validity banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: palette.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Valid until ${AppDateFormatter.formatDate(quote.validUntil)} (${quote.validityDays} days)',
                          style: GoogleFonts.inter(fontSize: AppText.caption, fontWeight: FontWeight.w500, color: palette.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Lifecycle Actions: approved estimates can be converted; open
            // estimates (draft/sent) can still be edited, approved or
            // declined; converted/rejected estimates are locked.
            if (quote.status == QuotationStatus.approved)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _convertJobCard(context, quote),
                      icon: const Icon(Icons.assignment_turned_in_rounded),
                      label: const Text('Convert to Job Card'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
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
            else if (quote.status == QuotationStatus.draft ||
                quote.status == QuotationStatus.sent)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editQuotation(context, quote),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveQuotation(context, quote),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: palette.paid,
                        foregroundColor: palette.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _declineQuotation(context, quote),
                      icon: const Icon(Icons.block_rounded, size: 18),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: palette.pending,
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
                  color: palette.textMuted.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 16, color: palette.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'This estimate is ${quote.status.displayName.toLowerCase()} — no further actions',
                      style: GoogleFonts.inter(fontSize: AppText.caption, fontWeight: FontWeight.w600, color: palette.textMuted),
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

  Widget _buildSummaryLine(String label, String val, AppPalette palette, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: AppText.caption, color: palette.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(val, style: GoogleFonts.inter(fontSize: AppText.body, fontWeight: FontWeight.w600, color: color ?? palette.textPrimary)),
        ],
      ),
    );
  }
}
