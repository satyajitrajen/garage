import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../widgets/permission_gate.dart';
import '../../utils/permissions.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../models/maintenance_item.dart';
import '../../models/invoice.dart';
import '../../models/job_card.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/quantity_formatter.dart';
import '../customers/add_customer_screen.dart';
import '../vehicles/add_vehicle_dialog.dart';
import '../maintenance/add_maintenance_screen.dart';
import '../invoices/invoice_preview_screen.dart';
import '../payments/payment_collection_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gradient_button.dart';
import '../../theme/app_text.dart';
import '../../utils/error_message.dart';
import '../../utils/grouped_number.dart';

class QuickServiceWizard extends StatefulWidget {
  final Customer? initialCustomer;
  final Vehicle? initialVehicle;

  const QuickServiceWizard({super.key, this.initialCustomer, this.initialVehicle});

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

  /// Job card created by a bill attempt that then failed; reused on retry so
  /// the walk-in is not opened twice.
  JobCard? _pendingJobCard;

  /// Keeps the odometer/discount fields (and their focus) alive when the
  /// items step switches to its scrolling layout as the keyboard opens.
  final _itemsFieldsKey = GlobalKey();

  /// Only reuse the pending job card while the bill still matches it.
  JobCard? get _reusableJobCard {
    final jc = _pendingJobCard;
    if (jc == null ||
        jc.customerId != _selectedCustomer?.id ||
        jc.vehicleId != _selectedVehicle?.id ||
        jc.items.map((i) => i.id).join(',') !=
            _selectedItems.map((i) => i.id).join(',')) {
      return null;
    }
    return jc;
  }

