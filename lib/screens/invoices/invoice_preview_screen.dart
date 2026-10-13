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
import '../../utils/gst_lines.dart';
import '../../utils/date_formatter.dart';
import '../../utils/payment_mode_display.dart';
import '../../utils/quantity_formatter.dart';
import '../payments/payment_collection_screen.dart';
import '../../theme/app_text.dart';
import '../../utils/error_message.dart';
import '../../utils/grouped_number.dart';
import '../../utils/invoice_pdf.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_language.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final String invoiceId;

  const InvoicePreviewScreen({super.key, required this.invoiceId});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  bool _sharing = false;

  String _summary(Invoice invoice, Customer? customer, Vehicle? vehicle, GarageProfile profile) => [
        '${profile.name}: ${profile.gstin.trim().isEmpty ? tr('Bill') : 'Tax Invoice'} ${invoice.invoiceNumber}',
        if (vehicle != null) 'Vehicle: ${vehicle.registrationNumber}',
        'Total: ${CurrencyFormatter.format(invoice.grandTotal)}',
        if (invoice.balanceDue > 0) 'Balance due: ${CurrencyFormatter.format(invoice.balanceDue)}',
        if (invoice.dueDate != null) 'Due date: ${AppDateFormatter.formatDate(invoice.dueDate!)}',
        if (invoice.balanceDue > 0 && profile.upiId.trim().isNotEmpty) 'Pay by UPI: ${profile.upiId}',
      ].join('\n');

  Future<void> _sharePdf(Invoice invoice, Customer? customer, Vehicle? vehicle, GarageProfile profile) async {
    setState(() => _sharing = true);
    try {
      final bytes = await InvoicePdf.build(
        invoice: invoice,
        profile: profile,
        customer: customer,
        vehicle: vehicle,
      );
      final name = InvoicePdf.fileName(invoice);
      await SharePlus.instance.share(ShareParams(
        title: 'Bill ${invoice.invoiceNumber}',
        text: _summary(invoice, customer, vehicle, profile),
        files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: name)],
        fileNameOverrides: [name],
      ));
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showShareOptions(Invoice invoice, Customer? customer, Vehicle? vehicle, GarageProfile profile) {
    final phone = (customer?.whatsappNumber?.trim().isNotEmpty ?? false)
        ? customer!.whatsappNumber!
        : customer?.phone ?? '';
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusSheet)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(tr('Send PDF bill')),
              subtitle: Text(tr('Pick WhatsApp, email or print')),
              onTap: () {
                Navigator.pop(ctx);
                _sharePdf(invoice, customer, vehicle, profile);
              },
            ),
            if (phone.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: Text('WhatsApp message to ${customer?.name ?? 'customer'}'),
                subtitle: Text(tr('Total, balance and UPI as text')),
                onTap: () {
                  Navigator.pop(ctx);
                  ContactActions.whatsapp(
                    context,
                    phone,
                    message: _summary(invoice, customer, vehicle, profile),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceId = widget.invoiceId;
    final provider = Provider.of<GarageProvider>(context);
    final invoice = provider.getInvoiceById(invoiceId);

    if (invoice == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Bill'))),
        body: Center(child: Text(tr('Bill not found'))),
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
          // Share: the PDF bill (WhatsApp, email, print via the share sheet)
          // or a quick WhatsApp text to the customer.
          IconButton(
            // Building the PDF and opening the share sheet can take a few
            // seconds; show progress and ignore repeat taps meanwhile.
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_rounded),
            tooltip: tr('Share bill'),
            onPressed: _sharing
                ? null
                : () => _showShareOptions(invoice, customer, vehicle, profile),
          ),
          // Cancel action is only meaningful while nothing has been paid and
          // the invoice is still active — paid invoices need a refund flow and
          // cancelled ones are already voided.
          if (invoice.totalPaidAmount <= 0 && invoice.status != InvoiceStatus.cancelled)
            // Cancelling a bill is an invoices.manage write; hide the menu
            // from staff without the permission instead of erroring on tap.
            PermissionGate(
              permission: Permissions.invoicesManage,
              child: PopupMenuButton<String>(
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
                        Text(tr('Cancel bill')),
                      ],
                    ),
                  ),
                ],
              ),
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
                          // Only a GST-registered garage can issue a tax
                          // invoice; without a GSTIN this is a plain bill.
                          Text(profile.gstin.trim().isEmpty ? tr('Bill') : 'Tax invoice',
                              style: GoogleFonts.poppins(
                                  fontSize: AppText.label, color: palette.textMuted)),
                          Text(invoice.invoiceNumber,
                              style: GoogleFonts.poppins(
                                  fontSize: AppText.body, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          _metaLine(tr('Date'), AppDateFormatter.formatDate(invoice.invoiceDate), palette),
                          if (invoice.dueDate != null)
                            _metaLine(
                              tr('Pay by'),
                              AppDateFormatter.formatDate(invoice.dueDate!),
                              palette,
                              // Same amber pending token as the breakdown
                              // below — lateness is a warning, not an error.
                              color: invoice.isOverdue ? palette.pending : null,
                            ),
                          if (invoice.jobCardId != null)
                            _metaLine(
                              tr('Job card'),
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
                            Text(tr('Billed to'), style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted)),
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
                            Text(tr('Vehicle'), style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted)),
                            const SizedBox(height: 2),
                            Text(vehicle?.registrationNumber ?? '', style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            Text(vehicle?.displayName ?? "", style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textSecondary)),
                            Text('${groupDigits(invoice.kmReading)} km', style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textSecondary)),
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
                          child: Text(tr('Item'), style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(tr('Qty'), textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(tr('Rate'), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(tr('Amount'), textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary)),
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
                                  [
                                    item.isLabour ? tr('Labour Charge') : 'Part • ${item.category.displayName}',
                                    ?item.discountLabel,
                                  ].join(' • '),
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
                  _buildSummaryRow(tr('Parts'), CurrencyFormatter.format(invoice.partsSubtotal)),
                  const SizedBox(height: 4),
                  _buildSummaryRow(tr('Labour'), CurrencyFormatter.format(invoice.labourSubtotal)),
                  const SizedBox(height: 4),
                  if (invoice.discountAmount > 0) ...[
                    _buildSummaryRow(tr('Discount Applied:'), '- ${CurrencyFormatter.format(invoice.discountAmount)}', color: palette.paid),
                    const SizedBox(height: 4),
                  ],
                  for (final line in gstLines(invoice.taxBreakdown)) ...[
                    _buildSummaryRow('${line.key}:', CurrencyFormatter.format(line.value)),
                    const SizedBox(height: 4),
                  ],
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('Total'), style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.format(invoice.grandTotal),
                            style: GoogleFonts.poppins(fontSize: AppText.headline, fontWeight: FontWeight.w700, color: palette.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('Paid'), style: GoogleFonts.poppins(fontSize: AppText.body, color: palette.paid, fontWeight: FontWeight.w600)),
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
                        child: Text(tr('Balance due'), style: GoogleFonts.poppins(fontSize: AppText.body, color: invoice.balanceDue > 0 ? palette.pending : palette.paid, fontWeight: FontWeight.w700)),
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
                      tr('Due Date:'),
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
                      tr('Payment History'),
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
                        tr('Notes'),
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
                        tr('Terms & Conditions'),
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
                      tr('Bill Cancelled'),
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
                  // Money-positive action: green `paid`, matching the green
                  // confirm button inside the collection screen (§5).
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: palette.paid,
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
                        tr('Bill Settled & Paid in Full'),
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
        // In-flight latch: a second tap while the cancel request is running
        // would hit the server twice (the retry fails with 422).
        bool cancelling = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(tr('Cancel Bill?')),
            content: Text(
                'Cancel bill ${invoice.invoiceNumber}? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('Keep Bill')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.absent,
                  foregroundColor: palette.onPrimary,
                ),
                onPressed: cancelling
                    ? null
                    : () async {
                        setDialogState(() => cancelling = true);
                        try {
                          await provider.cancelInvoice(invoice.id);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          // A voided bill is a state change, not a failure:
                          // informational near-black, not error red (§2).
                          showAppSnackBar(
                            context,
                            'Bill ${invoice.invoiceNumber} cancelled',
                            type: SnackBarType.info,
                          );
                        } catch (e) {
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          showAppSnackBar(
                            context,
                            errorMessage(e),
                            type: SnackBarType.error,
                          );
                        }
                      },
                child: Text(tr('Cancel Bill')),
              ),
            ],
          ),
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
