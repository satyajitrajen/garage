import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/invoice.dart';
import '../../models/payment.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/payment_mode_display.dart';
import '../../theme/app_text.dart';
import '../../utils/error_message.dart';
import '../../utils/permissions.dart';
import '../../widgets/permission_gate.dart';
import '../../l10n/app_language.dart';
import '../../utils/form_errors.dart';

class PaymentCollectionScreen extends StatefulWidget {
  final Invoice invoice;

  const PaymentCollectionScreen({super.key, required this.invoice});

  @override
  State<PaymentCollectionScreen> createState() => _PaymentCollectionScreenState();
}

class _PaymentCollectionScreenState extends State<PaymentCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();

  PaymentMode _selectedMode = PaymentMode.upi;
  bool _isFullPayment = true;
  bool _isSaving = false;
  /// Amount the last Full/Partial preset wrote into the field, so the next
  /// toggle only overwrites when the user has not typed their own amount.
  String _lastPresetAmount = '';

  @override
  void initState() {
    super.initState();
    _lastPresetAmount = widget.invoice.balanceDue.toStringAsFixed(2);
    _amountController.text = _lastPresetAmount;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onPaymentTypeToggle(bool isFull) {
    final preset = isFull
        ? widget.invoice.balanceDue.toStringAsFixed(2)
        : (widget.invoice.balanceDue / 2).toStringAsFixed(2);
    setState(() {
      _isFullPayment = isFull;
      // Only overwrite when the field still holds the previous preset — an
      // amount the user typed by hand must survive switching Full/Partial.
      if (_amountController.text.trim() == _lastPresetAmount) {
        _amountController.text = preset;
      }
      _lastPresetAmount = preset;
    });
  }

  double _remainingDueSnapshot = 0;

  Future<void> _submitPayment() async {
    // Latch: a fast double-tap on Confirm must not record the payment twice —
    // both taps would pass the balance check before the first save lands.
    if (_isSaving) return;
    // Re-check at the mutation entry: recording a payment is a
    // payments.record write, not just a screen the staff can open.
    if (!ensurePermission(context, Permissions.paymentsRecord)) return;
    if (!_formKey.currentState!.validate()) {
      scrollToFirstFormError(_formKey);
      return;
    }

    final provider = Provider.of<GarageProvider>(context, listen: false);
    // Always validate against the live invoice, not the snapshot passed to
    // this screen — the invoice may have changed since we were pushed.
    final invoice = provider.getInvoiceById(widget.invoice.id) ?? widget.invoice;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      showAppSnackBar(
        context,
        tr('Payment amount must be greater than zero'),
        type: SnackBarType.error,
      );
      return;
    }

    if (amount > invoice.balanceDue + 0.01) {
      showAppSnackBar(
        context,
        'Amount cannot exceed pending balance of ${CurrencyFormatter.format(invoice.balanceDue)}',
        type: SnackBarType.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    final Payment payment;
    try {
      payment = await provider.recordPayment(
        invoiceId: invoice.id,
        amount: amount,
        mode: _selectedMode,
        transactionRef: _refController.text.trim().isEmpty ? null : _refController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Could not record payment: ${errorMessage(e)}',
        type: SnackBarType.error,
      );
      return;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    // Show confirmation modal / dialog
    _remainingDueSnapshot =
        (invoice.balanceDue - payment.amount).clamp(0, double.infinity);
    _showReceiptSuccessDialog(payment, invoice.invoiceNumber);
  }

  void _showReceiptSuccessDialog(Payment payment, String invoiceNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Captured inside the builder so the dialog always renders with the
        // live theme, like the other dialogs in the app.
        final palette = dialogContext.palette;
        return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusCard)),
        backgroundColor: palette.card,
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // The design-system green badge background stands in for the
                // old one-off pastel literal (0xFFDCFCE7).
                color: palette.badgeGreenBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, color: palette.paid, size: 48),
            ),
            const SizedBox(height: 12),
            Text(
              tr('Payment Received!'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: AppText.headline),
            ),
          ],
        ),
        // Scrolls when large text makes the receipt taller than the dialog.
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                CurrencyFormatter.format(payment.amount),
                style: GoogleFonts.poppins(
                  fontSize: AppText.display,
                  fontWeight: FontWeight.w700,
                  color: palette.paid,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paid via ${payment.mode.label}',
              style: GoogleFonts.poppins(
                fontSize: AppText.body,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
            if (payment.transactionRef != null) ...[
              const SizedBox(height: 4),
              Text(
                'Ref: ${payment.transactionRef}',
                style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textMuted),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(tr('Bill:'), style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textMuted)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(invoiceNumber,
                      textAlign: TextAlign.end,
                      style: GoogleFonts.poppins(fontSize: AppText.caption, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(tr('Remaining Due:'), style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textMuted)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    CurrencyFormatter.format(_remainingDueSnapshot),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.poppins(
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w700,
                      color: _remainingDueSnapshot > 0 ? palette.pending : palette.paid,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context, true); // Return to invoice preview
              },
              child: Text(tr('Done')),
            ),
          ),
        ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final invoice = provider.getInvoiceById(widget.invoice.id) ?? widget.invoice;
    final customer = provider.getCustomerById(invoice.customerId);
    final vehicle = provider.getVehicleById(invoice.vehicleId);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Record Payment / Collection'), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pending Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  // Design-system banner gradient (near-black), not brand
                  // red: a big red card read as an error. White text sits on
                  // top in both themes.
                  gradient: LinearGradient(
                    colors: palette.bannerGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${vehicle?.registrationNumber ?? ""} • ${customer?.name ?? ""}',
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: AppText.caption),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr('Outstanding Balance Due'),
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: AppText.caption),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(invoice.balanceDue),
                      style: GoogleFonts.poppins(
                        fontSize: AppText.display,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Total Bill: ${CurrencyFormatter.format(invoice.grandTotal)}',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: AppText.label),
                        ),
                        Text(
                          'Paid So Far: ${CurrencyFormatter.format(invoice.totalPaidAmount)}',
                          // White on the red card: green on red was unreadable.
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: AppText.label, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Full vs Partial Payment Choice
              Text(
                tr('Payment Type'),
                style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _onPaymentTypeToggle(true),
                      style: OutlinedButton.styleFrom(
                        // Selected = accent near-black; brand red is for
                        // actions only, and picking a type is informational.
                        backgroundColor: _isFullPayment ? palette.accent.withOpacity(0.12) : Colors.transparent,
                        side: BorderSide(
                          color: _isFullPayment ? palette.accent : palette.textMuted,
                          width: _isFullPayment ? 2 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Full Payment (${CurrencyFormatter.format(invoice.balanceDue)})',
                        style: GoogleFonts.poppins(
                          fontWeight: _isFullPayment ? FontWeight.w700 : FontWeight.w500,
                          color: _isFullPayment ? palette.accent : palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _onPaymentTypeToggle(false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_isFullPayment ? palette.accent.withOpacity(0.12) : Colors.transparent,
                        side: BorderSide(
                          color: !_isFullPayment ? palette.accent : palette.textMuted,
                          width: !_isFullPayment ? 2 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr('Partial Payment'),
                        style: GoogleFonts.poppins(
                          fontWeight: !_isFullPayment ? FontWeight.w700 : FontWeight.w500,
                          color: !_isFullPayment ? palette.accent : palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.poppins(fontSize: AppText.headline, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: tr('Amount Received (₹) *'),
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: palette.primary),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return tr('Enter amount');
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) return tr('Invalid amount');
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Payment Mode Selector
              Text(
                tr('Payment Mode'),
                style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PaymentMode.values.map((mode) {
                  final isSelected = _selectedMode == mode;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          mode.icon,
                          size: 16,
                          color: isSelected ? palette.onPrimary : palette.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(mode.label),
                      ],
                    ),
                    selected: isSelected,
                    // Selected chip = accent near-black; brand red is for
                    // actions only (§2).
                    selectedColor: palette.accent,
                    labelStyle: TextStyle(
                      color: isSelected ? palette.onPrimary : palette.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedMode = mode);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Transaction Reference (if UPI / Card / Bank / Cheque)
              TextFormField(
                controller: _refController,
                decoration: InputDecoration(
                  labelText: _selectedMode == PaymentMode.cash
                      ? tr('Cash Receipt / Handover Note (Optional)')
                      : _selectedMode == PaymentMode.upi
                          ? tr('UPI Reference / UTR Number')
                          : _selectedMode == PaymentMode.card
                              ? tr('POS Approval / Last 4 Digits')
                              : tr('Bank UTR / Cheque Number'),
                  prefixIcon: const Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('Payment Notes / Receiver Remarks'),
                  hintText: 'e.g. Received full settlement in cash with receipt issued',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitPayment,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.verified_rounded),
                  label: Text(tr('Confirm & Record Payment')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: palette.paid,
                    foregroundColor: palette.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