  @override
  void initState() {
    super.initState();
    final customer = widget.initialCustomer;
    final vehicle = widget.initialVehicle;
    if (customer != null) _selectedCustomer = customer;
    if (vehicle != null) {
      _selectedVehicle = vehicle;
      _kmController.text = groupDigits(vehicle.currentKm);
      _currentStep = 2;
    } else if (customer != null) {
      _currentStep = 1;
    }
  }

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
      _kmController.text = groupDigits(vehicle.currentKm);
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
        kmReading: parseGroupedInt(_kmController.text) ?? _selectedVehicle!.currentKm,
        items: List.of(_selectedItems),
        discount: discount,
        existingJobCard: _reusableJobCard,
      );
      _pendingJobCard = null;
      if (!mounted) return;

      setState(() {
        _generatedInvoice = invoice;
        _currentStep = 3;
      });
    } catch (e) {
      if (e is QuickServiceBillingException) _pendingJobCard = e.jobCard;
      if (!mounted) return;
      showAppSnackBar(
        context,
        errorMessage(e),
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
          title: Text('Quick Service Flow', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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

    // Flexible + one-line label: four steps fit narrow phones and large text.
    return Flexible(
      flex: 2,
      child: Column(
      mainAxisSize: MainAxisSize.min,
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
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: AppText.label,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? palette.primary : palette.textSecondary,
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildStepLine(int stepIndex) {
    final isActive = _currentStep > stepIndex;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
              Expanded(
                child: Text(
                  'Choose customer',
                  style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final newCust = await Navigator.push<Customer>(
                    context,
                    MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                  );
                  if (!mounted) return;
                  if (newCust != null) _onCustomerSelected(newCust);
                },
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('New'),
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
                        title: Text(c.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                        subtitle: Text('${c.phone} · ${vehicles.length} ${vehicles.length == 1 ? 'vehicle' : 'vehicles'}'),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose vehicle', style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700)),
                    Text('For ${_selectedCustomer!.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final newV = await showDialog<Vehicle>(
                    context: context,
                    builder: (_) => AddVehicleDialog(customerId: _selectedCustomer!.id),
                  );
                  if (!mounted) return;
                  if (newV != null) _onVehicleSelected(newV);
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New'),
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
                  title: Text(v.registrationNumber, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
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
    final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
    // Preview through the model: lines carry their own GST rates and the
    // bill created by quickServiceCheckout uses exactly this math.
    final draft = Invoice(
      id: '',
      invoiceNumber: '',
      customerId: '',
      vehicleId: '',
      kmReading: 0,
      items: _selectedItems,
      discountAmount: discount,
      perItemTax: true,
    );
    final subtotal = draft.grossSubtotal;
    final tax = draft.totalTaxAmount;
    final netGrandTotal = draft.grandTotal;
    // Short viewport (keyboard up on a small phone): Scaffold strips the inset
    // from the body's MediaQuery, so decide from the space actually given.
    return LayoutBuilder(builder: (context, constraints) {
    final keyboardOpen = constraints.maxHeight < 380;
    // Also scroll (but keep the totals) when large text leaves too little
    // room for a pinned list.
    final scrolling = keyboardOpen ||
        constraints.maxHeight < 600 * MediaQuery.textScalerOf(context).scale(1);

    // With the keyboard up the step has ~250px on a small phone: scroll the
    // whole step (list shrink-wrapped) instead of pinning an Expanded list.
    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Work & parts', style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700)),
                    Text(
                      '${_selectedVehicle!.registrationNumber} (${_selectedVehicle!.displayName})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _openAddItems,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // KM and Discount fields
          Container(
            key: _itemsFieldsKey,
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
                    inputFormatters: const [GroupedDigitsInputFormatter()],
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

          _expandUnlessScrolling(
            scrolling,
            _selectedItems.isEmpty
                ? (scrolling
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No items added yet',
                            style: GoogleFonts.poppins(color: palette.textMuted)),
                      )
                    : const EmptyStateWidget(
                        icon: Icons.build_circle_outlined,
                        title: 'No items added yet',
                        description: 'Tap "Add Items" to choose oil, filters, labour, etc.',
                      ))
                : ListView.separated(
                    shrinkWrap: scrolling,
                    physics: scrolling ? const NeverScrollableScrollPhysics() : null,
                    itemCount: _selectedItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _selectedItems[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          subtitle: Text('${formatQuantity(item.quantity)} ${item.unit} x ${CurrencyFormatter.format(item.unitPrice)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(CurrencyFormatter.format(item.totalAmount), style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: palette.primary)),
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
          if (!keyboardOpen) ...[
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    children: [
                      Text('Subtotal: ${CurrencyFormatter.format(subtotal)}', style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted)),
                      if (discount > 0)
                        Text('Discount: -${CurrencyFormatter.format(discount)}', style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.paid, fontWeight: FontWeight.w600)),
                      Text('GST: ${CurrencyFormatter.format(tax)}', style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Net Bill Total:', style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textMuted)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(CurrencyFormatter.format(netGrandTotal), style: GoogleFonts.poppins(fontSize: AppText.headline, fontWeight: FontWeight.w700, color: palette.primary)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: GradientButton(
                          onPressed: _generateFinalBill,
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text('Generate Bill'),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ],
        ],
      );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: scrolling ? SingleChildScrollView(child: content) : content,
    );
    });
  }

  Widget _expandUnlessScrolling(bool scrolling, Widget child) =>
      scrolling ? child : Expanded(child: child);

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
            style: GoogleFonts.poppins(fontSize: AppText.headline, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Bill #${inv.invoiceNumber}',
            style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700, color: palette.primary),
          ),
          if (job != null) ...[
            const SizedBox(height: 6),
            Text(
              'Job Card #${job.jobCardNumber} • Marked Delivered',
              style: GoogleFonts.poppins(fontSize: AppText.caption, fontWeight: FontWeight.w600, color: palette.paid),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Total Amount: ${CurrencyFormatter.format(inv.grandTotal)} • Pending Due: ${CurrencyFormatter.format(inv.balanceDue)}',
            style: GoogleFonts.poppins(fontSize: AppText.body, color: palette.textSecondary),
          ),
          const SizedBox(height: 28),

          if (inv.balanceDue > 0) ...[
            GradientButton(
              width: double.infinity,
              onPressed: () {
                if (!ensurePermission(context, Permissions.paymentsRecord)) return;
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
              label: const Text('View Bill'),
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
