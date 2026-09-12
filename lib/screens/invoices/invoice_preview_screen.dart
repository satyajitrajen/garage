import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/invoice.dart';
import '../../models/maintenance_item.dart';
import '../../models/payment.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/contact_actions.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/quantity_formatter.dart';
import '../../widgets/status_badge.dart';
import '../payments/payment_collection_screen.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'cancel_invoice',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 18, color: AppColors.pending),
                      SizedBox(width: 8),
                      Text('Cancel Invoice'),
                    ],
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusBadge.fromInvoiceStatus(invoice.status),
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
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                  // Workshop Tax Header
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
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            if (profile.tagline.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                profile.tagline.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              'TAX INVOICE & CASH MEMO',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                              ),
                            ),
                            Text(
                              'GSTIN: ${profile.gstin}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '${profile.addressLine}, ${profile.city}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
                              ),
                            ),
                            Text(
                              'Phone: ${profile.phone}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
                              ),
                            ),
                            if (profile.email.trim().isNotEmpty)
                              Text(
                                'Email: ${profile.email.trim()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            invoice.invoiceNumber,
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Date: ${AppDateFormatter.formatDate(invoice.invoiceDate)}',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                          ),
                          if (invoice.jobCardId != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'JC Ref: ${provider.getJobCardById(invoice.jobCardId!)?.jobCardNumber ?? "JC"}',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
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
                            Text('BILLED TO:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(customer?.name ?? '', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                            Text(customer?.phone ?? '', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                            if (customer?.address != null)
                              Text(customer!.address!, style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textMuted), maxLines: 2),
                            if (customerGstin != null && customerGstin.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'GSTIN: $customerGstin',
                                style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
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
                            Text('VEHICLE DETAILS:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(vehicle?.registrationNumber ?? '', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                            Text(vehicle?.displayName ?? "", style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                            Text('Odometer: ${invoice.kmReading} KM', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
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
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text('ITEM / SERVICE', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
                          child: Text('TOTAL', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
                                  style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  item.isLabour ? 'Labour Charge' : 'Part • ${item.category.displayName}',
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

                  // Financial Breakdown
                  _buildSummaryRow('Spare Parts Subtotal:', CurrencyFormatter.format(invoice.partsSubtotal), isDark),
                  const SizedBox(height: 4),
                  _buildSummaryRow('Labour Charges Subtotal:', CurrencyFormatter.format(invoice.labourSubtotal), isDark),
                  const SizedBox(height: 4),
                  if (invoice.discountAmount > 0) ...[
                    _buildSummaryRow('Discount Applied:', '- ${CurrencyFormatter.format(invoice.discountAmount)}', isDark, color: AppColors.paid),
                    const SizedBox(height: 4),
                  ],
                  if (invoice.taxPercent > 0) ...[
                    _buildSummaryRow('CGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', CurrencyFormatter.format(invoice.cgstAmount), isDark),
                    const SizedBox(height: 4),
                    _buildSummaryRow('SGST (${(invoice.taxPercent / 2).toStringAsFixed(1)}%):', CurrencyFormatter.format(invoice.sgstAmount), isDark),
                    const SizedBox(height: 4),
                  ],
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Grand Total Bill:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(
                        CurrencyFormatter.format(invoice.grandTotal),
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Amount Paid:', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.paid, fontWeight: FontWeight.w600)),
                      Text(
                        CurrencyFormatter.format(invoice.totalPaidAmount),
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.paid),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Balance Due / Pending:', style: GoogleFonts.poppins(fontSize: 14, color: invoice.balanceDue > 0 ? AppColors.pending : AppColors.paid, fontWeight: FontWeight.w700)),
                      Text(
                        CurrencyFormatter.format(invoice.balanceDue),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: invoice.balanceDue > 0 ? AppColors.pending : AppColors.paid,
                        ),
                      ),
                    ],
                  ),
                  if (invoice.dueDate != null) ...[
                    const SizedBox(height: 4),
                    _buildSummaryRow('Due Date:', AppDateFormatter.formatDate(invoice.dueDate!), isDark),
                  ],
                  const SizedBox(height: 16),

                  // Payment Logs if any
                  if (invoice.payments.isNotEmpty) ...[
                    Text(
                      'Payment History',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    ...invoice.payments.map((p) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.paid.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                [
                                  p.mode.displayName,
                                  AppDateFormatter.formatDate(p.paymentDate),
                                  if (p.transactionRef?.trim().isNotEmpty ?? false)
                                    'ref ${p.transactionRef!.trim()}',
                                  if (p.receivedBy?.trim().isNotEmpty ?? false)
                                    'by ${p.receivedBy!.trim()}',
                                ].join(' • '),
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(p.amount),
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.paid),
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
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notesText,
                        style: GoogleFonts.poppins(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : AppColors.textSecondary),
                      ),
                    ],
                    if (termsText.isNotEmpty) ...[
                      if (notesText.isNotEmpty) const SizedBox(height: 10),
                      Text(
                        'Terms & Conditions',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        termsText,
                        style: GoogleFonts.poppins(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : AppColors.textSecondary),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Action: Payment Collection Button
            if (invoice.balanceDue > 0) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
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
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.paid.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.paid.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.paid, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Bill Settled & Paid in Full',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.paid,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Invoice?'),
        content: const Text('Cancel this invoice? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Invoice'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pending,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await provider.cancelInvoice(invoice.id);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Invoice ${invoice.invoiceNumber} cancelled'),
                    backgroundColor: AppColors.pending,
                  ),
                );
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: AppColors.pending,
                  ),
                );
              }
            },
            child: const Text('Cancel Invoice'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: color ?? (isDark ? Colors.white : AppColors.textPrimary))),
      ],
    );
  }
}
