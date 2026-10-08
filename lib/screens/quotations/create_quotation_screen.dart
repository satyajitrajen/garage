import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../models/quotation.dart';
import '../../models/maintenance_item.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/gst_lines.dart';
import '../../widgets/empty_state_widget.dart';
import '../maintenance/add_maintenance_screen.dart';
import 'quotation_detail_screen.dart';
import '../../theme/app_text.dart';
import '../../utils/error_message.dart';

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

  /// New estimates tax each line at its own rate. Editing a legacy estimate
  /// keeps its single document rate (and the rate dropdown) so its approved
  /// total does not change under the customer.
  bool _perItemTax = true;
  bool _isSaving = false;

  /// Edit mode only: set when the user actually changes the validity
  /// dropdown. Untouched edits keep the stored validUntil date verbatim
  /// instead of recomputing it from the day-count (rider: validUntil is
  /// authoritative on edit).
  bool _validityChanged = false;

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
      // ValidUntil is authoritative on edit: derive the displayed day-count
      // from the stored dates instead of trusting validityDays (the two can
      // disagree when a previous save recomputed one but not the other). If
      // the dates are degenerate, fall back to the stored day-count. Either
      // way the value is unioned into the dropdown options in build() so a
      // non-listed count still displays — and is saved back — unchanged.
      final derivedDays = existing.validUntil
          .difference(existing.createdAt)
          .inDays;
      _validityDays = derivedDays > 0 ? derivedDays : existing.validityDays;
      _taxPercent = existing.taxPercent;
      _perItemTax = existing.perItemTax;
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

    if (!mounted) return;
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
      showAppSnackBar(
        context,
        'Please add at least one service or spare part item',
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

    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final km =
        int.tryParse(_kmController.text.trim()) ?? widget.vehicle.currentKm;

    try {
      if (_isEditing) {
        // Edit mode: rebuild from the freshest stored record — widget.existing
        // was captured at construction and the quotation's identity/status
        // fields (number, status, timestamps) may have moved on since (the
        // same re-fetch the job card edit performs).
        final existing =
            provider.getQuotationById(widget.existing!.id) ?? widget.existing!;
        final edited = Quotation(
          id: existing.id,
          quotationNumber: existing.quotationNumber,
          customerId: existing.customerId,
          vehicleId: existing.vehicleId,
          kmReading:
              int.tryParse(_kmController.text.trim()) ?? existing.kmReading,
          items: _items,
          overallDiscount: discount,
          taxPercent: _taxPercent,
          perItemTax: _perItemTax,
          validityDays: _validityDays,
          status: existing.status,
          notes: notes,
          createdAt: existing.createdAt,
          // ValidUntil is authoritative on edit: keep the stored date unless
          // the user actually changed the validity dropdown — recomputing it
          // from a day-count on every save was shifting untouched estimates.
          validUntil: _validityChanged
              ? existing.createdAt.add(Duration(days: _validityDays))
              : existing.validUntil,
        );

        await provider.updateQuotation(edited);
        if (!mounted) return;

        showAppSnackBar(
          context,
          'Estimate #${existing.quotationNumber} updated successfully!',
          type: SnackBarType.success,
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
          perItemTax: true,
          validityDays: _validityDays,
          status: QuotationStatus.sent,
          notes: notes,
        );

        final created = await provider.addQuotation(quote);
        if (!mounted) return;

        showAppSnackBar(
          context,
          'Estimate #${created.quotationNumber} saved successfully!',
          type: SnackBarType.success,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuotationDetailScreen(quotationId: created.id),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        errorMessage(e),
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

    // Rider: a stored/derived validity or tax value can fall outside the
    // configured option lists (edit mode). Prepend it so the dropdown value
    // is always among the items (Formfield assert) and an untouched edit
    // saves exactly what it prefilled.
    final validityOptions =
        config.quotationValidityOptions.contains(_validityDays)
        ? config.quotationValidityOptions
        : [_validityDays, ...config.quotationValidityOptions];
    final taxOptions = config.taxPercentOptions.contains(_taxPercent)
        ? config.taxPercentOptions
        : [_taxPercent, ...config.taxPercentOptions];

    final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
    // Preview through the model so the summary matches the saved estimate.
    final draft = Quotation(
      id: '',
      quotationNumber: '',
      customerId: widget.customer.id,
      vehicleId: widget.vehicle.id,
      kmReading: 0,
      items: _items,
      overallDiscount: discount,
      taxPercent: _taxPercent,
      perItemTax: _perItemTax,
    );
    final partsSubtotal = draft.partsSubtotal;
    final labourSubtotal = draft.labourSubtotal;
    final grandTotal = draft.grandTotal;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Estimate' : 'Create Quotation / Estimate',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
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
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusBadge,
                        ),
                      ),
                      child: Icon(
                        Icons.request_quote_rounded,
                        color: palette.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customer.name,
                            style: GoogleFonts.poppins(
                              fontSize: AppText.title,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.vehicle.displayName} (${widget.vehicle.registrationNumber})',
                            style: GoogleFonts.poppins(
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

              // Items Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Estimate Line Items (${_items.length})',
                      style: GoogleFonts.poppins(
                        fontSize: AppText.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                  icon: Icons.add_shopping_cart_rounded,
                  title: 'No services or parts added yet',
                  description:
                      'Tap "+ Add Items" to pick from catalogue or add custom items',
                )
              else
                ..._items.map((item) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        item.name,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${item.quantity} ${item.unit} @ ${CurrencyFormatter.format(item.unitPrice)}',
                      ),
                      trailing: Text(
                        CurrencyFormatter.format(item.totalAmount),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: palette.primary,
                        ),
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
                      isExpanded: true,
                      initialValue: _validityDays,
                      decoration: const InputDecoration(
                        labelText: 'Quote Validity',
                      ),
                      items: validityOptions
                          .map(
                            (days) => DropdownMenuItem(
                              value: days,
                              child: Text('$days Days'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() {
                        // Only a real change marks the estimate edited —
                        // re-selecting the prefilled count must not recompute
                        // the stored validUntil date.
                        if (val != null && val != _validityDays) {
                          _validityDays = val;
                          _validityChanged = true;
                        }
                      }),
                    ),
                  ),
                  if (!_perItemTax) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      isExpanded: true,
                      initialValue: _taxPercent,
                      decoration: const InputDecoration(labelText: 'Tax Rate'),
                      items: taxOptions.map((rate) {
                        return DropdownMenuItem(
                          value: rate,
                          child: Text(
                            rate > 0
                                ? '${rate.toStringAsFixed(0)}% (CGST ${(rate / 2).toStringAsFixed(1)}% + SGST ${(rate / 2).toStringAsFixed(1)}%)'
                                : '${rate.toStringAsFixed(0)}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(
                        () => _taxPercent = val ?? config.defaultTaxPercent,
                      ),
                    ),
                  ),
                  ],
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
                  hintText:
                      'e.g. Price valid for genuine OEM parts. Labour included.',
                ),
              ),
              const SizedBox(height: 24),

              // Totals Summary Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Parts',
                      CurrencyFormatter.format(partsSubtotal),
                      palette,
                    ),
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      'Labour',
                      CurrencyFormatter.format(labourSubtotal),
                      palette,
                    ),
                    const SizedBox(height: 6),
                    if (discount > 0) ...[
                      _buildSummaryRow(
                        'Discount:',
                        '- ${CurrencyFormatter.format(discount)}',
                        palette,
                        color: palette.paid,
                      ),
                      const SizedBox(height: 6),
                    ],
                    for (final line in gstLines(draft.taxBreakdown)) ...[
                      _buildSummaryRow(
                        '${line.key}:',
                        CurrencyFormatter.format(line.value),
                        palette,
                      ),
                      const SizedBox(height: 6),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Estimated Total:',
                            style: GoogleFonts.poppins(
                              fontSize: AppText.title,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.format(grandTotal),
                            style: GoogleFonts.poppins(
                              fontSize: AppText.headline,
                              fontWeight: FontWeight.w700,
                              color: palette.primary,
                            ),
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
                  label: Text(
                    _isEditing ? 'Save Changes' : 'Save & Send Estimate',
                  ),
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

  Widget _buildSummaryRow(
    String label,
    String value,
    AppPalette palette, {
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppText.caption,
              color: palette.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: AppText.body,
            fontWeight: FontWeight.w600,
            color: color ?? palette.textPrimary,
          ),
        ),
      ],
    );
  }
}
