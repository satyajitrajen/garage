import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../models/invoice.dart';
import '../../models/maintenance_item.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../maintenance/add_maintenance_screen.dart';
import 'invoice_preview_screen.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item or labour charge to generate bill')),
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

    await provider.addInvoice(invoice);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invoice #${invoice.invoiceNumber} created successfully!'),
        backgroundColor: AppColors.paid,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePreviewScreen(invoiceId: invoice.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        title: Text('Create Direct Tax Invoice', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 26),
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

              // Items Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill Line Items (${_items.length})',
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
                      const Icon(Icons.shopping_bag_outlined, size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      Text('No items in bill yet', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Add services, spare parts or oils to create bill', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
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
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _buildRow('Parts Total:', CurrencyFormatter.format(partsSubtotal), isDark),
                    const SizedBox(height: 4),
                    _buildRow('Labour Total:', CurrencyFormatter.format(labourSubtotal), isDark),
                    const SizedBox(height: 4),
                    if (discount > 0) ...[
                      _buildRow('Discount:', '- ${CurrencyFormatter.format(discount)}', isDark, color: AppColors.paid),
                      const SizedBox(height: 4),
                    ],
                    _buildRow('GST Taxes (${_taxPercent.toInt()}%):', CurrencyFormatter.format(taxAmount), isDark),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Net Payable Total:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(
                          CurrencyFormatter.format(grandTotal),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
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
                  onPressed: _saveInvoice,
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

  Widget _buildRow(String label, String value, bool isDark, {Color? color}) {
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
