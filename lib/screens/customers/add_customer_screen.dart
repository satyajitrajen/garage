import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../job_cards/create_job_card_screen.dart';
import '../quotations/create_quotation_screen.dart';

class AddCustomerScreen extends StatefulWidget {
  final bool startJobImmediately;
  final Customer? customerToEdit;

  const AddCustomerScreen({
    super.key,
    this.startJobImmediately = false,
    this.customerToEdit,
  });

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get isEditing => widget.customerToEdit != null;

  // Customer controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  // Vehicle controllers
  final _regNoController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _variantController = TextEditingController();
  final _kmController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();

  FuelType _fuelType = FuelType.petrol;
  bool _sameAsPhone = true;
  bool _hasVehicle = true;

  @override
  void initState() {
    super.initState();
    if (widget.customerToEdit != null) {
      final c = widget.customerToEdit!;
      _nameController.text = c.name;
      _phoneController.text = c.phone;
      _whatsappController.text = c.whatsappNumber ?? '';
      _sameAsPhone = c.whatsappNumber == null || c.whatsappNumber == c.phone;
      _emailController.text = c.email ?? '';
      _addressController.text = c.address ?? '';
      _notesController.text = c.notes ?? '';
      _hasVehicle = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _regNoController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _variantController.dispose();
    _kmController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _handleSave({bool startJob = false, bool createQuote = false}) {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<GarageProvider>(context, listen: false);

    if (isEditing) {
      // Build explicitly from controllers instead of copyWith: copyWith
      // treats null as "keep existing", so cleared fields would silently
      // keep their old values.
      final original = widget.customerToEdit!;
      final updatedCustomer = Customer(
        id: original.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        whatsappNumber: _sameAsPhone
            ? _phoneController.text.trim()
            : (_whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim()),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        gstin: original.gstin,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: original.createdAt,
      );

      provider.updateCustomer(updatedCustomer);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Customer ${updatedCustomer.name} updated successfully!'),
          backgroundColor: AppColors.paid,
        ),
      );

      Navigator.pop(context, updatedCustomer);
      return;
    }

    final uuid = const Uuid();
    final customerId = uuid.v4();
    final newCustomer = Customer(
      id: customerId,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      whatsappNumber: _sameAsPhone
          ? _phoneController.text.trim()
          : (_whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim()),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    provider.addCustomer(newCustomer);

    Vehicle? newVehicle;
    if (_hasVehicle && _regNoController.text.trim().isNotEmpty) {
      newVehicle = Vehicle(
        id: uuid.v4(),
        customerId: customerId,
        registrationNumber: _regNoController.text.trim().toUpperCase(),
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        variant: _variantController.text.trim().isEmpty ? null : _variantController.text.trim(),
        year: int.tryParse(_yearController.text.trim()),
        fuelType: _fuelType,
        currentKm: int.tryParse(_kmController.text.trim()) ?? 0,
        color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
      );
      provider.addVehicle(newVehicle);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Customer ${newCustomer.name} added successfully!'),
        backgroundColor: AppColors.paid,
      ),
    );

    if (startJob && newVehicle != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CreateJobCardScreen(
            customer: newCustomer,
            vehicle: newVehicle!,
          ),
        ),
      );
    } else if (createQuote && newVehicle != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CreateQuotationScreen(
            customer: newCustomer,
            vehicle: newVehicle!,
          ),
        ),
      );
    } else {
      Navigator.pop(context, newCustomer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Customer' : 'Add New Customer',
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
              // ---------------------------------------------------
              // CUSTOMER DETAILS SECTION
              // ---------------------------------------------------
              _buildSectionTitle(
                context,
                title: 'Customer Details',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 16),

              // Full Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Customer Full Name *',
                  hintText: 'e.g. Ramesh Patel',
                  prefixIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Customer name is required' : null,
              ),
              const SizedBox(height: 14),

              // Mobile / Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  hintText: 'e.g. +91 98765 43210',
                  prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.primary),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Mobile number is required' : null,
              ),
              const SizedBox(height: 10),

              // WhatsApp Checkbox
              CheckboxListTile(
                value: _sameAsPhone,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
                title: Text(
                  'WhatsApp number is same as Mobile',
                  style: GoogleFonts.poppins(fontSize: 13.5),
                ),
                onChanged: (val) => setState(() => _sameAsPhone = val ?? true),
              ),

              if (!_sameAsPhone) ...[
                const SizedBox(height: 6),
                TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number',
                    hintText: 'e.g. +91 98765 43210',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.paid),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Email & Address
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address (Optional)',
                  hintText: 'e.g. customer@gmail.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Customer Address / Location',
                  hintText: 'e.g. Flat 101, Palm Residency, Mumbai',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 28),

              // ---------------------------------------------------
              // VEHICLE DETAILS SECTION
              // ---------------------------------------------------
              if (!isEditing) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle(
                      context,
                      title: 'Vehicle Information',
                      icon: Icons.directions_car_filled_rounded,
                    ),
                    Switch.adaptive(
                      value: _hasVehicle,
                      activeTrackColor: AppColors.primary,
                      onChanged: (v) => setState(() => _hasVehicle = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              if (_hasVehicle) ...[
                // Registration Number
                TextFormField(
                  controller: _regNoController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Registration Number *',
                    hintText: 'e.g. DL 01 AB 1234 / MH 02 CZ 4421',
                    prefixIcon: Icon(Icons.pin_rounded, color: AppColors.primary),
                  ),
                  validator: (val) {
                    if (_hasVehicle && (val == null || val.trim().isEmpty)) {
                      return 'Registration number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Make & Model Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _makeController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Make / Brand *',
                          hintText: 'e.g. Maruti / Hyundai / Honda',
                        ),
                        validator: (val) => _hasVehicle && (val == null || val.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Model *',
                          hintText: 'e.g. Swift / Creta / City',
                        ),
                        validator: (val) => _hasVehicle && (val == null || val.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Current KM Reading & Variant
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _kmController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Current KM Reading *',
                          hintText: 'e.g. 45000',
                          prefixIcon: Icon(Icons.speed_rounded, color: AppColors.primary),
                        ),
                        validator: (val) => _hasVehicle && (val == null || val.trim().isEmpty)
                            ? 'KM is required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _variantController,
                        decoration: const InputDecoration(
                          labelText: 'Variant / Trim',
                          hintText: 'e.g. VXI, SX (O)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Fuel Type
                Text(
                  'Fuel Type',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FuelType.values.map((fuel) {
                    final isSelected = _fuelType == fuel;
                    return ChoiceChip(
                      label: Text(fuel.displayName),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? Colors.white : AppColors.textPrimary),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _fuelType = fuel);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Year & Color
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          hintText: 'e.g. 2022',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Color',
                          hintText: 'e.g. White / Silver',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Customer / Special Preference Notes',
                  hintText: 'e.g. VIP client, requests synthetic oil always',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 32),

              // ---------------------------------------------------
              // ACTION BUTTONS
              // ---------------------------------------------------
              if (isEditing) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleSave(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Update Customer Details'),
                  ),
                ),
              ] else if (_hasVehicle) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleSave(startJob: true),
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Save & Start Job Card'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleSave(createQuote: true),
                        icon: const Icon(Icons.request_quote_rounded, size: 18),
                        label: const Text('Create Estimate'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleSave(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ),
                          foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        child: const Text('Save Customer Only'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleSave(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save Customer'),
                  ),
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, {required String title, required IconData icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
