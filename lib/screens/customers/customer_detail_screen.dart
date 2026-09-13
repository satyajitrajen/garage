import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/job_card.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/contact_actions.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/status_badge.dart';
import 'add_customer_screen.dart';
import '../vehicles/add_vehicle_dialog.dart';
import '../vehicles/vehicle_selection_screen.dart';
import '../job_cards/job_card_detail_screen.dart';
import '../job_cards/create_job_card_screen.dart';
import '../invoices/invoice_preview_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addVehicle() async {
    final newVehicle = await showDialog<Vehicle>(
      context: context,
      builder: (_) => AddVehicleDialog(customerId: widget.customer.id),
    );

    if (newVehicle != null) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Vehicle ${newVehicle.registrationNumber} added!',
        type: SnackBarType.success,
      );
    }
  }

  void _editVehicle(Vehicle vehicle) async {
    final updated = await showDialog<Vehicle>(
      context: context,
      builder: (_) => AddVehicleDialog(
        customerId: widget.customer.id,
        vehicleToEdit: vehicle,
      ),
    );
    if (updated != null) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Vehicle ${updated.registrationNumber} updated!',
        type: SnackBarType.success,
      );
    }
  }

  void _confirmDeleteCustomer(BuildContext context, GarageProvider provider, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          title: const Text('Delete Customer?'),
          content: Text('Are you sure you want to delete ${customer.name}? This will also remove their registered fleet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.pending,
                foregroundColor: palette.onPrimary,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final deleted = await provider.deleteCustomer(customer.id);
                if (!context.mounted) return;
                if (!deleted) {
                  showAppSnackBar(
                    context,
                    'Cannot delete ${customer.name} — customer still has outstanding dues',
                    type: SnackBarType.error,
                  );
                  return;
                }
                Navigator.pop(context);
                showAppSnackBar(
                  context,
                  'Customer ${customer.name} deleted',
                  type: SnackBarType.error,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteVehicle(BuildContext context, GarageProvider provider, Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          title: const Text('Delete Vehicle?'),
          content: Text('Are you sure you want to remove ${vehicle.registrationNumber} from fleet?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.pending,
                foregroundColor: palette.onPrimary,
              ),
              onPressed: () async {
                await provider.deleteVehicle(vehicle.id);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                showAppSnackBar(
                  context,
                  'Vehicle ${vehicle.registrationNumber} deleted',
                  type: SnackBarType.error,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final customer = provider.getCustomerById(widget.customer.id) ?? widget.customer;
    final vehicles = provider.getVehiclesForCustomer(customer.id);
    final customerInvoices = provider.invoices.where((inv) => inv.customerId == customer.id).toList();
    final customerJobCards = provider.jobCards.where((jc) => jc.customerId == customer.id).toList();
    final outstandingDues = provider.getCustomerOutstandingBalance(customer.id);

    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Customer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCustomerScreen(customerToEdit: customer),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: palette.pending),
            tooltip: 'Delete Customer',
            onPressed: () => _confirmDeleteCustomer(context, provider, customer),
          ),
          IconButton(
            icon: const Icon(Icons.directions_car_filled_rounded),
            tooltip: 'New Service for Vehicle',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VehicleSelectionScreen(
                    customer: customer,
                    targetAction: VehicleTargetAction.createJobCard,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Customer Profile Card
          Container(
            padding: const EdgeInsets.all(20),
            color: palette.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: palette.primary.withValues(alpha: 0.15),
                      child: Text(
                        customer.name.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: palette.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: GoogleFonts.inter(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            customer.phone,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: palette.textSecondary,
                            ),
                          ),
                          if (customer.email != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              customer.email!,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: palette.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Quick Action Buttons (Call / WhatsApp)
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () =>
                              ContactActions.call(context, customer.phone),
                          icon: Icon(Icons.phone_rounded, color: palette.accent, size: 20),
                          tooltip: 'Call Customer',
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () {
                            ContactActions.whatsapp(
                              context,
                              customer.effectiveWhatsApp,
                              message: ContactActions.greeting(
                                customerName: customer.name,
                                garageName: provider.profile.name,
                              ),
                            );
                          },
                          icon: Icon(Icons.chat_bubble_rounded, color: palette.paid, size: 20),
                          tooltip: 'WhatsApp Message',
                        ),
                      ],
                    ),
                  ],
                ),
                if (customer.address != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: palette.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customer.address!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (customer.gstin?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'GSTIN: ${customer.gstin!.trim()}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: palette.primary,
                      ),
                    ),
                  ),
                ],
                if (customer.notes?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note_alt_outlined, size: 16, color: palette.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customer.notes!.trim(),
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Outstanding Balance Banner
                if (outstandingDues > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: palette.pending.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.pending.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: palette.pending, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Outstanding Balance Dues:',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: palette.pending,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.format(outstandingDues),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: palette.pending,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Tabs for Vehicles, Job Cards, and Invoices
          TabBar(
            controller: _tabController,
            labelColor: palette.primary,
            unselectedLabelColor: palette.textMuted,
            indicatorColor: palette.primary,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: [
              Tab(text: 'Vehicles (${vehicles.length})'),
              Tab(text: 'Job Cards (${customerJobCards.length})'),
              Tab(text: 'Invoices (${customerInvoices.length})'),
            ],
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: VEHICLES
                _buildVehiclesTab(vehicles),

                // TAB 2: JOB CARDS
                _buildJobCardsTab(customerJobCards),

                // TAB 3: INVOICES
                _buildInvoicesTab(customerInvoices),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesTab(List<Vehicle> vehicles) {
    final palette = context.palette;
    final provider = Provider.of<GarageProvider>(context);
    final customer = provider.getCustomerById(widget.customer.id) ?? widget.customer;

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Registered Fleet',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            ElevatedButton.icon(
              onPressed: _addVehicle,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Vehicle'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...vehicles.map((v) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        v.registrationNumber,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          v.fuelType.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: palette.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    v.displayName,
                    style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${v.currentKm} KM',
                        style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
                      ),
                      if (v.year != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${v.year} Model',
                          style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit Vehicle',
                            onPressed: () => _editVehicle(v),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, size: 18, color: palette.pending),
                            tooltip: 'Delete Vehicle',
                            onPressed: () => _confirmDeleteVehicle(context, provider, v),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateJobCardScreen(
                                customer: customer,
                                vehicle: v,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.build_circle_outlined, size: 16),
                        label: const Text('Start Service'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildJobCardsTab(List<JobCard> jobCards) {
    final palette = context.palette;
    if (jobCards.isEmpty) {
      return Center(
        child: Text('No job cards recorded yet', style: GoogleFonts.inter(color: palette.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
      itemCount: jobCards.length,
      itemBuilder: (context, index) {
        final jc = jobCards[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => JobCardDetailScreen(jobCardId: jc.id)),
              );
            },
            title: Text(
              jc.jobCardNumber,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              AppDateFormatter.formatDate(jc.createdAt),
              style: GoogleFonts.inter(fontSize: 12.5),
            ),
            trailing: StatusBadge.fromJobStatus(jc.status),
          ),
        );
      },
    );
  }

  Widget _buildInvoicesTab(List<Invoice> invoices) {
    final palette = context.palette;
    if (invoices.isEmpty) {
      return Center(
        child: Text('No invoices recorded yet', style: GoogleFonts.inter(color: palette.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final inv = invoices[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoiceId: inv.id)),
              );
            },
            title: Text(
              inv.invoiceNumber,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${CurrencyFormatter.format(inv.grandTotal)} • ${AppDateFormatter.formatDate(inv.invoiceDate)}',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            // Same small overdue chip as the invoices list, so a bill past
            // its due date is flagged wherever the invoice appears.
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (inv.isOverdue) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.pending,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Overdue',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                StatusBadge.fromInvoiceStatus(inv.status),
              ],
            ),
          ),
        );
      },
    );
  }
}
