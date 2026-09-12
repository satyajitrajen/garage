import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/staff.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';

class AddStaffScreen extends StatefulWidget {
  final Staff? staffToEdit;

  const AddStaffScreen({super.key, this.staffToEdit});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _salaryController = TextEditingController();
  final _addressController = TextEditingController();

  StaffRole _selectedRole = StaffRole.seniorTechnician;

  @override
  void initState() {
    super.initState();
    if (widget.staffToEdit != null) {
      final s = widget.staffToEdit!;
      _nameController.text = s.name;
      _phoneController.text = s.phone;
      _emailController.text = s.email ?? '';
      _salaryController.text = s.monthlySalary.toStringAsFixed(0);
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
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<GarageProvider>(context, listen: false);
    final salary = double.tryParse(_salaryController.text.trim()) ?? 0.0;

    if (widget.staffToEdit != null) {
      final updated = widget.staffToEdit!.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        monthlySalary: salary,
        role: _selectedRole,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      );
      await provider.updateStaff(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Staff ${updated.name} updated!'), backgroundColor: AppColors.paid),
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
      await provider.addStaff(newStaff);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Employee ${newStaff.name} added to team!'), backgroundColor: AppColors.paid),
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.staffToEdit != null ? 'Edit Employee' : 'Add Garage Staff',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Staff Full Name *',
                  hintText: 'e.g. Ramesh Sharma',
                  prefixIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: 'e.g. +91 98765 43210',
                  prefixIcon: Icon(Icons.phone_rounded, color: AppColors.primary),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: 14),

              // Role Dropdown
              DropdownButtonFormField<StaffRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Staff Role / Skill *',
                  prefixIcon: Icon(Icons.badge_rounded, color: AppColors.primary),
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
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  labelText: 'Monthly Base Salary (₹) *',
                  hintText: 'e.g. 24000',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter salary';
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) return 'Invalid salary amount';
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
                  onPressed: _saveStaff,
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
