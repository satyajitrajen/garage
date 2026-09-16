import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../models/invoice.dart';
import '../../models/maintenance_item.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../maintenance/add_maintenance_screen.dart';
import 'invoice_preview_screen.dart';
import '../../theme/app_text.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Customer customer;
  final Vehicle vehicle;

  const CreateInvoiceScreen({
    super.key,
    required this.customer,
    required this.vehicle,
  });

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kmController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  final List<MaintenanceItem> _items = [];
  double _taxPercent = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _taxPercent = context.read<GarageProvider>().config.defaultTaxPercent;
    _kmController.text = widget.vehicle.currentKm.toString();
  }

  @override
  void dispose() {
    _kmController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _openAddItems() async {
    final items = await Navigator.push<List<MaintenanceItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          initialItems: _items,
          title: 'Add Invoice Line Items',
        ),
      ),
    );

    if (!mounted) return;
    if (items != null) {
      setState(() {
        _items.clear();
        _items.addAll(items);
      });
    }
  }

  Future<void> _saveInvoice() async {
    // Latch: a fast double-tap on Save must not create two invoices.
    if (_isSaving) return;
    if (_items.isEmpty) {
      showAppSnackBar(
        context,
        'Please add at least one item or labour charge to generate bill',
        type: SnackBarType.info,
      );
      return;
    }

    final provider = Provider.of<GarageProvider>(context, listen: false);
    final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final gross = _items.fold(0.0, (sum, i) => sum + i.taxableAmount);
    if (discount < 0 || discount > gross) {
      showAppSnackBar(
        context,
        'Discount must be between 0 and ${CurrencyFormatter.format(gross)}',
        type: SnackBarType.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    final invoice = Invoice(
      id: const Uuid().v4(),
      invoiceNumber: provider.generateInvoiceNumber(),
      customerId: widget.customer.id,
      vehicleId: widget.vehicle.id,
      kmReading: int.tryParse(_kmController.text.trim()) ?? widget.vehicle.currentKm,
      items: _items,
      discountAmount: discount,
      taxPercent: _taxPercent,
      invoiceDate: DateTime.now(),
      dueDate: DateTime.now().add(Duration(days: provider.config.invoiceDueDays)),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    try {
      await provider.addInvoice(invoice);
      if (!mounted) return;

      // The invoice itself is committed; addInvoice downgrades a failed
      // vehicle/job-card side effect to a warning. Show it last so it is not
      // replaced by the success message.
      showAppSnackBar(
        context,
        'Invoice #${invoice.invoiceNumber} created successfully!',
        type: SnackBarType.success,
      );
      if (provider.sideEffectWarning != null) {
        showAppSnackBar(
          context,
          provider.sideEffectWarning!,
          type: SnackBarType.info,
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePreviewScreen(invoiceId: invoice.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final config = context.read<GarageProvider>().config;

    final partsSubtotal = _items.where((i) => !i.isLabour).fold(0.0, (sum, i) => sum + i.taxableAmount);
    final labourSubtotal = _items.where((i) => i.isLabour).fold(0.0, (sum, i) => sum + i.taxableAmount);
    final grossSubtotal = partsSubtotal + labourSubtotal;
    final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final taxableSubtotal = (grossSubtotal - discount).clamp(0.0, double.infinity);
    final taxAmount = taxableSubtotal * (_taxPercent / 100);
    final grandTotal = taxableSubtotal + taxAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Direct Tax Invoice', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer & Vehicle summary banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: palette.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customer.name,
                            style: GoogleFonts.inter(fontSize: AppText.title, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.vehicle.displayName} (${widget.vehicle.registrationNumber})',
                            style: GoogleFonts.inter(
                              fontSize: AppText.body,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Items Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill Line Items (${_items.length})',
                    style: GoogleFonts.inter(fontSize: AppText.title, fontWeight: FontWeight.w700),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openAddItems,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Items'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_items.isEmpty)
                const EmptyStateWidget(
                  icon: Icons.shopping_bag_outlined,
                  title: 'No items in bill yet',
                  description: 'Add services, spare parts or oils to create bill',
                )
              else
                ..._items.map((item) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      subtitle: Text('${item.quantity} ${item.unit} @ ${CurrencyFormatter.format(item.unitPrice)}'),
                      trailing: Text(
                        CurrencyFormatter.format(item.totalAmount),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.primary),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),

              // Taxes & Discount Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      initialValue: _taxPercent,
                      decoration: const InputDecoration(labelText: 'GST Tax Rate'),
                      items: config.taxPercentOptions.map((rate) {
                        return DropdownMenuItem(
                          value: rate,
                          child: Text(rate > 0
                              ? '${rate.toStringAsFixed(0)}% (CGST ${(rate / 2).toStringAsFixed(1)}% + SGST ${(rate / 2).toStringAsFixed(1)}%)'
                              : '${rate.toStringAsFixed(0)}%'),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _taxPercent = val ?? config.defaultTaxPercent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Discount (₹)',
                        prefixIcon: Icon(Icons.discount_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // KM Reading
              TextFormField(
                controller: _kmController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Current KM Reading',
                  prefixIcon: Icon(Icons.speed_rounded),
                ),
              ),
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Invoice Notes / Customer Remarks',
                  hintText: 'e.g. Standard 30 days warranty on labour',
                ),
              ),
              const SizedBox(height: 24),

              // Financial Summary Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  children: [
                    _buildRow('Parts Total:', CurrencyFormatter.format(partsSubtotal), palette),
                    const SizedBox(height: 4),
                    _buildRow('Labour Total:', CurrencyFormatter.format(labourSubtotal), palette),
                    const SizedBox(height: 4),
                    if (discount > 0) ...[
                      _buildRow('Discount:', '- ${CurrencyFormatter.format(discount)}', palette, color: palette.paid),
                      const SizedBox(height: 4),
                    ],
                    _buildRow('GST Taxes (${_taxPercent.toInt()}%):', CurrencyFormatter.format(taxAmount), palette),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Net Payable Total:', style: GoogleFonts.inter(fontSize: AppText.title, fontWeight: FontWeight.w700)),
                        Text(
                          CurrencyFormatter.format(grandTotal),
                          style: GoogleFonts.inter(
                            fontSize: AppText.headline,
                            fontWeight: FontWeight.w900,
                            color: palette.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Save Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveInvoice,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Save & Preview Bill'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildRow(String label, String value, AppPalette palette, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: AppText.caption, color: palette.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: GoogleFonts.inter(fontSize: AppText.body, fontWeight: FontWeight.w600, color: color ?? palette.textPrimary)),
      ],
    );
  }
}
