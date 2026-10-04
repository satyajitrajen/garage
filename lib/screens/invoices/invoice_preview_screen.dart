import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../widgets/permission_gate.dart';
import '../../utils/permissions.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/garage_profile.dart';
import '../../models/invoice.dart';
import '../../models/maintenance_item.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/contact_actions.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/payment_mode_display.dart';
import '../../utils/quantity_formatter.dart';
import '../payments/payment_collection_screen.dart';
import '../../theme/app_text.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final String invoiceId;

  const InvoicePreviewScreen({super.key, required this.invoiceId});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final invoiceId = widget.invoiceId;
    final provider = Provider.of<GarageProvider>(context);
    final invoice = provider.getInvoiceById(invoiceId);

    if (invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tax Invoice')),
        body: const Center(child: Text('Invoice not found')),
      );
    }

    final customer = provider.getCustomerById(invoice.customerId);
    final vehicle = provider.getVehicleById(invoice.vehicleId);
    final profile = provider.profile;
    final palette = context.palette;
    final customerGstin = customer?.gstin?.trim();
    final notesText = invoice.notes?.trim() ?? '';
    final termsText = invoice.termsAndConditions?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.invoiceNumber, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          // One share action covering the whole bill — PDF/print is out of
          // scope, so the old "Print Tax Bill" stub was removed.
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Bill',
            onPressed: () {
              final lines = [
                '${profile.name} — Tax Invoice ${invoice.invoiceNumber}',
                'Customer: ${customer?.name ?? '-'}',
                if (vehicle != null) 'Vehicle: ${vehicle.registrationNumber}',
                'Grand Total: ${CurrencyFormatter.format(invoice.grandTotal)}',
                'Balance Due: ${CurrencyFormatter.format(invoice.balanceDue)}',
                if (invoice.dueDate != null)
                  'Due Date: ${AppDateFormatter.formatDate(invoice.dueDate!)}',
              ];
              ContactActions.shareText(
                context,
                title: 'Invoice ${invoice.invoiceNumber}',
                text: lines.join('\n'),
              );
            },
          ),
          // Cancel action is only meaningful while nothing has been paid and
          // the invoice is still active — paid invoices need a refund flow and
          // cancelled ones are already voided.
          if (invoice.totalPaidAmount <= 0 && invoice.status != InvoiceStatus.cancelled)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'cancel_invoice') {
                  _confirmCancelInvoice(context, provider, invoice);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'cancel_invoice',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 18, color: palette.absent),
                      const SizedBox(width: 8),
                      const Text('Cancel invoice'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Tax Invoice Paper Card
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
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Document header: seller on the left, invoice facts on
                  // the right, the way a printed GST tax invoice reads. --
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.name,
                                style: GoogleFonts.poppins(
                                    fontSize: AppText.title, fontWeight: FontWeight.w700)),
                            for (final line in [
                              profile.tagline,
                              [profile.addressLine, profile.city]
                                  .where((e) => e.trim().isNotEmpty)
                                  .join(', '),
                              if (profile.phone.trim().isNotEmpty) 'Ph ${profile.phone}',
                              if (profile.email.trim().isNotEmpty) profile.email,
                            ].where((e) => e.trim().isNotEmpty))
                              Text(line,
                                  style: GoogleFonts.poppins(
                                      fontSize: AppText.label, color: palette.textSecondary)),
                            if (profile.gstin.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('GSTIN ${profile.gstin}',
                                    style: GoogleFonts.poppins(
                                        fontSize: AppText.label,
                                        fontWeight: FontWeight.w600,
                                        color: palette.textPrimary)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Invoice facts shrink to fit next to a long seller
                      // block on narrow screens / large text.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topRight,
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Tax invoice',
                              style: GoogleFonts.poppins(
                                  fontSize: AppText.label, color: palette.textMuted)),
                          Text(invoice.invoiceNumber,
                              style: GoogleFonts.poppins(
                                  fontSize: AppText.body, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          _metaLine('Date', AppDateFormatter.formatDate(invoice.invoiceDate), palette),
                          if (invoice.dueDate != null)
                            _metaLine(
                              'Pay by',
                              AppDateFormatter.formatDate(invoice.dueDate!),
                              palette,
                              color: invoice.isOverdue ? palette.absent : null,
                            ),
                          if (invoice.jobCardId != null)
                            _metaLine(
                              'Job card',
                              provider.getJobCardById(invoice.jobCardId!)?.jobCardNumber ?? '—',
                              palette,
                            ),
                        ],
                      ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Bill To (Customer) & Vehicle Specs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Billed to', style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted)),
                            const SizedBox(height: 2),
                            Text(customer?.name ?? '', style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700)),
                            Text(customer?.phone ?? '', style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textSecondary)),
                            if (customer?.address != null)
                              Text(customer!.address!, style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted), maxLines: 2),
                            if (customerGstin != null && customerGstin.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'GSTIN: $customerGstin',
                                style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w600, color: palette.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Vehicle', style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted)),
                            const SizedBox(height: 2),
                            Text(vehicle?.registrationNumber ?? '', style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            Text(vehicle?.displayName ?? "", style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textSecondary)),
                            Text('${invoice.kmReading} km', style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textSecondary)),
                          ],
                        ),
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
                          flex: 4,
                          child: Text('Item', style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text('Qty', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Rate', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Amount', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Table Rows
                  ...invoice.items.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$index. ${item.name}',
                                  style: GoogleFonts.poppins(fontSize: AppText.body, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  item.isLabour ? 'Labour Charge' : 'Part • ${item.category.displayName}',
                                  style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(formatQuantity(item.quantity), textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: AppText.caption)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(CurrencyFormatter.format(item.unitPrice), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: AppText.caption)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(CurrencyFormatter.format(item.taxableAmount), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: AppText.body, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),

                  // Financial Breakdown
                  _buildSummaryRow('Parts', CurrencyFormatter.format(invoice.partsSubtotal)),
                  const SizedBox(height: 4),
                  _buildSummaryRow('Labour', CurrencyFormatter.format(invoice.labourSubtotal)),
                  const SizedBox(height: 4),
                  if (invoice.discountAmount > 0) ...[
                    _buildSummaryRow('Discount Applied:', '- ${CurrencyFormatter.format(invoice.discountAmount)}', color: palette.paid),
                    const SizedBox(height: 4),
                  ],
                  if (invoice.taxPercent > 0) ...[
                    _buildSummaryRow('CGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', CurrencyFormatter.format(invoice.cgstAmount)),
                    const SizedBox(height: 4),
                    _buildSummaryRow('SGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', CurrencyFormatter.format(invoice.sgstAmount)),
                    const SizedBox(height: 4),
                  ],
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.format(invoice.grandTotal),
                            style: GoogleFonts.poppins(fontSize: AppText.headline, fontWeight: FontWeight.w700, color: palette.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Paid', style: GoogleFonts.poppins(fontSize: AppText.body, color: palette.paid, fontWeight: FontWeight.w600)),
                      Text(
                        CurrencyFormatter.format(invoice.totalPaidAmount),
                        style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700, color: palette.paid),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Balance due', style: GoogleFonts.poppins(fontSize: AppText.body, color: invoice.balanceDue > 0 ? palette.pending : palette.paid, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.format(invoice.balanceDue),
                        style: GoogleFonts.poppins(
                          fontSize: AppText.title,
                          fontWeight: FontWeight.w700,
                          color: invoice.balanceDue > 0 ? palette.pending : palette.paid,
                        ),
                      ),
                    ],
                  ),
                  if (invoice.dueDate != null) ...[
                    const SizedBox(height: 4),
                    // Overdue bills flag the due date in the pending color so
                    // the lateness reads at a glance on the printed slip too.
                    _buildSummaryRow(
                      'Due Date:',
                      AppDateFormatter.formatDate(invoice.dueDate!),
                      color: invoice.isOverdue ? palette.pending : null,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Pay by UPI: only while something is owed and the garage
                  // has a UPI ID; the QR carries the exact balance.
                  if (invoice.status != InvoiceStatus.cancelled &&
                      invoice.balanceDue > 0 &&
                      profile.upiId.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: palette.border),
                        borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                      ),
                      child: Row(
                        children: [
                          QrImageView(
                            data: _qrPayload(invoice, profile),
                            size: 96,
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scan to pay ${CurrencyFormatter.format(invoice.balanceDue)}',
                                    style: GoogleFonts.poppins(
                                        fontSize: AppText.body, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('UPI · ${profile.upiId.trim()}',
                                    style: GoogleFonts.poppins(
                                        fontSize: AppText.label, color: palette.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Payment Logs if any
                  if (invoice.payments.isNotEmpty) ...[
                    Text(
                      'Payment History',
                      style: GoogleFonts.poppins(fontSize: AppText.caption, fontWeight: FontWeight.w700, color: palette.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    ...invoice.payments.map((p) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: palette.paid.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                [
                                  // Compact label so "UPI / QR / GPay" and
                                  // friends don't crowd the one-line row.
                                  p.mode.label,
                                  AppDateFormatter.formatDate(p.paymentDate),
                                  if (p.transactionRef?.trim().isNotEmpty ?? false)
                                    'ref ${p.transactionRef!.trim()}',
                                  if (p.receivedBy?.trim().isNotEmpty ?? false)
                                    'by ${p.receivedBy!.trim()}',
                                ].join(' • '),
                                style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(p.amount),
                              style: GoogleFonts.poppins(fontSize: AppText.caption, fontWeight: FontWeight.w700, color: palette.paid),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  // Notes & Terms — printed at the foot of the bill only
                  // when the garage configured them.
                  if (notesText.isNotEmpty || termsText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    if (notesText.isNotEmpty) ...[
                      Text(
                        'Notes',
                        style: GoogleFonts.poppins(fontSize: AppText.caption, fontWeight: FontWeight.w700, color: palette.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notesText,
                        style: GoogleFonts.poppins(fontSize: AppText.label, height: 1.4, color: palette.textSecondary),
                      ),
                    ],
                    if (termsText.isNotEmpty) ...[
                      if (notesText.isNotEmpty) const SizedBox(height: 10),
                      Text(
                        'Terms & Conditions',
                        style: GoogleFonts.poppins(fontSize: AppText.caption, fontWeight: FontWeight.w700, color: palette.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        termsText,
                        style: GoogleFonts.poppins(fontSize: AppText.label, height: 1.4, color: palette.textSecondary),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Action: cancelled invoices branch first — their balance
            // is zeroed by design, so the paid/settled banner below would
            // otherwise claim a voided bill was "paid in full".
            if (invoice.status == InvoiceStatus.cancelled) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: palette.cancelled.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                  border: Border.all(color: palette.cancelled.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel_rounded, color: palette.cancelled, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Invoice Cancelled',
                      style: GoogleFonts.poppins(
                        fontSize: AppText.title,
                        fontWeight: FontWeight.w700,
                        color: palette.cancelled,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (invoice.balanceDue > 0) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!ensurePermission(context, Permissions.paymentsRecord)) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentCollectionScreen(invoice: invoice),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payments_rounded),
                  label: Text('Record Payment (${CurrencyFormatter.format(invoice.balanceDue)} Due)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: palette.paid.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                  border: Border.all(color: palette.paid.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: palette.paid, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Bill Settled & Paid in Full',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: AppText.title,
                          fontWeight: FontWeight.w700,
                          color: palette.paid,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _confirmCancelInvoice(
      BuildContext context, GarageProvider provider, Invoice invoice) {
    if (!ensurePermission(context, Permissions.invoicesManage)) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          title: const Text('Cancel Invoice?'),
          content: const Text('Cancel this invoice? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Invoice'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.pending,
                foregroundColor: palette.onPrimary,
              ),
              onPressed: () async {
                try {
                  await provider.cancelInvoice(invoice.id);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  showAppSnackBar(
                    context,
                    'Invoice ${invoice.invoiceNumber} cancelled',
                    type: SnackBarType.error,
                  );
                } catch (e) {
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  showAppSnackBar(
                    context,
                    e.toString().replaceFirst('Exception: ', ''),
                    type: SnackBarType.error,
                  );
                }
              },
              child: const Text('Cancel Invoice'),
            ),
          ],
        );
      },
    );
  }

  Widget _metaLine(String label, String value, AppPalette palette, {Color? color}) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label  ', style: GoogleFonts.poppins(color: palette.textMuted)),
          TextSpan(
              text: value,
              style: GoogleFonts.poppins(
                  color: color ?? palette.textPrimary, fontWeight: FontWeight.w500)),
        ]),
        style: const TextStyle(fontSize: AppText.label),
      );

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: GoogleFonts.poppins(fontSize: AppText.body, fontWeight: FontWeight.w600, color: color ?? palette.textPrimary)),
      ],
    );
  }

  String _qrPayload(Invoice invoice, GarageProfile profile) {
    if (invoice.balanceDue > 0 && profile.upiId.trim().isNotEmpty) {
      return 'upi://pay?pa=${profile.upiId.trim()}'
          '&pn=${Uri.encodeComponent(profile.name)}'
          '&am=${invoice.balanceDue.toStringAsFixed(2)}&cu=INR';
    }
    return invoice.invoiceNumber;
  }
}
