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
import '../../utils/quantity_formatter.dart';
import '../../utils/date_formatter.dart';
import '../maintenance/add_maintenance_screen.dart';
import '../invoices/invoice_preview_screen.dart';
import 'create_job_card_screen.dart';
import '../../theme/app_text.dart';
import '../../utils/error_message.dart';
import '../../utils/permissions.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/permission_gate.dart';
import '../../utils/grouped_number.dart';
import '../../l10n/app_language.dart';

class JobCardDetailScreen extends StatefulWidget {
  final String jobCardId;

  const JobCardDetailScreen({super.key, required this.jobCardId});

  @override
  State<JobCardDetailScreen> createState() => _JobCardDetailScreenState();
}

class _JobCardDetailScreenState extends State<JobCardDetailScreen> {
  /// Double-submit latch: a second tap while the bill is being created must
  /// not open (or create) a second invoice.
  bool _isGeneratingInvoice = false;

  /// A delivered or cancelled job card is closed: no more edits or item
  /// changes are allowed on it.
  bool _isJobActive(JobCard jobCard) =>
      jobCard.status != JobStatus.delivered && jobCard.status != JobStatus.cancelled;

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  /// Opens the job card form in edit mode. The detail screen resolves the job
  /// card by id from the provider on every build, so the notifyListeners from
  /// the update refreshes everything shown here automatically. A billed job
  /// card passes [itemsLocked] so the editor keeps its items read-only too.
  Future<void> _editJobCard(JobCard jobCard, {required bool itemsLocked}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobCardScreen(
          existing: jobCard,
          itemsLocked: itemsLocked,
        ),
      ),
    );
  }

  Future<void> _removeItem(JobCard jobCard, MaintenanceItem item) async {
    // Destructive: name the line being dropped before it disappears from the
    // totals. Destructive, so the confirm button is red.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          title: Text(tr('Remove Item?')),
          content: Text(
              'Remove "${item.name}" from this job card? Its amount will be dropped from the totals.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.absent,
                foregroundColor: palette.onPrimary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Remove')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final provider = Provider.of<GarageProvider>(context, listen: false);
    try {
      await provider.removeItemFromJobCard(jobCard.id, item.id);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Removed "${item.name}" from this job card',
        type: SnackBarType.success,
      );
    } catch (e) {
      // API-path failures (network, 402, lock) must surface as feedback, not
      // as an unhandled async error that leaves the row seemingly removed.
      if (!mounted) return;
      showAppSnackBar(
        context,
        errorMessage(e),
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _editWorkItems(JobCard jobCard) async {
    final updatedItems = await Navigator.push<List<MaintenanceItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          initialItems: jobCard.items,
          title: tr('Edit Job Card Items'),
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
        tr('This job card is closed; its work items can no longer be changed'),
        type: SnackBarType.info,
      );
      return;
    }
    // Upsert each picked item through the provider: new ids append, known
    // ids replace in place (this is the same flow the create form uses).
    // Each item is guarded individually so one failing item surfaces an
    // error snack bar without aborting the rest of the batch.
    for (final item in updatedItems) {
      try {
        await provider.addOrUpdateItemInJobCard(jobCard.id, item);
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          errorMessage(e),
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _changeStatus(JobCard jobCard, JobStatus newStatus) async {
    final provider = Provider.of<GarageProvider>(context, listen: false);
    try {
      await provider.updateJobStatus(jobCard.id, newStatus);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Status changed to ${newStatus.displayName}',
        type: SnackBarType.info,
      );
    } catch (e) {
      // API-path failures must surface as feedback, not as an unhandled
      // async exception that leaves the status silently unchanged.
      if (!mounted) return;
      showAppSnackBar(
        context,
        errorMessage(e),
        type: SnackBarType.error,
      );
    }
  }

  /// The main path a job moves along. Waiting Parts is a pause inside
  /// "In progress", and Cancelled is an exit, so neither is a step here.
  static const _stages = [
    JobStatus.received,
    JobStatus.inspection,
    JobStatus.inProgress,
    JobStatus.readyForDelivery,
    JobStatus.delivered,
  ];

  /// The single forward action for the current status, or null when the
  /// job is closed.
  (String, JobStatus)? _nextStep(JobStatus status) => switch (status) {
        JobStatus.received => (tr('Start inspection'), JobStatus.inspection),
        JobStatus.inspection => (tr('Start work'), JobStatus.inProgress),
        JobStatus.inProgress => (tr('Mark ready'), JobStatus.readyForDelivery),
        JobStatus.waitingParts => (tr('Parts arrived — resume work'), JobStatus.inProgress),
        JobStatus.readyForDelivery => (tr('Mark delivered'), JobStatus.delivered),
        JobStatus.delivered || JobStatus.cancelled => null,
      };

  Future<void> _pickStatus(JobCard jobCard) async {
    final picked = await showModalBottomSheet<JobStatus>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final status in JobStatus.values)
                ListTile(
                  title: Text(status.displayName),
                  leading: Icon(
                    status == jobCard.status
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: status == JobStatus.cancelled
                        ? ctx.palette.absent
                        : null,
                  ),
                  onTap: () => Navigator.pop(ctx, status),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != jobCard.status && mounted) {
      await _changeStatus(jobCard, picked);
    }
  }

  Widget _buildStatusCard(JobCard jobCard, AppPalette palette) {
    final status = jobCard.status;
    final cancelled = status == JobStatus.cancelled;
    // Waiting Parts shows as the "In progress" step, flagged below.
    final stageIndex = _stages.indexOf(
        status == JobStatus.waitingParts ? JobStatus.inProgress : status);
    final next = _nextStep(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusTile),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  status.displayName,
                  style: GoogleFonts.poppins(
                    fontSize: AppText.subtitle,
                    fontWeight: FontWeight.w700,
                    color: cancelled ? palette.absent : palette.textPrimary,
                  ),
                ),
              ),
              // Write action — hidden from staff without jobcards.manage.
              PermissionGate(
                permission: Permissions.jobcardsManage,
                child: TextButton(
                  onPressed: () => _pickStatus(jobCard),
                  child: Text(tr('Change status')),
                ),
              ),
            ],
          ),
          if (!cancelled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < _stages.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        // Progress through the stages is informational —
                        // near-black, not brand red (§2).
                        color: i <= stageIndex ? palette.accent : palette.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              status == JobStatus.waitingParts
                  ? 'Step ${stageIndex + 1} of ${_stages.length} · paused, waiting for parts'
                  : 'Step ${stageIndex + 1} of ${_stages.length}',
              style: GoogleFonts.poppins(
                fontSize: AppText.label,
                color: status == JobStatus.waitingParts
                    ? palette.pending
                    : palette.textMuted,
              ),
            ),
          ],
          if (next != null) ...[
            const SizedBox(height: 12),
            // Write action — hidden from staff without jobcards.manage.
            PermissionGate(
              permission: Permissions.jobcardsManage,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _changeStatus(jobCard, next.$2),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(next.$1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generateInvoice(JobCard jobCard) async {
    if (_isGeneratingInvoice) return;
    if (!ensurePermission(context, Permissions.invoicesManage)) return;
    final provider = Provider.of<GarageProvider>(context, listen: false);
    if (jobCard.items.isEmpty) {
      showAppSnackBar(
        context,
        tr('Add at least one work item before invoicing this job card'),
        type: SnackBarType.error,
      );
      return;
    }
    setState(() => _isGeneratingInvoice = true);
    final existingInvoice = provider.invoices.where((inv) => inv.jobCardId == jobCard.id).firstOrNull;
    try {
      final invoice = existingInvoice ?? await provider.createInvoiceFromJobCard(jobCard);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePreviewScreen(invoiceId: invoice.id),
        ),
      );
    } catch (e) {
      // Invoicing can fail on the API path (network, duplicate guard, etc.);
      // keep the user on this screen with an error instead of crashing.
      if (!mounted) return;
      showAppSnackBar(
        context,
        errorMessage(e),
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isGeneratingInvoice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final jobCard = provider.getJobCardById(widget.jobCardId);

    if (jobCard == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Job Card Details'))),
        body: EmptyStateWidget(
          icon: Icons.assignment_outlined,
          title: tr('Job card not found'),
          description: tr('This job card may have been removed.'),
          buttonText: tr('Go back'),
          onButtonPressed: () => Navigator.of(context).maybePop(),
        ),
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
            Text(jobCard.jobCardNumber, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: AppText.title)),
            Text(
              'Created ${AppDateFormatter.formatDate(jobCard.createdAt)}',
              style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted),
            ),
          ],
        ),
        actions: [
          if (_isJobActive(jobCard))
            PermissionGate(
              permission: Permissions.jobcardsManage,
              child: IconButton(
                tooltip: tr('Edit job card'),
                // Same lock as the list-level item controls: once the job is
                // billed, the editor must not be able to rewrite its items.
                onPressed: () => _editJobCard(
                  jobCard,
                  itemsLocked: existingInvoice != null,
                ),
                icon: const Icon(Icons.edit_rounded),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      // The bill action stays pinned at the bottom so it's reachable without
      // scrolling past the items and inspection.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: existingInvoice != null
              ? SizedBox(
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
                  label: Text('View Bill #${existingInvoice.invoiceNumber}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                  ),
                ),
              )
              : // Creating a bill is a write action — hidden from staff without
              // invoices.manage (and re-checked in _generateInvoice).
              PermissionGate(
                permission: Permissions.invoicesManage,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isGeneratingInvoice ? null : () => _generateInvoice(jobCard),
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: Text(tr('Create Bill')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                    ),
                  ),
                ),
              ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status: progress through the main stages plus one clear "next"
            // action; every other status (waiting parts, cancel, going back)
            // sits behind "Change status".
            _buildStatusCard(jobCard, palette),
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
                      Expanded(
                        child: Text(
                          vehicle?.registrationNumber ?? tr('Vehicle'),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: palette.cardAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vehicle?.fuelType.displayName ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: AppText.label,
                            fontWeight: FontWeight.w600,
                            // Informational chip — muted, not brand red (§2).
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${vehicle?.displayName ?? ""} • ${customer?.name ?? ""}',
                    style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: _buildInfoColumn(tr('Odometer'), '${groupDigits(jobCard.kmReading)} km')),
                      const SizedBox(width: 8),
                      Flexible(child: _buildInfoColumn(tr('Fuel Level'), jobCard.fuelLevel)),
                      const SizedBox(width: 8),
                      Flexible(child: _buildInfoColumn(tr('Mechanic'), staff?.name ?? tr('Unassigned'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Red only when the promise is broken, amber when it is
                  // under two hours away; otherwise neutral, so red keeps
                  // meaning "act now".
                  Builder(builder: (context) {
                    final open = jobCard.status != JobStatus.delivered &&
                        jobCard.status != JobStatus.cancelled;
                    final left =
                        jobCard.promisedDeliveryDate.difference(DateTime.now());
                    final late = open && left.isNegative;
                    final soon = open && !late && left.inMinutes < 120;
                    final color = late
                        ? palette.absent
                        : soon
                            ? palette.pending
                            : palette.textSecondary;
                    return Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 15, color: color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${late ? tr('Late — promised') : tr('Promised')}: ${AppDateFormatter.formatDateTime(jobCard.promisedDeliveryDate)}',
                            style: GoogleFonts.poppins(
                              fontSize: AppText.caption,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
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
                              fontSize: AppText.caption,
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
                              fontSize: AppText.caption,
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
                    tr('Complaints'),
                    style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ...jobCard.customerComplaints.map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.circle, size: 6, color: palette.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c,
                              style: GoogleFonts.poppins(fontSize: AppText.body),
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
                clipBehavior: Clip.antiAlias,
                // Background lives on the tile (not the box) so its ink
                // ripple stays visible.
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                  border: Border.all(color: palette.border),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    backgroundColor: palette.card,
                    collapsedBackgroundColor: palette.card,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    title: Text(tr('Inspection'),
                        style: GoogleFonts.poppins(fontSize: AppText.body, fontWeight: FontWeight.w600)),
                    trailing: Text(
                      '${jobCard.inspectionChecklist.values.where((v) => v).length} of '
                      '${jobCard.inspectionChecklist.length} checked',
                      style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textSecondary),
                    ),
                    children: [
                      for (final entry in jobCard.inspectionChecklist.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                entry.value ? Icons.check_rounded : Icons.remove_rounded,
                                size: 16,
                                color: entry.value ? palette.paid : palette.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(entry.key,
                                    style: GoogleFonts.poppins(
                                        fontSize: AppText.caption,
                                        color: entry.value ? palette.textPrimary : palette.textMuted)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
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
                      tr('Notes'),
                      style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      jobCard.supervisorNotes!,
                      style: GoogleFonts.poppins(fontSize: AppText.body, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],

            // Work Items & Spare Parts Table
            const SizedBox(height: 16),
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
                      Expanded(
                        child: Text(
                          tr('Parts & labour'),
                          style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
                        ),
                      ),
                      // A billed job locks its items so they can no longer
                      // diverge from the invoice; the disabled button carries
                      // an explanatory tooltip. Write action — gated.
                      PermissionGate(
                        permission: Permissions.jobcardsManage,
                        child: Tooltip(
                          message: itemsLocked
                              ? tr('Locked — already billed')
                              : tr('Edit the work items on this job card'),
                          child: TextButton.icon(
                            onPressed: itemsLocked || !_isJobActive(jobCard)
                                ? null
                                : () => _editWorkItems(jobCard),
                            icon: const Icon(Icons.edit_note_rounded, size: 18),
                            label: Text(tr('Edit items')),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (jobCard.items.isEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        tr('No parts or labour yet. Tap Edit items to add them.'),
                        style: GoogleFonts.poppins(color: palette.textMuted, fontSize: AppText.caption),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    const Divider(),
                    ...jobCard.items.map((item) {
                      final row = Padding(
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
                                    style: GoogleFonts.poppins(fontSize: AppText.body, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    [
                                      '${formatQuantity(item.quantity)} ${item.unit} x ${CurrencyFormatter.format(item.unitPrice)}',
                                      ?item.discountLabel,
                                    ].join(' • '),
                                    style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(item.totalAmount),
                              style: GoogleFonts.poppins(
                                fontSize: AppText.body,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                      // Swipe left to remove (with confirmation), instead of
                      // a delete icon on every line. Billed jobs are locked.
                      if (!_isJobActive(jobCard) || itemsLocked) return row;
                      return Dismissible(
                        key: ValueKey('item-${item.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _removeItem(jobCard, item);
                          // The provider rebuilds the list once it's gone.
                          return false;
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: palette.absent,
                          child: Icon(Icons.delete_outline_rounded, color: palette.onPrimary),
                        ),
                        child: row,
                      );
                    }),
                    if (_isJobActive(jobCard) && !itemsLocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(tr('Swipe an item left to remove it'),
                            style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted)),
                      ),
                    const Divider(),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(tr('Parts'), style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textSecondary))),
                        const SizedBox(width: 8),
                        Text(CurrencyFormatter.format(jobCard.partsTotal), style: GoogleFonts.poppins(fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(tr('Labour'), style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textSecondary))),
                        const SizedBox(width: 8),
                        Text(CurrencyFormatter.format(jobCard.labourTotal), style: GoogleFonts.poppins(fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(tr('Total'), style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(jobCard.grandTotal),
                          style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700, color: palette.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
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
            fontSize: AppText.label,
            color: palette.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: AppText.body,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}
