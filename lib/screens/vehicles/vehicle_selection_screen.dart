import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../job_cards/create_job_card_screen.dart';
import '../quotations/create_quotation_screen.dart';
import '../invoices/create_invoice_screen.dart';
import 'add_vehicle_dialog.dart';
import '../../theme/app_text.dart';

enum VehicleTargetAction {
  createJobCard,
  createQuotation,
  createInvoice,
  viewOnly,
}

class VehicleSelectionScreen extends StatefulWidget {
  final Customer customer;
  final VehicleTargetAction targetAction;

  const VehicleSelectionScreen({
    super.key,
    required this.customer,
    this.targetAction = VehicleTargetAction.createJobCard,
  });

  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
  Vehicle? _selectedVehicle;

  void _proceedWithVehicle(Vehicle vehicle) {
    switch (widget.targetAction) {
      case VehicleTargetAction.createJobCard:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateJobCardScreen(
              customer: widget.customer,
              vehicle: vehicle,
            ),
          ),
        );
        break;
      case VehicleTargetAction.createQuotation:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateQuotationScreen(
              customer: widget.customer,
              vehicle: vehicle,
            ),
          ),
        );
        break;
      case VehicleTargetAction.createInvoice:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateInvoiceScreen(
              customer: widget.customer,
              vehicle: vehicle,
            ),
          ),
        );
        break;
      case VehicleTargetAction.viewOnly:
        Navigator.pop(context, vehicle);
        break;
    }
  }

  void _openAddVehicleDialog() async {
    final newVehicle = await showDialog<Vehicle>(
      context: context,
      builder: (_) => AddVehicleDialog(customerId: widget.customer.id),
    );

    if (newVehicle != null) {
      if (!mounted) return;
      setState(() {
        _selectedVehicle = newVehicle;
      });
      showAppSnackBar(
        context,
        'Added vehicle ${newVehicle.registrationNumber}',
        type: SnackBarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final vehicles = provider.getVehiclesForCustomer(widget.customer.id);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Vehicle', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: _openAddVehicleDialog,
            icon: Icon(Icons.add_rounded, color: palette.primary),
            label: Text(
              'Add Vehicle',
              style: GoogleFonts.poppins(
                color: palette.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Customer Summary Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: palette.card,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: palette.primary.withOpacity(0.12),
                  child: Text(
                    widget.customer.name.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: AppText.headline,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customer.name,
                        style: GoogleFonts.poppins(
                          fontSize: AppText.title,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 4,
                        children: [
                          Icon(Icons.phone_rounded, size: 14, color: palette.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            widget.customer.phone,
                            style: GoogleFonts.poppins(
                              fontSize: AppText.caption,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: palette.cardAlt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${vehicles.length} Vehicles',
                              style: GoogleFonts.poppins(
                                fontSize: AppText.label,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Vehicle List
          Expanded(
            child: vehicles.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.directions_car_filled_rounded,
                    title: 'No Vehicles Registered',
                    description: 'This customer has no vehicles listed yet. Add a vehicle to begin maintenance or estimates.',
                    buttonText: 'Add First Vehicle',
                    onButtonPressed: _openAddVehicleDialog,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
                    itemCount: vehicles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      final isSelected = _selectedVehicle?.id == vehicle.id;
                      final serviceHistory = provider.getServiceHistoryForVehicle(vehicle.id);

                      return InkWell(
                        onTap: () {
                          setState(() => _selectedVehicle = vehicle);
                          _proceedWithVehicle(vehicle);
                        },
                        borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                            border: Border.all(
                              color: isSelected ? palette.primary : palette.border,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: AppDimens.cardShadow(palette.textPrimary),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // License Plate visual box
                                  Flexible(
                                    child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: palette.background,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: palette.primary.withOpacity(0.5), width: 1.2),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Indian flag navy band — deliberate theme-invariant literal.
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF003399),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                          child: const Text(
                                            'IND',
                                            style: TextStyle(color: Colors.white, fontSize: AppText.micro, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            vehicle.registrationNumber,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: AppText.body,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.8,
                                              color: palette.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: palette.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      vehicle.fuelType.displayName,
                                      style: GoogleFonts.poppins(
                                        fontSize: AppText.label,
                                        fontWeight: FontWeight.w600,
                                        color: palette.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                vehicle.displayName,
                                style: GoogleFonts.poppins(
                                  fontSize: AppText.title,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                runSpacing: 4,
                                children: [
                                  Icon(Icons.speed_rounded, size: 15, color: palette.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${vehicle.currentKm.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} KM',
                                    style: GoogleFonts.poppins(
                                      fontSize: AppText.caption,
                                      fontWeight: FontWeight.w500,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                  if (vehicle.year != null) ...[
                                    const SizedBox(width: 12),
                                    Icon(Icons.calendar_today_rounded, size: 14, color: palette.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${vehicle.year} Model',
                                      style: GoogleFonts.poppins(
                                        fontSize: AppText.caption,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (vehicle.color != null) ...[
                                    const SizedBox(width: 12),
                                    Icon(Icons.palette_outlined, size: 14, color: palette.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      vehicle.color!,
                                      style: GoogleFonts.poppins(
                                        fontSize: AppText.caption,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (vehicle.lastServiceDate != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Last serviced: ${AppDateFormatter.formatDate(vehicle.lastServiceDate!)} (${serviceHistory.length} total visits)',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppText.label,
                                    color: palette.paid,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Tap to select & continue',
                                    style: GoogleFonts.poppins(
                                      fontSize: AppText.caption,
                                      fontWeight: FontWeight.w600,
                                      color: palette.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 16, color: palette.primary),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
