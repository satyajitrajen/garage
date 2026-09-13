import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../models/maintenance_item.dart';
import '../../models/invoice.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../customers/add_customer_screen.dart';
import '../vehicles/add_vehicle_dialog.dart';
import '../maintenance/add_maintenance_screen.dart';
import '../invoices/invoice_preview_screen.dart';
import '../payments/payment_collection_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gradient_button.dart';

class QuickServiceWizard extends StatefulWidget {
  const QuickServiceWizard({super.key});

  @override
  State<QuickServiceWizard> createState() => _QuickServiceWizardState();
}

class _QuickServiceWizardState extends State<QuickServiceWizard> {
  int _currentStep = 0;

  Customer? _selectedCustomer;
  Vehicle? _selectedVehicle;
  final List<MaintenanceItem> _selectedItems = [];
  final _kmController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Invoice? _generatedInvoice;
  bool _isGeneratingBill = false;

  @override
  void dispose() {
    _kmController.dispose();
    _discountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onCustomerSelected(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _selectedVehicle = null;
      _currentStep = 1;
    });
  }

  void _onVehicleSelected(Vehicle vehicle) {
    setState(() {
      _selectedVehicle = vehicle;
      _kmController.text = vehicle.currentKm.toString();
      _currentStep = 2;
    });
  }

  void _openAddItems() async {
    final items = await Navigator.push<List<MaintenanceItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          initialItems: _selectedItems,
          title: 'Select Work Items for Bill',
        ),
      ),
    );

    if (!mounted) return;
    if (items != null) {
      setState(() {
        _selectedItems.clear();
        _selectedItems.addAll(items);
      });
    }
  }

  Future<void> _generateFinalBill() async {
    // Latch: prevent a double-tap from creating two invoices across the
    // async gap before _generatedInvoice is set.
    if (_isGeneratingBill) return;
    _isGeneratingBill = true;
    try {
      // Guard: never generate a second invoice for the same service.
      if (_generatedInvoice != null) {
        setState(() => _currentStep = 3);
        return;
      }

      if (_selectedItems.isEmpty) {
        showAppSnackBar(
          context,
          'Please add at least one work item or spare part',
          type: SnackBarType.info,
        );
        return;
      }

      final provider = Provider.of<GarageProvider>(context, listen: false);
      final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
      if (discount < 0) {
        showAppSnackBar(context, 'Discount cannot be negative', type: SnackBarType.info);
        return;
      }
      final gross = _selectedItems.fold(0.0, (sum, i) => sum + i.totalAmount);
      if (discount > gross) {
        showAppSnackBar(
          context,
          'Discount cannot exceed subtotal of ${CurrencyFormatter.format(gross)}',
          type: SnackBarType.info,
        );
        return;
      }

      // Full counter flow in one call: opens the walk-in job card, bills it
      // (tax stays config-driven inside the provider) and auto-delivers the
      // job. Payment, if any, is recorded afterwards from the success step.
      final invoice = await provider.quickServiceCheckout(
        customerId: _selectedCustomer!.id,
        vehicleId: _selectedVehicle!.id,
        kmReading: int.tryParse(_kmController.text.trim()) ?? _selectedVehicle!.currentKm,
        items: List.of(_selectedItems),
        discount: discount,
      );
      if (!mounted) return;

      setState(() {
        _generatedInvoice = invoice;
        _currentStep = 3;
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    } finally {
      _isGeneratingBill = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);

    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 0) {
          setState(() => _currentStep--);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text('Quick Service Flow', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            // Step Progress Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: context.palette.cardAlt,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStepIndicator(0, 'Customer', Icons.person_rounded),
                _buildStepLine(0),
                _buildStepIndicator(1, 'Vehicle', Icons.directions_car_rounded),
                _buildStepLine(1),
                _buildStepIndicator(2, 'Items', Icons.build_rounded),
                _buildStepLine(2),
                _buildStepIndicator(3, 'Bill / Pay', Icons.payments_rounded),
              ],
            ),
          ),

          // Step Body
          Expanded(
            child: _buildCurrentStepView(provider),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildStepIndicator(int stepIndex, String title, IconData icon) {
    final palette = context.palette;
    final isActive = _currentStep >= stepIndex;
    final isCurrent = _currentStep == stepIndex;

    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          // Filled with a palette slot in both states, so the foreground
          // follows onPrimary (white in light, dark navy in dark mode).
          backgroundColor: isActive ? palette.primary : palette.textMuted,
          child: Icon(
            isCurrent ? icon : (isActive ? Icons.check_rounded : icon),
            size: 16,
            color: palette.onPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? palette.primary : palette.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int stepIndex) {
    final isActive = _currentStep > stepIndex;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        color: isActive ? context.palette.primary : context.palette.textMuted,
      ),
    );
  }

  Widget _buildCurrentStepView(GarageProvider provider) {
    switch (_currentStep) {
      case 0:
        return _buildSelectCustomerStep(provider);
      case 1:
        return _buildSelectVehicleStep(provider);
      case 2:
        return _buildAddItemsStep(provider);
      case 3:
        return _buildBillAndPayStep(provider);
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: SELECT OR ADD CUSTOMER
  Widget _buildSelectCustomerStep(GarageProvider provider) {
    final palette = context.palette;
    final filteredCustomers = provider.customers.where((c) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final nameMatches = c.name.toLowerCase().contains(query);
      final phoneMatches = c.phone.toLowerCase().contains(query);
      return nameMatches || phoneMatches;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step 1: Choose Customer',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final newCust = await Navigator.push<Customer>(
                    context,
                    MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                  );
                  if (!mounted) return;
                  if (newCust != null) _onCustomerSelected(newCust);
                },
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add New'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search customer by name or phone...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: filteredCustomers.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.person_search_rounded,
                  title: 'No matching customers found',
                  description: 'Try searching a different name or phone number',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredCustomers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final c = filteredCustomers[index];
                    final vehicles = provider.getVehiclesForCustomer(c.id);

                    return Card(
                      child: ListTile(
                        onTap: () => _onCustomerSelected(c),
                        leading: CircleAvatar(
                          backgroundColor: palette.primary.withValues(alpha: 0.12),
                          child: Text(c.name.substring(0, 1).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: palette.primary)),
                        ),
                        title: Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        subtitle: Text('${c.phone} • ${vehicles.length} Vehicles'),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: palette.textMuted),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // STEP 2: SELECT OR ADD VEHICLE
  Widget _buildSelectVehicleStep(GarageProvider provider) {
    final palette = context.palette;
    final vehicles = provider.getVehiclesForCustomer(_selectedCustomer!.id);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step 2: Choose Vehicle', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
                  Text('For ${_selectedCustomer!.name}', style: GoogleFonts.inter(fontSize: 13, color: palette.primary, fontWeight: FontWeight.w600)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final newV = await showDialog<Vehicle>(
                    context: context,
                    builder: (_) => AddVehicleDialog(customerId: _selectedCustomer!.id),
                  );
                  if (!mounted) return;
                  if (newV != null) _onVehicleSelected(newV);
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Vehicle'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: vehicles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final v = vehicles[index];
              return Card(
                child: ListTile(
                  onTap: () => _onVehicleSelected(v),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: palette.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.directions_car_rounded, color: palette.primary),
                  ),
                  title: Text(v.registrationNumber, style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  subtitle: Text('${v.displayName} • ${v.currentKm} KM • ${v.fuelType.displayName}'),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: palette.textMuted),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // STEP 3: ADD ITEMS & PARTS
  Widget _buildAddItemsStep(GarageProvider provider) {
    final palette = context.palette;
    final subtotal = _selectedItems.fold(0.0, (sum, i) => sum + i.totalAmount);
    final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final taxable = (subtotal - discount).clamp(0.0, double.infinity);
    final taxRate = provider.config.defaultTaxPercent / 100;
    final tax = taxable * taxRate;
    final netGrandTotal = taxable + tax;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step 3: Work Items', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
                  Text('${_selectedVehicle!.registrationNumber} (${_selectedVehicle!.displayName})', style: GoogleFonts.inter(fontSize: 13, color: palette.primary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _openAddItems,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Items'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // KM and Discount fields
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _kmController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Odometer (KM)',
                      prefixIcon: Icon(Icons.speed_rounded, size: 18),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Discount (₹)',
                      prefixIcon: Icon(Icons.discount_rounded, size: 18),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _selectedItems.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.build_circle_outlined,
                    title: 'No items added yet',
                    description: 'Tap "Add Items" to choose oil, filters, labour, etc.',
                  )
                : ListView.separated(
                    itemCount: _selectedItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _selectedItems[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          subtitle: Text('${item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.unitPrice)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(CurrencyFormatter.format(item.totalAmount), style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.primary)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 18, color: palette.pending),
                                onPressed: () => setState(() => _selectedItems.removeAt(index)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal: ${CurrencyFormatter.format(subtotal)}', style: GoogleFonts.inter(fontSize: 12, color: palette.textMuted)),
                      if (discount > 0)
                        Text('Discount: -${CurrencyFormatter.format(discount)}', style: GoogleFonts.inter(fontSize: 12, color: palette.paid, fontWeight: FontWeight.w600)),
                      Text('Tax (${provider.config.defaultTaxPercent.toStringAsFixed(0)}%): ${CurrencyFormatter.format(tax)}', style: GoogleFonts.inter(fontSize: 12, color: palette.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net Bill Total:', style: GoogleFonts.inter(fontSize: 12.5, color: palette.textMuted)),
                          Text(CurrencyFormatter.format(netGrandTotal), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: palette.primary)),
                        ],
                      ),
                      GradientButton(
                        onPressed: _generateFinalBill,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('Generate Bill'),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 4: BILL PREVIEW & PAYMENT TRIGGER
  Widget _buildBillAndPayStep(GarageProvider provider) {
    final palette = context.palette;
    if (_generatedInvoice == null) return const SizedBox.shrink();

    final inv = provider.getInvoiceById(_generatedInvoice!.id) ?? _generatedInvoice!;
    final job = inv.jobCardId == null ? null : provider.getJobCardById(inv.jobCardId!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.paid.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: palette.paid, size: 64),
          ),
          const SizedBox(height: 16),
          Text(
            'Job Card & Bill Generated!',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Invoice #${inv.invoiceNumber}',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: palette.primary),
          ),
          if (job != null) ...[
            const SizedBox(height: 6),
            Text(
              'Job Card #${job.jobCardNumber} • Marked Delivered',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: palette.paid),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Total Amount: ${CurrencyFormatter.format(inv.grandTotal)} • Pending Due: ${CurrencyFormatter.format(inv.balanceDue)}',
            style: GoogleFonts.inter(fontSize: 14, color: palette.textSecondary),
          ),
          const SizedBox(height: 28),

          if (inv.balanceDue > 0) ...[
            GradientButton(
              width: double.infinity,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentCollectionScreen(invoice: inv),
                  ),
                );
              },
              icon: const Icon(Icons.payments_rounded),
              label: Text('Record Payment (${CurrencyFormatter.format(inv.balanceDue)})'),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoiceId: inv.id)),
                );
              },
              icon: const Icon(Icons.receipt_rounded),
              label: const Text('View Tax Invoice Preview'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }
}
