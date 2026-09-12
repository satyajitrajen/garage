import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehicle ${newVehicle.registrationNumber} added!'),
          backgroundColor: AppColors.paid,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehicle ${updated.registrationNumber} updated!'),
          backgroundColor: AppColors.paid,
        ),
      );
    }
  }

  void _confirmDeleteCustomer(BuildContext context, GarageProvider provider, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('Are you sure you want to delete ${customer.name}? This will also remove their registered fleet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pending),
            onPressed: () async {
              Navigator.pop(ctx);
              final deleted = await provider.deleteCustomer(customer.id);
              if (!context.mounted) return;
              if (!deleted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cannot delete ${customer.name} — customer still has outstanding dues'),
                    backgroundColor: AppColors.pending,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Customer ${customer.name} deleted'),
                  backgroundColor: AppColors.pending,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteVehicle(BuildContext context, GarageProvider provider, Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vehicle?'),
        content: Text('Are you sure you want to remove ${vehicle.registrationNumber} from fleet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pending),
            onPressed: () async {
              await provider.deleteVehicle(vehicle.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Vehicle ${vehicle.registrationNumber} deleted'),
                  backgroundColor: AppColors.pending,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.pending),
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
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        customer.name.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
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
                            style: GoogleFonts.poppins(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            customer.phone,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            ),
                          ),
                          if (customer.email != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              customer.email!,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
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
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Simulating call to ${customer.phone}...')),
                            );
                          },
                          icon: const Icon(Icons.phone_rounded, color: AppColors.accent, size: 20),
                          tooltip: 'Call Customer',
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Opening WhatsApp to ${customer.effectiveWhatsApp}...')),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_rounded, color: AppColors.paid, size: 20),
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
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customer.address!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
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
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'GSTIN: ${customer.gstin!.trim()}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                if (customer.notes?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note_alt_outlined, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customer.notes!.trim(),
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
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
                      color: AppColors.pending.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.pending.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.pending, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Outstanding Balance Dues:',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.pending,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.format(outstandingDues),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pending,
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
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
            indicatorColor: AppColors.primary,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
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
                _buildVehiclesTab(vehicles, isDark),

                // TAB 2: JOB CARDS
                _buildJobCardsTab(customerJobCards, isDark),

                // TAB 3: INVOICES
                _buildInvoicesTab(customerInvoices, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesTab(List<Vehicle> vehicles, bool isDark) {
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
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
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
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          v.fuelType.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    v.displayName,
                    style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${v.currentKm} KM',
                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      if (v.year != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${v.year} Model',
                          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
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
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.pending),
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
                          backgroundColor: AppColors.primary,
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

  Widget _buildJobCardsTab(List jobCards, bool isDark) {
    if (jobCards.isEmpty) {
      return Center(
        child: Text('No job cards recorded yet', style: GoogleFonts.poppins(color: AppColors.textMuted)),
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
              style: GoogleFonts.poppins(fontSize: 12.5),
            ),
            trailing: StatusBadge.fromJobStatus(jc.status),
          ),
        );
      },
    );
  }

  Widget _buildInvoicesTab(List invoices, bool isDark) {
    if (invoices.isEmpty) {
      return Center(
        child: Text('No invoices recorded yet', style: GoogleFonts.poppins(color: AppColors.textMuted)),
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
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            trailing: StatusBadge.fromInvoiceStatus(inv.status),
          ),
        );
      },
    );
  }
}
