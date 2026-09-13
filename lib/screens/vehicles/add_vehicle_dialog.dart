import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_palette.dart';

class AddVehicleDialog extends StatefulWidget {
  final String customerId;
  final Vehicle? vehicleToEdit;

  const AddVehicleDialog({
    super.key,
    required this.customerId,
    this.vehicleToEdit,
  });

  @override
  State<AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends State<AddVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _regNoController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _variantController = TextEditingController();
  final _yearController = TextEditingController();
  final _kmController = TextEditingController();
  final _colorController = TextEditingController();

  FuelType _fuelType = FuelType.petrol;

  bool get isEditing => widget.vehicleToEdit != null;

  @override
  void initState() {
    super.initState();
    if (widget.vehicleToEdit != null) {
      final v = widget.vehicleToEdit!;
      _regNoController.text = v.registrationNumber;
      _makeController.text = v.make;
      _modelController.text = v.model;
      _variantController.text = v.variant ?? '';
      _yearController.text = v.year?.toString() ?? '';
      _kmController.text = v.currentKm.toString();
      _colorController.text = v.color ?? '';
      _fuelType = v.fuelType;
    }
  }

  @override
  void dispose() {
    _regNoController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _variantController.dispose();
    _yearController.dispose();
    _kmController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<GarageProvider>(context, listen: false);

    if (isEditing) {
      // Build explicitly from controllers instead of copyWith: copyWith
      // treats null as "keep existing", so clearing Variant/Color/Year in
      // the form would silently keep the old values.
      final original = widget.vehicleToEdit!;
      final updated = Vehicle(
        id: original.id,
        customerId: original.customerId,
        registrationNumber: _regNoController.text.trim().toUpperCase(),
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        variant: _variantController.text.trim().isEmpty ? null : _variantController.text.trim(),
        year: int.tryParse(_yearController.text.trim()),
        fuelType: _fuelType,
        currentKm: int.tryParse(_kmController.text.trim()) ?? 0,
        color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
        chassisNumber: original.chassisNumber,
        engineNumber: original.engineNumber,
        createdAt: original.createdAt,
        lastServiceDate: original.lastServiceDate,
      );

      await provider.updateVehicle(updated);
      if (!mounted) return;
      Navigator.pop(context, updated);
      return;
    }

    final newVehicle = Vehicle(
      id: const Uuid().v4(),
      customerId: widget.customerId,
      registrationNumber: _regNoController.text.trim().toUpperCase(),
      make: _makeController.text.trim(),
      model: _modelController.text.trim(),
      variant: _variantController.text.trim().isEmpty ? null : _variantController.text.trim(),
      year: int.tryParse(_yearController.text.trim()),
      fuelType: _fuelType,
      currentKm: int.tryParse(_kmController.text.trim()) ?? 0,
      color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
    );

    await provider.addVehicle(newVehicle);
    if (!mounted) return;
    Navigator.pop(context, newVehicle);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Plain AlertDialog: the theme's dialogTheme supplies the background
    // (palette surface) and card-radius shape in both modes.
    return AlertDialog(
      content: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Vehicle' : 'Add New Vehicle',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Registration Number
                TextFormField(
                  controller: _regNoController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Registration Number *',
                    hintText: 'e.g. MH 12 AB 1234',
                    prefixIcon: Icon(Icons.pin_rounded, color: palette.primary),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Registration number is required';
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
                          hintText: 'e.g. Maruti, Hyundai',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Model *',
                          hintText: 'e.g. Swift, Creta',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Variant & Year Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _variantController,
                        decoration: const InputDecoration(
                          labelText: 'Variant / Trim',
                          hintText: 'e.g. VXI, SX',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Mfg Year',
                          hintText: 'e.g. 2021',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Fuel Type Selector
                Text(
                  'Fuel Type',
                  style: GoogleFonts.inter(
                    fontSize: 13,
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
                        color: isSelected ? palette.primary : palette.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _fuelType = fuel);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Current KM Reading & Color
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _kmController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Current KM Reading *',
                          hintText: 'e.g. 35000',
                          prefixIcon: Icon(Icons.speed_rounded, color: palette.primary),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'KM is required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Color',
                          hintText: 'e.g. White, Black',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveVehicle,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(isEditing ? 'Update Vehicle' : 'Save Vehicle'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
