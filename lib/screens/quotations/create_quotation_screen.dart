import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../models/quotation.dart';
import '../../models/maintenance_item.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../maintenance/add_maintenance_screen.dart';
import 'quotation_detail_screen.dart';

class CreateQuotationScreen extends StatefulWidget {
  final Customer customer;
  final Vehicle vehicle;

  /// Non-null puts the screen in edit mode: fields are prefilled from this
  /// quotation and saving updates it (number, status and timestamps kept).
  final Quotation? existing;

  const CreateQuotationScreen({
    super.key,
    required this.customer,
    required this.vehicle,
    this.existing,
  });

  @override
  State<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends State<CreateQuotationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kmController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  final List<MaintenanceItem> _items = [];
  int _validityDays = 7;
  double _taxPercent = 0.0;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final config = context.read<GarageProvider>().config;
    _taxPercent = config.defaultTaxPercent;
    _validityDays = config.quotationValidityOptions.first;
    _kmController.text = widget.vehicle.currentKm.toString();

    // Edit mode: prefill everything from the quotation being edited.
    final existing = widget.existing;
    if (existing != null) {
      _kmController.text = existing.kmReading.toString();
      _discountController.text = existing.overallDiscount == 0
          ? '0'
          : existing.overallDiscount.toStringAsFixed(2);
      _notesController.text = existing.notes ?? '';
      _items.addAll(existing.items.map((item) => item.copyWith()));
      // Dropdowns assert when their initial value is not among the options.
      _validityDays = config.quotationValidityOptions.contains(existing.validityDays)
          ? existing.validityDays
          : config.quotationValidityOptions.first;
      _taxPercent = config.taxPercentOptions.contains(existing.taxPercent)
          ? existing.taxPercent
          : config.defaultTaxPercent;
    }
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
          title: 'Add Estimate Items',
        ),
      ),
    );

    if (items != null) {
      setState(() {
        _items.clear();
        _items.addAll(items);
      });
    }
  }

  Future<void> _saveQuotation() async {
    // Latch: a fast double-tap on Save must not create two quotations.
    if (_isSaving) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one service or spare part item')),
      );
      return;
    }

    final provider = Provider.of<GarageProvider>(context, listen: false);
    final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final gross = _items.fold(0.0, (sum, i) => sum + i.taxableAmount);
    if (discount < 0 || discount > gross) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Discount must be between 0 and ${CurrencyFormatter.format(gross)}'),
          backgroundColor: AppColors.pending,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    final km = int.tryParse(_kmController.text.trim()) ?? widget.vehicle.currentKm;

    try {
      if (_isEditing) {
        // Edit mode: rebuild from the existing quotation so the quotation
        // number, status and timestamps stay untouched.
        final existing = widget.existing!;
        final edited = Quotation(
          id: existing.id,
          quotationNumber: existing.quotationNumber,
          customerId: existing.customerId,
          vehicleId: existing.vehicleId,
          kmReading: int.tryParse(_kmController.text.trim()) ?? existing.kmReading,
          items: _items,
          overallDiscount: discount,
          taxPercent: _taxPercent,
          validityDays: _validityDays,
          status: existing.status,
          notes: notes,
          createdAt: existing.createdAt,
          validUntil: existing.validUntil,
        );

        await provider.updateQuotation(edited);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estimate #${existing.quotationNumber} updated successfully!'),
            backgroundColor: AppColors.paid,
          ),
        );

        Navigator.pop(context);
      } else {
        final quote = Quotation(
          id: const Uuid().v4(),
          // Quotation numbers are generated only for new estimates.
          quotationNumber: provider.generateQuotationNumber(),
          customerId: widget.customer.id,
          vehicleId: widget.vehicle.id,
          kmReading: km,
          items: _items,
          overallDiscount: discount,
          taxPercent: _taxPercent,
          validityDays: _validityDays,
          status: QuotationStatus.sent,
          notes: notes,
        );

        await provider.addQuotation(quote);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estimate #${quote.quotationNumber} saved successfully!'),
            backgroundColor: AppColors.paid,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuotationDetailScreen(quotationId: quote.id),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.pending,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = context.read<GarageProvider>().config;

    final partsSubtotal = _items.where((i) => !i.isLabour).fold(0.0, (sum, i) => sum + i.taxableAmount);
    final labourSubtotal = _items.where((i) => i.isLabour).fold(0.0, (sum, i) => sum + i.taxableAmount);
    final grossSubtotal = partsSubtotal + labourSubtotal;
    final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final discountedSubtotal = (grossSubtotal - discount).clamp(0.0, double.infinity);
    final taxAmount = discountedSubtotal * (_taxPercent / 100);
    final grandTotal = discountedSubtotal + taxAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Estimate' : 'Create Quotation / Estimate', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.request_quote_rounded, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customer.name,
                            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.vehicle.displayName} (${widget.vehicle.registrationNumber})',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Items Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Estimate Line Items (${_items.length})',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.add_shopping_cart_rounded, size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        'No services or parts added yet',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "+ Add Items" to pick from catalogue or add custom items',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              else
                ..._items.map((item) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text('${item.quantity} ${item.unit} @ ${CurrencyFormatter.format(item.unitPrice)}'),
                      trailing: Text(
                        CurrencyFormatter.format(item.totalAmount),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),

              // Validity & Taxes
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _validityDays,
                      decoration: const InputDecoration(labelText: 'Quote Validity'),
                      items: config.quotationValidityOptions
                          .map((days) => DropdownMenuItem(
                                value: days,
                                child: Text('$days Days'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(
                          () => _validityDays = val ?? config.quotationValidityOptions.first),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      initialValue: _taxPercent,
                      decoration: const InputDecoration(labelText: 'Tax Rate'),
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
                ],
              ),
              const SizedBox(height: 14),

              // Discount & KM
              Row(
                children: [
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _kmController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'KM Reading',
                        prefixIcon: Icon(Icons.speed_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Estimate Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Quotation Notes / Terms',
                  hintText: 'e.g. Price valid for genuine OEM parts. Labour included.',
                ),
              ),
              const SizedBox(height: 24),

              // Totals Summary Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Parts Subtotal:', CurrencyFormatter.format(partsSubtotal), isDark),
                    const SizedBox(height: 6),
                    _buildSummaryRow('Labour Subtotal:', CurrencyFormatter.format(labourSubtotal), isDark),
                    const SizedBox(height: 6),
                    if (discount > 0) ...[
                      _buildSummaryRow('Discount:', '- ${CurrencyFormatter.format(discount)}', isDark, color: AppColors.paid),
                      const SizedBox(height: 6),
                    ],
                    _buildSummaryRow('Taxes (${_taxPercent.toInt()}%):', CurrencyFormatter.format(taxAmount), isDark),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estimated Total:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(
                          CurrencyFormatter.format(grandTotal),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveQuotation,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_isEditing ? 'Save Changes' : 'Save & Send Estimate'),
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

  Widget _buildSummaryRow(String label, String value, bool isDark, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: color ?? (isDark ? Colors.white : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
