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

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.invoice.balanceDue.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onPaymentTypeToggle(bool isFull) {
    setState(() {
      _isFullPayment = isFull;
      if (isFull) {
        _amountController.text = widget.invoice.balanceDue.toStringAsFixed(2);
      } else {
        _amountController.text = (widget.invoice.balanceDue / 2).toStringAsFixed(2);
      }
    });
  }

  double _remainingDueSnapshot = 0;

  Future<void> _submitPayment() async {
    // Latch: a fast double-tap on Confirm must not record the payment twice —
    // both taps would pass the balance check before the first save lands.
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<GarageProvider>(context, listen: false);
    // Always validate against the live invoice, not the snapshot passed to
    // this screen — the invoice may have changed since we were pushed.
    final invoice = provider.getInvoiceById(widget.invoice.id) ?? widget.invoice;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      showAppSnackBar(
        context,
        'Payment amount must be greater than zero',
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
        'Could not record payment: ${e.toString().replaceFirst('Exception: ', '')}',
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
              'Payment Received!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: AppText.headline),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(payment.amount),
              style: GoogleFonts.inter(
                fontSize: AppText.display,
                fontWeight: FontWeight.w900,
                color: palette.paid,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paid via ${payment.mode.label}',
              style: GoogleFonts.inter(
                fontSize: AppText.body,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
            if (payment.transactionRef != null) ...[
              const SizedBox(height: 4),
              Text(
                'Ref: ${payment.transactionRef}',
                style: GoogleFonts.inter(fontSize: AppText.caption, color: palette.textMuted),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Invoice:', style: GoogleFonts.inter(fontSize: AppText.caption, color: palette.textMuted)),
                Text(invoiceNumber, style: GoogleFonts.inter(fontSize: AppText.caption, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Remaining Due:', style: GoogleFonts.inter(fontSize: AppText.caption, color: palette.textMuted)),
                Text(
                  CurrencyFormatter.format(_remainingDueSnapshot),
                  style: GoogleFonts.inter(
                    fontSize: AppText.caption,
                    fontWeight: FontWeight.w700,
                    color: _remainingDueSnapshot > 0 ? palette.pending : palette.paid,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context, true); // Return to invoice preview
              },
              child: const Text('Done'),
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
        title: Text('Record Payment / Collection', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
                  // Brand gradient is the fixed brand anchor: white text sits
                  // on top, so a themed surface slot would hide it.
                  gradient: LinearGradient(
                    colors: palette.brandGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${vehicle?.registrationNumber ?? ""} • ${customer?.name ?? ""}',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: AppText.caption),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Outstanding Balance Due',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: AppText.caption),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(invoice.balanceDue),
                      style: GoogleFonts.inter(
                        fontSize: AppText.display,
                        fontWeight: FontWeight.w900,
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
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: AppText.label),
                        ),
                        Text(
                          'Paid So Far: ${CurrencyFormatter.format(invoice.totalPaidAmount)}',
                          style: GoogleFonts.inter(color: palette.paid, fontSize: AppText.label, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Full vs Partial Payment Choice
              Text(
                'Payment Type',
                style: GoogleFonts.inter(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _onPaymentTypeToggle(true),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _isFullPayment ? palette.primary.withOpacity(0.12) : Colors.transparent,
                        side: BorderSide(
                          color: _isFullPayment ? palette.primary : palette.textMuted,
                          width: _isFullPayment ? 2 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Full Payment (${CurrencyFormatter.format(invoice.balanceDue)})',
                        style: GoogleFonts.inter(
                          fontWeight: _isFullPayment ? FontWeight.w700 : FontWeight.w500,
                          color: _isFullPayment ? palette.primary : palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _onPaymentTypeToggle(false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_isFullPayment ? palette.primary.withOpacity(0.12) : Colors.transparent,
                        side: BorderSide(
                          color: !_isFullPayment ? palette.primary : palette.textMuted,
                          width: !_isFullPayment ? 2 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Partial Payment',
                        style: GoogleFonts.inter(
                          fontWeight: !_isFullPayment ? FontWeight.w700 : FontWeight.w500,
                          color: !_isFullPayment ? palette.primary : palette.textPrimary,
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
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: AppText.headline, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Amount Received (₹) *',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: palette.primary),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Payment Mode Selector
              Text(
                'Payment Mode',
                style: GoogleFonts.inter(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
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
                          color: isSelected ? palette.onPrimary : palette.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(mode.label),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: palette.primary,
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
                      ? 'Cash Receipt / Handover Note (Optional)'
                      : _selectedMode == PaymentMode.upi
                          ? 'UPI Reference / UTR Number'
                          : _selectedMode == PaymentMode.card
                              ? 'POS Approval / Last 4 Digits'
                              : 'Bank UTR / Cheque Number',
                  prefixIcon: const Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Payment Notes / Receiver Remarks',
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
                  label: const Text('Confirm & Record Payment'),
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
