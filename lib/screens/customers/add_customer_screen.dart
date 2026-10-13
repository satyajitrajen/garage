import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../job_cards/create_job_card_screen.dart';
import '../quotations/create_quotation_screen.dart';
import '../../theme/app_text.dart';
import '../../utils/error_message.dart';
import '../../utils/grouped_number.dart';
import '../../l10n/app_language.dart';
import '../../utils/form_errors.dart';

class AddCustomerScreen extends StatefulWidget {
  final bool startJobImmediately;
  final Customer? customerToEdit;

  /// Pre-fills the vehicle's registration number (from "Start a job").
  final String? initialRegistration;

  const AddCustomerScreen({
    super.key,
    this.startJobImmediately = false,
    this.customerToEdit,
    this.initialRegistration,
  });

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  /// Set by the first submit attempt; from then on fields re-validate
  /// as they are edited, so fixed errors clear immediately.
  bool _submitted = false;

  bool get isEditing => widget.customerToEdit != null;

  // Customer controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
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
  bool _showMoreCustomer = false;
  bool _showMoreVehicle = false;
  bool _isSaving = false;
  Customer? _createdCustomer;

  @override
  void initState() {
    super.initState();
    if (widget.initialRegistration != null) {
      _regNoController.text = widget.initialRegistration!;
    }
    if (widget.customerToEdit != null) {
      final c = widget.customerToEdit!;
      _nameController.text = c.name;
      _phoneController.text = c.phone;
      _whatsappController.text = c.whatsappNumber ?? '';
      _sameAsPhone = c.whatsappNumber == null || c.whatsappNumber == c.phone;
      _emailController.text = c.email ?? '';
      _gstinController.text = c.gstin ?? '';
      _addressController.text = c.address ?? '';
      _notesController.text = c.notes ?? '';
      _hasVehicle = false;
      // Editing: open the optional section if anything in it is filled in.
      _showMoreCustomer = [c.email, c.gstin, c.address, c.notes]
          .any((v) => v != null && v.trim().isNotEmpty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
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

  Future<void> _handleSave({bool startJob = false, bool createQuote = false}) async {
    if (_isSaving) return;
    if (!_submitted) setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) {
      scrollToFirstFormError(_formKey);
      return;
    }

    final provider = Provider.of<GarageProvider>(context, listen: false);
    setState(() => _isSaving = true);

    try {
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
          gstin: _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: original.createdAt,
        );

        await provider.updateCustomer(updatedCustomer);
        if (!mounted) return;

        showAppSnackBar(
          context,
          'Customer ${updatedCustomer.name} updated successfully!',
          type: SnackBarType.success,
        );

        Navigator.pop(context, updatedCustomer);
        return;
      }

      final newCustomer = Customer(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        whatsappNumber: _sameAsPhone
            ? _phoneController.text.trim()
            : (_whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim()),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        gstin: _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Reject a duplicate plate before creating the customer, so a taken plate
      // doesn't leave a customer behind without the vehicle.
      if (_hasVehicle && _regNoController.text.trim().isNotEmpty) {
        final existing =
            provider.vehicleWithRegistration(_regNoController.text.trim());
        if (existing != null) {
          final owner = provider.getCustomerById(existing.customerId)?.name;
          showAppSnackBar(
            context,
            'Vehicle ${existing.registrationNumber} already exists${owner == null ? '' : ' (owner: $owner)'}',
            type: SnackBarType.error,
          );
          return;
        }
      }

      // Retry after vehicle failure: customer already created, skip creation
      final createdCustomer = _createdCustomer ?? await provider.addCustomer(newCustomer);
      _createdCustomer = createdCustomer;
      if (!mounted) return;

      Vehicle? createdVehicle;
      if (_hasVehicle && _regNoController.text.trim().isNotEmpty) {
        final newVehicle = Vehicle(
          id: const Uuid().v4(),
          customerId: createdCustomer.id,
          registrationNumber: _regNoController.text.trim().toUpperCase(),
          make: _makeController.text.trim(),
          model: _modelController.text.trim(),
          variant: _variantController.text.trim().isEmpty ? null : _variantController.text.trim(),
          year: int.tryParse(_yearController.text.trim()),
          fuelType: _fuelType,
          currentKm: parseGroupedInt(_kmController.text) ?? 0,
          color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
        );
        try {
          createdVehicle = await provider.addVehicle(newVehicle);
          if (!mounted) return;
          _createdCustomer = null;
        } catch (e) {
          if (!mounted) return;
          showAppSnackBar(
            context,
            errorMessage(e),
            type: SnackBarType.error,
          );
          return;
        }
      } else {
        _createdCustomer = null;
      }

      showAppSnackBar(
        context,
        'Customer ${createdCustomer.name} added successfully!',
        type: SnackBarType.success,
      );

      if (startJob && createdVehicle != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CreateJobCardScreen(
              customer: createdCustomer,
              vehicle: createdVehicle!,
            ),
          ),
        );
      } else if (createQuote && createdVehicle != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CreateQuotationScreen(
              customer: createdCustomer,
              vehicle: createdVehicle!,
            ),
          ),
        );
      } else {
        Navigator.pop(context, createdCustomer);
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        errorMessage(e),
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
          isEditing ? tr('Edit Customer') : tr('Add New Customer'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.paddingScreen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------------------------------------------
              // CUSTOMER DETAILS SECTION
              // ---------------------------------------------------
              _buildSectionTitle(
                context,
                title: tr('Customer Details'),
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 16),

              // Full Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: tr('Customer Full Name *'),
                  hintText: 'e.g. Ramesh Patel',
                  prefixIcon: Icon(Icons.person_rounded, color: palette.textSecondary),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? tr('Customer name is required') : null,
              ),
              const SizedBox(height: AppDimens.paddingCard),

              // Mobile / Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: tr('Mobile Number *'),
                  hintText: 'e.g. +91 98765 43210',
                  prefixIcon: Icon(Icons.phone_android_rounded, color: palette.textSecondary),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? tr('Mobile number is required') : null,
              ),
              const SizedBox(height: 10),

              // WhatsApp Checkbox
              CheckboxListTile(
                value: _sameAsPhone,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: palette.primary,
                title: Text(
                  tr('WhatsApp number is same as Mobile'),
                  style: GoogleFonts.poppins(fontSize: AppText.body),
                ),
                onChanged: (val) => setState(() => _sameAsPhone = val ?? true),
              ),

              if (!_sameAsPhone) ...[
                const SizedBox(height: 6),
                TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: tr('WhatsApp Number'),
                    hintText: 'e.g. +91 98765 43210',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded, color: palette.textSecondary),
                  ),
                ),
              ],
              const SizedBox(height: AppDimens.paddingCard),

              // Optional customer details (email, address, GSTIN, notes) are
              // folded away so the required fields fit on one screen.
              _moreToggle(
                label: tr('More customer details (email, address, GSTIN, notes)'),
                expanded: _showMoreCustomer,
                onTap: () => setState(() => _showMoreCustomer = !_showMoreCustomer),
              ),
              if (_showMoreCustomer) ...[
              const SizedBox(height: AppDimens.paddingCard),
              // Email & Address
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: tr('Email Address (Optional)'),
                  hintText: 'e.g. customer@gmail.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: AppDimens.paddingCard),

              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('Customer Address / Location'),
                  hintText: 'e.g. Flat 101, Palm Residency, Mumbai',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: AppDimens.paddingCard),

              // GSTIN (optional tax identity) — uppercase forced so stored
              // values match the format printed on invoices. Non-empty input
              // must be the full 15 characters.
              TextFormField(
                controller: _gstinController,
                maxLength: 15,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) =>
                        newValue.copyWith(text: newValue.text.toUpperCase()),
                  ),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  labelText: tr('GSTIN (Optional)'),
                  hintText: 'e.g. 27ABCDE1234F1Z5',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                validator: (val) {
                  final gstin = val?.trim() ?? '';
                  if (gstin.isNotEmpty && gstin.length != 15) {
                    return tr('Enter a valid 15-character GSTIN');
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimens.paddingCard),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('Customer / Special Preference Notes'),
                  hintText: 'e.g. VIP client, requests synthetic oil always',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              ],
              const SizedBox(height: AppDimens.paddingScreen * 2),

              // ---------------------------------------------------
              // VEHICLE DETAILS SECTION
              // ---------------------------------------------------
              if (!isEditing) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildSectionTitle(
                        context,
                        title: tr('Vehicle Information'),
                        icon: Icons.directions_car_filled_rounded,
                      ),
                    ),
                    // Labelled, with a white thumb: a red thumb on the red
                    // track read as an unlabeled red button.
                    Text(
                      tr('Add vehicle'),
                      style: GoogleFonts.poppins(
                        fontSize: AppText.caption,
                        color: palette.textSecondary,
                      ),
                    ),
                    Switch.adaptive(
                      value: _hasVehicle,
                      activeTrackColor: palette.primary,
                      thumbColor: WidgetStatePropertyAll(palette.onPrimary),
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
                  decoration: InputDecoration(
                    labelText: tr('Vehicle Registration Number *'),
                    hintText: 'e.g. DL 01 AB 1234 / MH 02 CZ 4421',
                    prefixIcon: Icon(Icons.pin_rounded, color: palette.textSecondary),
                  ),
                  validator: (val) {
                    if (_hasVehicle && (val == null || val.trim().isEmpty)) {
                      return tr('Registration number is required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimens.paddingCard),

                // Make & Model Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _makeController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: tr('Make *'),
                          hintText: 'e.g. Maruti / Hyundai / Honda',
                        ),
                        validator: (val) => _hasVehicle && (val == null || val.trim().isEmpty)
                            ? tr('Required')
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: tr('Model *'),
                          hintText: 'e.g. Swift / Creta / City',
                        ),
                        validator: (val) => _hasVehicle && (val == null || val.trim().isEmpty)
                            ? tr('Required')
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.paddingCard),

                // Current KM Reading
                TextFormField(
                  controller: _kmController,
                  inputFormatters: const [GroupedDigitsInputFormatter()],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('KM Reading *'),
                    hintText: 'e.g. 45000',
                    prefixIcon: Icon(Icons.speed_rounded, color: palette.textSecondary),
                  ),
                  validator: (val) {
                    if (_hasVehicle && (val == null || val.trim().isEmpty)) {
                      return tr('KM is required');
                    }
                    if (_hasVehicle && val != null && val.trim().isNotEmpty) {
                      final km = parseGroupedInt(val);
                      if (km == null || km < 0) return tr('Enter a valid KM reading');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimens.paddingCard),

                // Fuel Type
                Text(
                  tr('Fuel Type'),
                  style: GoogleFonts.poppins(
                    fontSize: AppText.caption,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
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
                      selectedColor: palette.primary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? palette.primary
                            : palette.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _fuelType = fuel);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                _moreToggle(
                  label: tr('More vehicle details (variant, year, colour)'),
                  expanded: _showMoreVehicle,
                  onTap: () => setState(() => _showMoreVehicle = !_showMoreVehicle),
                ),
                if (_showMoreVehicle) ...[
                const SizedBox(height: AppDimens.paddingCard),
                TextFormField(
                  controller: _variantController,
                  decoration: InputDecoration(
                    labelText: tr('Variant'),
                    hintText: 'e.g. VXI, SX (O)',
                  ),
                ),
                const SizedBox(height: AppDimens.paddingCard),
                // Year & Color
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tr('Year'),
                          hintText: 'e.g. 2022',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        decoration: InputDecoration(
                          labelText: tr('Vehicle Color'),
                          hintText: 'e.g. White / Silver',
                        ),
                      ),
                    ),
                  ],
                ),
                ],
              ],
              const SizedBox(height: AppDimens.paddingScreen * 2),

              // ---------------------------------------------------
              // ACTION BUTTONS
              // ---------------------------------------------------
              if (isEditing) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _handleSave(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                    ),
                    child: Text(tr('Update Customer Details')),
                  ),
                ),
              ] else if (_hasVehicle) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isSaving ? null : () => _handleSave(startJob: true),
                    icon: const Icon(Icons.add_task_rounded),
                    label: Text(tr('Save & Start Job Card')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => _handleSave(createQuote: true),
                        icon: const Icon(Icons.request_quote_rounded, size: 18),
                        label: Text(tr('Create Estimate')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => _handleSave(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: palette.textMuted),
                          foregroundColor: palette.textPrimary,
                        ),
                        child: Text(tr('Save Customer Only')),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _handleSave(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(tr('Save Customer')),
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

  /// "More details" disclosure row for optional fields.
  Widget _moreToggle({
    required String label,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
      icon: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
      label: Text(
        expanded ? tr('Hide optional details') : label,
        textAlign: TextAlign.start,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, {required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: context.palette.primary, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: AppText.title,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
