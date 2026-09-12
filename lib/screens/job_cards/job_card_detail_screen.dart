import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/job_card.dart';
import '../../models/maintenance_item.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/status_badge.dart';
import '../maintenance/add_maintenance_screen.dart';
import '../invoices/invoice_preview_screen.dart';
import 'create_job_card_screen.dart';

class JobCardDetailScreen extends StatefulWidget {
  final String jobCardId;

  const JobCardDetailScreen({super.key, required this.jobCardId});

  @override
  State<JobCardDetailScreen> createState() => _JobCardDetailScreenState();
}

class _JobCardDetailScreenState extends State<JobCardDetailScreen> {
  /// A delivered or cancelled job card is closed: no more edits or item
  /// changes are allowed on it.
  bool _isJobActive(JobCard jobCard) =>
      jobCard.status != JobStatus.delivered && jobCard.status != JobStatus.cancelled;

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  /// Opens the job card form in edit mode. The detail screen resolves the job
  /// card by id from the provider on every build, so the notifyListeners from
  /// the update refreshes everything shown here automatically.
  Future<void> _editJobCard(JobCard jobCard) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobCardScreen(existing: jobCard),
      ),
    );
  }

  Future<void> _removeItem(JobCard jobCard, MaintenanceItem item) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    await provider.removeItemFromJobCard(jobCard.id, item.id);
    if (!mounted) return;
    showAppSnackBar(
      context,
      'Removed "${item.name}" from this job card',
      type: SnackBarType.success,
    );
  }

  Future<void> _editWorkItems(JobCard jobCard) async {
    final updatedItems = await Navigator.push<List<MaintenanceItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          initialItems: jobCard.items,
          title: 'Edit Job Card Items',
        ),
      ),
    );

    if (updatedItems == null || !mounted) return;
    final provider = Provider.of<GarageProvider>(context, listen: false);
    // Re-fetch: the job may have changed (e.g. been closed) while the items
    // editor was open; item changes on a delivered/cancelled job are blocked.
    final fresh = provider.getJobCardById(jobCard.id);
    if (fresh == null || !_isJobActive(fresh)) {
      showAppSnackBar(
        context,
        'This job card is closed; its work items can no longer be changed',
        type: SnackBarType.info,
      );
      return;
    }
    // Upsert each picked item through the provider: new ids append, known
    // ids replace in place (this is the same flow the create form uses).
    // Wrapped so one failing item surfaces an error snack bar instead of
    // letting a repo throw escape mid-way through the batch.
    try {
      for (final item in updatedItems) {
        await provider.addOrUpdateItemInJobCard(jobCard.id, item);
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _changeStatus(JobCard jobCard, JobStatus newStatus) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    await provider.updateJobStatus(jobCard.id, newStatus);
    if (!mounted) return;
    showAppSnackBar(
      context,
      'Status changed to ${newStatus.displayName}',
      type: SnackBarType.info,
    );
  }

  Future<void> _generateInvoice(JobCard jobCard) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    if (jobCard.items.isEmpty) {
      showAppSnackBar(
        context,
        'Add at least one work item before invoicing this job card',
        type: SnackBarType.error,
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
    // Once the job is billed, its work items are locked so they can no
    // longer diverge from the amounts printed on the invoice.
    final itemsLocked = existingInvoice != null;
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(jobCard.jobCardNumber, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
            Text(
              'Created ${AppDateFormatter.formatDate(jobCard.createdAt)}',
              style: GoogleFonts.poppins(fontSize: 12, color: palette.textMuted),
            ),
          ],
        ),
        actions: [
          if (_isJobActive(jobCard))
            IconButton(
              tooltip: 'Edit job card',
              onPressed: () => _editJobCard(jobCard),
              icon: const Icon(Icons.edit_rounded),
            ),
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
                color: palette.card,
                borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                border: Border.all(
                  color: palette.border,
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
                      color: palette.textSecondary,
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
                            selectedColor: palette.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : palette.textPrimary,
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
                color: palette.card,
                borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                border: Border.all(
                  color: palette.border,
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
                          color: palette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vehicle?.fuelType.displayName ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.primary,
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
                      _buildInfoColumn('Odometer', '${jobCard.kmReading} KM'),
                      _buildInfoColumn('Fuel Level', jobCard.fuelLevel),
                      _buildInfoColumn('Mechanic', staff?.name ?? 'Unassigned'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 15, color: palette.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Promised: ${AppDateFormatter.formatDateTime(jobCard.promisedDeliveryDate)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.primary,
                        ),
                      ),
                    ],
                  ),
                  if (_hasText(jobCard.estimatedCostNote)) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.request_quote_rounded, size: 15, color: palette.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Est. cost note: ${jobCard.estimatedCostNote}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (jobCard.status == JobStatus.delivered && jobCard.completedAt != null) ...[
                    const SizedBox(height: 8),
                    // crossAxisAlignment matches the est-cost-note row above so
                    // a two-line completion timestamp aligns with its icon.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_rounded, size: 15, color: palette.paid),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Completed: ${AppDateFormatter.formatDateTime(jobCard.completedAt!)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.paid,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Complaints Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                border: Border.all(
                  color: palette.border,
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
                          Icon(Icons.check_circle_outline_rounded, size: 16, color: palette.primary),
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

            // Inspection Checklist (captured data; hidden when none recorded)
            if (jobCard.inspectionChecklist.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                  border: Border.all(
                    color: palette.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inspection Checklist '
                      '(${jobCard.inspectionChecklist.values.where((v) => v).length}/${jobCard.inspectionChecklist.length})',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ...jobCard.inspectionChecklist.entries.map((entry) {
                      final done = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: done ? palette.paid : palette.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  color: done ? palette.textPrimary : palette.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // Supervisor Notes (captured data; hidden when empty)
            if (_hasText(jobCard.supervisorNotes)) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                  border: Border.all(
                    color: palette.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supervisor Notes',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      jobCard.supervisorNotes!,
                      style: GoogleFonts.poppins(fontSize: 13.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],

            // Work Items & Spare Parts Table
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                border: Border.all(
                  color: palette.border,
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
                      // A billed job locks its items so they can no longer
                      // diverge from the invoice; the disabled button carries
                      // an explanatory tooltip.
                      Tooltip(
                        message: itemsLocked
                            ? 'Locked — billed on an invoice'
                            : 'Edit the work items on this job card',
                        child: TextButton.icon(
                          onPressed: itemsLocked || !_isJobActive(jobCard)
                              ? null
                              : () => _editWorkItems(jobCard),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Add / Edit Items'),
                        ),
                      ),
                    ],
                  ),
                  if (jobCard.items.isEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'No maintenance items added yet. Tap "Add / Edit Items" to add parts & labour.',
                        style: GoogleFonts.poppins(color: palette.textMuted, fontSize: 13),
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
                                    '${item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.unitPrice)}',
                                    style: GoogleFonts.poppins(fontSize: 12, color: palette.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(item.totalAmount),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            if (_isJobActive(jobCard)) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: itemsLocked ? 'Locked — billed on an invoice' : 'Remove item',
                                onPressed: itemsLocked ? null : () => _removeItem(jobCard, item),
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: itemsLocked ? palette.textMuted : palette.pending,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('Parts Subtotal:', style: GoogleFonts.poppins(fontSize: 13, color: palette.textSecondary))),
                        const SizedBox(width: 8),
                        Text(CurrencyFormatter.format(jobCard.partsTotal), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('Labour Subtotal:', style: GoogleFonts.poppins(fontSize: 13, color: palette.textSecondary))),
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
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: palette.primary),
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
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
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
                    backgroundColor: palette.paid,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: palette.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}
