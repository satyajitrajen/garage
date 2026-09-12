import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/invoice.dart';
import '../../models/payment.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';

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
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<GarageProvider>(context, listen: false);
    // Always validate against the live invoice, not the snapshot passed to
    // this screen — the invoice may have changed since we were pushed.
    final invoice = provider.getInvoiceById(widget.invoice.id) ?? widget.invoice;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment amount must be greater than zero')),
      );
      return;
    }

    if (amount > invoice.balanceDue + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Amount cannot exceed pending balance of ${CurrencyFormatter.format(invoice.balanceDue)}')),
      );
      return;
    }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not record payment: $e')),
      );
      return;
    }

    // Show confirmation modal / dialog
    _remainingDueSnapshot =
        (invoice.balanceDue - payment.amount).clamp(0, double.infinity);
    _showReceiptSuccessDialog(payment, invoice.invoiceNumber);
  }

  void _showReceiptSuccessDialog(Payment payment, String invoiceNumber) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.paid, size: 48),
            ),
            const SizedBox(height: 12),
            Text(
              'Payment Received!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(payment.amount),
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.paid,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paid via ${payment.mode.displayName}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              ),
            ),
            if (payment.transactionRef != null) ...[
              const SizedBox(height: 4),
              Text(
                'Ref: ${payment.transactionRef}',
                style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Invoice:', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted)),
                Text(invoiceNumber, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Remaining Due:', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted)),
                Text(
                  CurrencyFormatter.format(_remainingDueSnapshot),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _remainingDueSnapshot > 0 ? AppColors.pending : AppColors.paid,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final invoice = provider.getInvoiceById(widget.invoice.id) ?? widget.invoice;
    final customer = provider.getCustomerById(invoice.customerId);
    final vehicle = provider.getVehicleById(invoice.vehicleId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Record Payment / Collection', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFF1E293B), const Color(0xFF334155)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
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
                          style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${vehicle?.registrationNumber ?? ""} • ${customer?.name ?? ""}',
                            style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 12.5),
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
                      style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(invoice.balanceDue),
                      style: GoogleFonts.poppins(
                        fontSize: 32,
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
                          style: GoogleFonts.poppins(color: const Color(0xFFCBD5E1), fontSize: 12),
                        ),
                        Text(
                          'Paid So Far: ${CurrencyFormatter.format(invoice.totalPaidAmount)}',
                          style: GoogleFonts.poppins(color: AppColors.paid, fontSize: 12, fontWeight: FontWeight.w600),
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
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _onPaymentTypeToggle(true),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _isFullPayment ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                        side: BorderSide(
                          color: _isFullPayment ? AppColors.primary : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          width: _isFullPayment ? 2 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Full Payment (${CurrencyFormatter.format(invoice.balanceDue)})',
                        style: GoogleFonts.poppins(
                          fontWeight: _isFullPayment ? FontWeight.w700 : FontWeight.w500,
                          color: _isFullPayment ? AppColors.primary : (isDark ? Colors.white : AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _onPaymentTypeToggle(false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_isFullPayment ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                        side: BorderSide(
                          color: !_isFullPayment ? AppColors.primary : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          width: !_isFullPayment ? 2 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Partial Payment',
                        style: GoogleFonts.poppins(
                          fontWeight: !_isFullPayment ? FontWeight.w700 : FontWeight.w500,
                          color: !_isFullPayment ? AppColors.primary : (isDark ? Colors.white : AppColors.textPrimary),
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
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  labelText: 'Amount Received (₹) *',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
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
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
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
                          mode == PaymentMode.cash
                              ? Icons.payments_rounded
                              : mode == PaymentMode.upi
                                  ? Icons.qr_code_2_rounded
                                  : mode == PaymentMode.card
                                      ? Icons.credit_card_rounded
                                      : Icons.account_balance_rounded,
                          size: 16,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(mode.displayName),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
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
                  onPressed: _submitPayment,
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Confirm & Record Payment'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.paid,
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
