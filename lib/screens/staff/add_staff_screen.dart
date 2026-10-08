import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/api/api_exception.dart';
import '../../models/staff.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../theme/app_text.dart';

class AddStaffScreen extends StatefulWidget {
  final Staff? staffToEdit;

  const AddStaffScreen({super.key, this.staffToEdit});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  /// Set by the first submit attempt; from then on fields re-validate
  /// as they are edited, so fixed errors clear immediately.
  bool _submitted = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _salaryController = TextEditingController();
  final _addressController = TextEditingController();

  StaffRole _selectedRole = StaffRole.seniorTechnician;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.staffToEdit != null) {
      final s = widget.staffToEdit!;
      _nameController.text = s.name;
      _phoneController.text = s.phone;
      _emailController.text = s.email ?? '';
      _salaryController.text = s.monthlySalary == s.monthlySalary.roundToDouble()
          ? s.monthlySalary.toStringAsFixed(0)
          : s.monthlySalary.toStringAsFixed(2);
      _addressController.text = s.address ?? '';
      _selectedRole = s.role;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _salaryController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveStaff() async {
    if (_isSaving) return;
    if (!_submitted) setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<GarageProvider>(context, listen: false);
    final salary = double.tryParse(_salaryController.text.trim()) ?? 0.0;
    setState(() => _isSaving = true);

    try {
      if (widget.staffToEdit != null) {
        final original = widget.staffToEdit!;
        final updated = Staff(
          id: original.id,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          monthlySalary: salary,
          role: _selectedRole,
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          isActive: original.isActive,
          joiningDate: original.joiningDate,
          emergencyContact: original.emergencyContact,
        );
        final saved = await provider.updateStaff(updated);
        if (!mounted) return;
        showAppSnackBar(
          context,
          'Staff ${saved.name} updated!',
          type: SnackBarType.success,
        );
      } else {
        final newStaff = Staff(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          monthlySalary: salary,
          role: _selectedRole,
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        );
        final saved = await provider.addStaff(newStaff);
        if (!mounted) return;
        showAppSnackBar(
          context,
          'Employee ${saved.name} added to team!',
          type: SnackBarType.success,
        );
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.userMessage
          : 'Failed to save staff. Please try again.';
      showAppSnackBar(
        context,
        message,
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.staffToEdit != null ? 'Edit Employee' : 'Add Garage Staff',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Staff Full Name *',
                  hintText: 'e.g. Ramesh Sharma',
                  prefixIcon: Icon(Icons.person_rounded, color: palette.primary),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: 'e.g. +91 98765 43210',
                  prefixIcon: Icon(Icons.phone_rounded, color: palette.primary),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: 14),

              // Role Dropdown
              DropdownButtonFormField<StaffRole>(
                isExpanded: true,
                initialValue: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Staff Role / Skill *',
                  prefixIcon: Icon(Icons.badge_rounded, color: palette.primary),
                ),
                items: StaffRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.displayName),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedRole = val ?? StaffRole.seniorTechnician),
              ),
              const SizedBox(height: 14),

              // Monthly Salary
              TextFormField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Monthly Base Salary (₹) *',
                  hintText: 'e.g. 24000',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: palette.primary),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter salary';
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0 || !num.isFinite) return 'Invalid salary amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address (Optional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Residential Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveStaff,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(widget.staffToEdit != null ? 'Save Changes' : 'Add Employee'),
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
