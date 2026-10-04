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
import '../job_cards/job_card_detail_screen.dart';
import '../job_cards/create_job_card_screen.dart';
import '../invoices/invoice_preview_screen.dart';
import '../../theme/app_text.dart';

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
        title: const Text('Customer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit customer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCustomerScreen(customerToEdit: customer),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'delete') _confirmDeleteCustomer(context, provider, customer);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete customer', style: TextStyle(color: palette.absent)),
              ),
            ],
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
                Text(
                  customer.name,
                  style: GoogleFonts.poppins(
                    fontSize: AppText.headline,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [customer.phone, if (customer.email != null) customer.email!].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ContactActions.call(context, customer.phone),
                        icon: const Icon(Icons.phone_outlined, size: 18),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
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
                        icon: const Icon(Icons.chat_outlined, size: 18),
                        label: const Text('WhatsApp'),
                      ),
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
                          style: GoogleFonts.poppins(
                            fontSize: AppText.caption,
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
                      style: GoogleFonts.poppins(
                        fontSize: AppText.label,
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
                          style: GoogleFonts.poppins(
                            fontSize: AppText.caption,
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
                              'Balance due',
                              style: GoogleFonts.poppins(
                                fontSize: AppText.body,
                                fontWeight: FontWeight.w600,
                                color: palette.pending,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.format(outstandingDues),
                          style: GoogleFonts.poppins(
                            fontSize: AppText.title,
                            fontWeight: FontWeight.w700,
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
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: AppText.body),
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
            Expanded(
              child: Text(
                'Vehicles',
                style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700),
              ),
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
                      Expanded(
                        child: Text(
                          v.registrationNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: AppText.title,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          v.fuelType.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: AppText.label,
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
                    style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    children: [
                      Text(
                        '${v.currentKm} km',
                        style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textSecondary),
                      ),
                      if (v.year != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${v.year} model',
                          style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
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
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New job card'),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Vehicle options',
                        onSelected: (choice) {
                          if (choice == 'edit') _editVehicle(v);
                          if (choice == 'delete') _confirmDeleteVehicle(context, provider, v);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit vehicle')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete vehicle', style: TextStyle(color: palette.absent)),
                          ),
                        ],
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
        child: Text('No job cards recorded yet', style: GoogleFonts.poppins(color: palette.textMuted)),
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
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              AppDateFormatter.formatDate(jc.createdAt),
              style: GoogleFonts.poppins(fontSize: AppText.caption),
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
        child: Text('No invoices recorded yet', style: GoogleFonts.poppins(color: palette.textMuted)),
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
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${CurrencyFormatter.format(inv.grandTotal)} • ${AppDateFormatter.formatDate(inv.invoiceDate)}',
              style: GoogleFonts.poppins(fontSize: AppText.caption),
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
                      style: GoogleFonts.poppins(
                        fontSize: AppText.micro,
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
