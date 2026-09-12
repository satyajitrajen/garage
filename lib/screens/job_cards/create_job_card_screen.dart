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
import '../../utils/date_formatter.dart';
import '../maintenance/add_maintenance_screen.dart';
import 'job_card_detail_screen.dart';

class CreateJobCardScreen extends StatefulWidget {
  final Customer customer;
  final Vehicle vehicle;

  const CreateJobCardScreen({
    super.key,
    required this.customer,
    required this.vehicle,
  });

  @override
  State<CreateJobCardScreen> createState() => _CreateJobCardScreenState();
}

class _CreateJobCardScreenState extends State<CreateJobCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _complaintController = TextEditingController();
  final _kmController = TextEditingController();
  final _notesController = TextEditingController();

  final List<String> _complaints = [];
  final List<MaintenanceItem> _selectedItems = [];
  String? _assignedStaffId;
  String _fuelLevel = '1/2';
  DateTime _promisedDate = DateTime.now().add(const Duration(hours: 6));
  bool _isSaving = false;

  final Map<String, bool> _inspectionChecklist = {
    'Engine Oil & Level': true,
    'Brake Fluid & System': true,
    'Coolant / Radiator': true,
    'Battery & Terminals': true,
    'Tyres & Pressure': true,
    'AC & Cabin Cooling': true,
    'All Lights & Horn': true,
    'Body Scratches Checked': true,
  };

  @override
  void initState() {
    super.initState();
    _kmController.text = widget.vehicle.currentKm.toString();
  }

  @override
  void dispose() {
    _complaintController.dispose();
    _kmController.dispose();
    _notesController.dispose();
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
    final jobCard = JobCard(
      id: const Uuid().v4(),
      jobCardNumber: provider.generateJobCardNumber(),
      customerId: widget.customer.id,
      vehicleId: widget.vehicle.id,
      customerComplaints: _complaints,
      inspectionChecklist: _inspectionChecklist,
      fuelLevel: _fuelLevel,
      kmReading: int.tryParse(_kmController.text.trim()) ?? widget.vehicle.currentKm,
      assignedStaffId: _assignedStaffId,
      status: JobStatus.inProgress,
      promisedDeliveryDate: _promisedDate,
      items: _selectedItems,
      supervisorNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('New Job Card', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
                      child: const Icon(Icons.car_repair_rounded, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.vehicle.registrationNumber,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.vehicle.displayName} • ${widget.customer.name}',
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
                  TextButton.icon(
                    onPressed: _openAddItems,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: const Text('Add Items'),
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
                      subtitle: Text('${item.quantity} x ₹${item.unitPrice}'),
                      trailing: Text(
                        '₹${item.totalAmount.toStringAsFixed(0)}',
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
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveJobCard,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Create & Issue Job Card'),
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
