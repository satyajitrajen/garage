import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../models/job_card.dart';
import '../../models/maintenance_item.dart';
import '../../models/staff.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../maintenance/add_maintenance_screen.dart';
import 'job_card_detail_screen.dart';

class CreateJobCardScreen extends StatefulWidget {
  /// Customer/vehicle a NEW job card is created for. The screen shows them as
  /// a read-only summary banner; the caller decides them before pushing.
  final Customer? customer;
  final Vehicle? vehicle;

  /// Non-null puts the screen in edit mode: fields are prefilled from this
  /// job card and saving updates it (id, number, status and timestamps kept).
  final JobCard? existing;

  /// Edit mode only: when true the job card's items are locked (billed on an
  /// invoice) — the items section is read-only and saving keeps the original
  /// items instead of the editor's selection.
  final bool itemsLocked;

  const CreateJobCardScreen({
    super.key,
    this.customer,
    this.vehicle,
    this.existing,
    this.itemsLocked = false,
  });

  @override
  State<CreateJobCardScreen> createState() => _CreateJobCardScreenState();
}

class _CreateJobCardScreenState extends State<CreateJobCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _complaintController = TextEditingController();
  final _kmController = TextEditingController();
  final _notesController = TextEditingController();
  final _estCostController = TextEditingController();

  final List<String> _complaints = [];
  final List<MaintenanceItem> _selectedItems = [];
  String? _assignedStaffId;
  String _fuelLevel = '1/2';
  late DateTime _promisedDate;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  /// Items are only ever locked on the edit path (a billed job card); the
  /// create path has no originals to preserve, so the flag alone is not enough.
  bool get _itemsLocked => _isEditing && widget.itemsLocked;

  // Single source: the model's default inspection checklist (mutable copy so
  // the form checkboxes can be toggled). Edit mode swaps this for a mutable
  // copy of the job card's own captured checklist.
  final Map<String, bool> _inspectionChecklist =
      Map<String, bool>.from(JobCard.defaultChecklist);

  @override
  void initState() {
    super.initState();
    final provider = context.read<GarageProvider>();
    _promisedDate = DateTime.now().add(
      Duration(hours: provider.config.promisedDeliveryHours),
    );
    _kmController.text = widget.vehicle?.currentKm.toString() ?? '';

    // Edit mode: prefill everything from the job card being edited.
    final existing = widget.existing;
    if (existing != null) {
      _promisedDate = existing.promisedDeliveryDate;
      _kmController.text = existing.kmReading.toString();
      _complaints.addAll(existing.customerComplaints);
      _selectedItems.addAll(existing.items.map((item) => item.copyWith()));
      _notesController.text = existing.supervisorNotes ?? '';
      _estCostController.text = existing.estimatedCostNote ?? '';
      _inspectionChecklist
        ..clear()
        ..addAll(Map<String, bool>.from(existing.inspectionChecklist));
      // Dropdowns assert when their initial value is not among the options,
      // so a staff member that no longer exists / is inactive falls back to
      // unassigned instead of crashing the form.
      _assignedStaffId = provider.staff
              .any((s) => s.id == existing.assignedStaffId && s.isActive)
          ? existing.assignedStaffId
          : null;
      _fuelLevel = const ['Empty', '1/4', '1/2', '3/4', 'Full']
              .contains(existing.fuelLevel)
          ? existing.fuelLevel
          : '1/2';
    }
  }

  @override
  void dispose() {
    _complaintController.dispose();
    _kmController.dispose();
    _notesController.dispose();
    _estCostController.dispose();
    super.dispose();
  }

  void _addComplaint() {
    final text = _complaintController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _complaints.add(text);
        _complaintController.clear();
      });
    }
  }

  void _openAddItems() async {
    final items = await Navigator.push<List<MaintenanceItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMaintenanceScreen(
          initialItems: _selectedItems,
          title: 'Add Job Card Work Items',
        ),
      ),
    );

    if (items != null) {
      setState(() {
        _selectedItems.clear();
        _selectedItems.addAll(items);
      });
    }
  }

  void _pickPromisedDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _promisedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_promisedDate),
      );
      if (time != null && mounted) {
        setState(() {
          _promisedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _saveJobCard() async {
    // Latch: a fast double-tap on Save must not create two job cards.
    if (_isSaving) return;
    if (_complaints.isEmpty && _complaintController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one customer complaint or service requirement')),
      );
      return;
    }

    setState(() => _isSaving = true);

    if (_complaintController.text.trim().isNotEmpty) {
      _complaints.add(_complaintController.text.trim());
      _complaintController.clear();
    }

    final provider = Provider.of<GarageProvider>(context, listen: false);
    final existing = widget.existing;
    // Rebuilt explicitly (not copyWith) so fields the form does not edit —
    // id, jobCardNumber, status, createdAt, completedAt — carry over exactly
    // as before on the edit path, the same approach the quotation edit uses.
    final jobCard = JobCard(
      id: existing?.id ?? const Uuid().v4(),
      // Numbers are generated only for new job cards.
      jobCardNumber: existing?.jobCardNumber ?? provider.generateJobCardNumber(),
      customerId: existing?.customerId ?? widget.customer!.id,
      vehicleId: existing?.vehicleId ?? widget.vehicle!.id,
      customerComplaints: _complaints,
      inspectionChecklist: _inspectionChecklist,
      fuelLevel: _fuelLevel,
      kmReading: int.tryParse(_kmController.text.trim()) ??
          existing?.kmReading ??
          widget.vehicle?.currentKm ??
          0,
      assignedStaffId: _assignedStaffId,
      status: existing?.status ?? JobStatus.inProgress,
      promisedDeliveryDate: _promisedDate,
      createdAt: existing?.createdAt,
      completedAt: existing?.completedAt,
      // When the items are locked (billed on an invoice) the originals are
      // carried over untouched so they keep matching the printed invoice —
      // the editor's _selectedItems are display-only in that state.
      items: _itemsLocked ? existing!.items : _selectedItems,
      estimatedCostNote:
          _estCostController.text.trim().isEmpty ? null : _estCostController.text.trim(),
      supervisorNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    try {
      if (_isEditing) {
        await provider.updateJobCard(jobCard);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Job Card ${jobCard.jobCardNumber} updated successfully!'),
            backgroundColor: AppColors.paid,
          ),
        );

        Navigator.pop(context);
      } else {
        await provider.addJobCard(jobCard);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Job Card ${jobCard.jobCardNumber} created successfully!'),
            backgroundColor: AppColors.paid,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => JobCardDetailScreen(jobCardId: jobCard.id),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.pending,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Edit mode: the customer/vehicle are locked, so they are resolved from
    // the provider by the job card's ids and shown read-only below.
    final Customer? customer =
        _isEditing ? provider.getCustomerById(widget.existing!.customerId) : widget.customer;
    final Vehicle? vehicle =
        _isEditing ? provider.getVehicleById(widget.existing!.vehicleId) : widget.vehicle;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Job Card' : 'New Job Card',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer & Vehicle summary banner (read-only; locked in edit mode)
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
                      child: const Icon(Icons.car_repair_rounded, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle?.registrationNumber ?? 'Vehicle',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${vehicle?.displayName ?? '—'} • ${customer?.name ?? '—'}',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            ),
                          ),
                          if (_isEditing) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${widget.existing!.jobCardNumber} • customer & vehicle locked',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_isEditing)
                      Icon(Icons.lock_rounded, size: 18,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Current KM & Fuel Level Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kmController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Current KM *',
                        prefixIcon: Icon(Icons.speed_rounded, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _fuelLevel,
                      decoration: const InputDecoration(
                        labelText: 'Fuel Gauge',
                        prefixIcon: Icon(Icons.local_gas_station_rounded, color: AppColors.primary),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Empty', child: Text('Empty / Reserve')),
                        DropdownMenuItem(value: '1/4', child: Text('1/4 Tank')),
                        DropdownMenuItem(value: '1/2', child: Text('1/2 Tank')),
                        DropdownMenuItem(value: '3/4', child: Text('3/4 Tank')),
                        DropdownMenuItem(value: 'Full', child: Text('Full Tank')),
                      ],
                      onChanged: (val) => setState(() => _fuelLevel = val ?? '1/2'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Lead Mechanic & Delivery Date
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _assignedStaffId,
                      decoration: const InputDecoration(
                        labelText: 'Assign Mechanic',
                        prefixIcon: Icon(Icons.person_pin_rounded, color: AppColors.primary),
                      ),
                      hint: const Text('Select Mechanic'),
                      items: provider.staff
                          .where((s) => s.isActive)
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text('${s.name} (${s.role.displayName})'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _assignedStaffId = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Promised Delivery Date & Time
              InkWell(
                onTap: _pickPromisedDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Promised Delivery Time',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                ),
                              ),
                              Text(
                                AppDateFormatter.formatDateTime(_promisedDate),
                                style: GoogleFonts.poppins(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Customer Complaints / Demands
              Text(
                'Customer Complaints & Voice',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _complaintController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Brake noise, Oil leak, AC cooling slow...',
                      ),
                      onSubmitted: (_) => _addComplaint(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addComplaint,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
              if (_complaints.isNotEmpty) ...[
                const SizedBox(height: 10),
                ..._complaints.asMap().entries.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_right_rounded, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _complaints.removeAt(entry.key)),
                          child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),

              // Inspection Checklist
              Text(
                'Inspection & Vehicle Health Checklist',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: _inspectionChecklist.keys.map((key) {
                    final checked = _inspectionChecklist[key] ?? true;
                    return CheckboxListTile(
                      value: checked,
                      title: Text(key, style: GoogleFonts.poppins(fontSize: 13.5)),
                      activeColor: AppColors.paid,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          _inspectionChecklist[key] = val ?? false;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Items / Parts Selector Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Work Items & Parts (${_selectedItems.length})',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  // A billed job locks its items; the disabled button carries
                  // the same explanatory tooltip as the detail screen.
                  Tooltip(
                    message: _itemsLocked
                        ? 'Locked — billed on an invoice'
                        : 'Add parts & labour items',
                    child: TextButton.icon(
                      onPressed: _itemsLocked ? null : _openAddItems,
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text('Add Items'),
                    ),
                  ),
                ],
              ),
              if (_selectedItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._selectedItems.map((item) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      title: Text(item.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text('${item.quantity} x ${CurrencyFormatter.format(item.unitPrice)}'),
                      trailing: Text(
                        CurrencyFormatter.format(item.totalAmount),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),

              // Internal Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Supervisor Diagnostic Remarks',
                  hintText: 'e.g. Scratches on front left bumper noted, spare wheel in trunk',
                ),
              ),
              const SizedBox(height: 14),

              // Estimated Cost Note
              TextFormField(
                controller: _estCostController,
                decoration: const InputDecoration(
                  labelText: 'Est. cost note (optional)',
                  hintText: 'e.g. Approx 4,000 depending on parts availability',
                  prefixIcon: Icon(Icons.request_quote_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveJobCard,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(_isEditing ? 'Save Changes' : 'Create & Issue Job Card'),
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
}
