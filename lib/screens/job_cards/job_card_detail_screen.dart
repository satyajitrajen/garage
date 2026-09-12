import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/job_card.dart';
import '../../models/maintenance_item.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/status_badge.dart';
import '../maintenance/add_maintenance_screen.dart';
import '../invoices/invoice_preview_screen.dart';

class JobCardDetailScreen extends StatefulWidget {
  final String jobCardId;

  const JobCardDetailScreen({super.key, required this.jobCardId});

  @override
  State<JobCardDetailScreen> createState() => _JobCardDetailScreenState();
}

class _JobCardDetailScreenState extends State<JobCardDetailScreen> {
  void _editWorkItems(JobCard jobCard) async {
    final updatedItems = await Navigator.push<List<MaintenanceItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          initialItems: jobCard.items,
          title: 'Edit Job Card Items',
        ),
      ),
    );

    if (updatedItems != null && mounted) {
      final provider = Provider.of<GarageProvider>(context, listen: false);
      // Re-fetch: the job card may have changed (e.g. status updated) while
      // the items editor was open; copying onto a stale snapshot would
      // silently revert those changes.
      final fresh = provider.getJobCardById(jobCard.id) ?? jobCard;
      await provider.updateJobCard(fresh.copyWith(items: updatedItems));
    }
  }

  Future<void> _changeStatus(JobCard jobCard, JobStatus newStatus) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    await provider.updateJobStatus(jobCard.id, newStatus);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status changed to ${newStatus.displayName}'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _generateInvoice(JobCard jobCard) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    if (jobCard.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one work item before invoicing this job card')),
      );
      return;
    }
    final existingInvoice = provider.invoices.where((inv) => inv.jobCardId == jobCard.id).firstOrNull;
    final invoice = existingInvoice ?? await provider.createInvoiceFromJobCard(jobCard);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePreviewScreen(invoiceId: invoice.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final jobCard = provider.getJobCardById(widget.jobCardId);

    if (jobCard == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Card Details')),
        body: const Center(child: Text('Job card not found')),
      );
    }

    final customer = provider.getCustomerById(jobCard.customerId);
    final vehicle = provider.getVehicleById(jobCard.vehicleId);
    final staff = jobCard.assignedStaffId != null
        ? provider.getStaffById(jobCard.assignedStaffId!)
        : null;

    final existingInvoice = provider.invoices.where((inv) => inv.jobCardId == jobCard.id).firstOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(jobCard.jobCardNumber, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
            Text(
              'Created ${AppDateFormatter.formatDate(jobCard.createdAt)}',
              style: GoogleFonts.poppins(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusBadge.fromJobStatus(jobCard.status),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Workflow Stepper / Selector
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Live Status',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: JobStatus.values.map((status) {
                        final isSelected = jobCard.status == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(status.shortName),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) _changeStatus(jobCard, status);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Vehicle & Customer Overview Card
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        vehicle?.registrationNumber ?? 'Vehicle',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vehicle?.fuelType.displayName ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${vehicle?.displayName ?? ""} • ${customer?.name ?? ""}',
                    style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoColumn('Odometer', '${jobCard.kmReading} KM', isDark),
                      _buildInfoColumn('Fuel Level', jobCard.fuelLevel, isDark),
                      _buildInfoColumn('Mechanic', staff?.name ?? 'Unassigned', isDark),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 15, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Promised: ${AppDateFormatter.formatDateTime(jobCard.promisedDeliveryDate)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Complaints Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reported Complaints (${jobCard.customerComplaints.length})',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ...jobCard.customerComplaints.map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c,
                              style: GoogleFonts.poppins(fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Work Items & Spare Parts Table
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Services & Parts (${jobCard.items.length})',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      TextButton.icon(
                        onPressed: () => _editWorkItems(jobCard),
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('Add / Edit Items'),
                      ),
                    ],
                  ),
                  if (jobCard.items.isEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'No maintenance items added yet. Tap "Add / Edit Items" to add parts & labour.',
                        style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    const Divider(),
                    ...jobCard.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${item.quantity} ${item.unit} x ₹${item.unitPrice}',
                                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(item.totalAmount),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('Parts Subtotal:', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary))),
                        const SizedBox(width: 8),
                        Text(CurrencyFormatter.format(jobCard.partsTotal), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('Labour Subtotal:', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary))),
                        const SizedBox(width: 8),
                        Text(CurrencyFormatter.format(jobCard.labourTotal), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('Estimated Grand Total:', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(jobCard.grandTotal),
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Primary Action: View or Convert to Invoice
            if (existingInvoice != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoicePreviewScreen(invoiceId: existingInvoice.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_rounded),
                  label: Text('View Invoice #${existingInvoice.invoiceNumber}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _generateInvoice(jobCard),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Generate Invoice & Bill Customer'),
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
    );
  }

  Widget _buildInfoColumn(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
