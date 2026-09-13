import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/vehicle.dart';
import '../providers/garage_provider.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';
import '../utils/app_snack_bar.dart';
import '../screens/workflow/quick_service_wizard.dart';
import '../screens/job_cards/create_job_card_screen.dart';

/// Dashboard hero card modeled on a travel booking search card:
/// customer + vehicle rows, a read-only date/odometer pill row, service
/// chips, and one red CTA. Uses only existing provider data and flows.
class BookServiceCard extends StatefulWidget {
  const BookServiceCard({super.key});

  @override
  State<BookServiceCard> createState() => _BookServiceCardState();
}

class _BookServiceCardState extends State<BookServiceCard> {
  Customer? _customer;
  Vehicle? _vehicle;
  bool _quickService = true;

  Future<void> _pickCustomer() async {
    final provider = context.read<GarageProvider>();
    final selected = await showModalBottomSheet<Customer>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusSheet)),
      ),
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        final customers = provider.customers;
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: customers.length,
            itemBuilder: (_, i) {
              final customer = customers[i];
              return ListTile(
                title: Text(customer.name),
                subtitle: Text(customer.phone),
                onTap: () => Navigator.pop(sheetContext, customer),
                tileColor: i.isOdd ? palette.cardAlt : null,
              );
            },
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      _customer = selected;
      if (_vehicle?.customerId != selected.id) _vehicle = null;
    });
  }

  Future<void> _pickVehicle() async {
    final customer = _customer;
    if (customer == null) {
      await _pickCustomer();
      return;
    }
    final provider = context.read<GarageProvider>();
    final vehicles = provider.getVehiclesForCustomer(customer.id);
    if (!mounted) return;
    if (vehicles.isEmpty) {
      showAppSnackBar(context, 'No vehicles for ${customer.name}', type: SnackBarType.info);
      return;
    }
    final selected = await showModalBottomSheet<Vehicle>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusSheet)),
      ),
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: vehicles.length,
            itemBuilder: (_, i) {
              final vehicle = vehicles[i];
              return ListTile(
                title: Text('${vehicle.make} ${vehicle.model}'),
                subtitle: Text(vehicle.registrationNumber),
                onTap: () => Navigator.pop(sheetContext, vehicle),
                tileColor: i.isOdd ? palette.cardAlt : null,
              );
            },
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() => _vehicle = selected);
  }

  void _start() {
    final customer = _customer;
    if (customer == null) {
      _pickCustomer();
      return;
    }
    if (_quickService) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuickServiceWizard(initialCustomer: customer, initialVehicle: _vehicle),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateJobCardScreen(customer: customer, vehicle: _vehicle),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final today = DateTime.now();
    final provider = context.watch<GarageProvider>();
    final vehicleKm = _vehicle == null
        ? '—'
        : provider.getVehicleById(_vehicle!.id)?.currentKm.toString() ?? '—';

    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingCard),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: palette.border),
        boxShadow: AppDimens.cardShadow(palette.textPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book a Service', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          const SizedBox(height: 12),
          _bookingRow(
            palette: palette,
            label: 'Customer',
            value: _customer?.name ?? 'Select customer',
            icon: Icons.person_outline_rounded,
            hasValue: _customer != null,
            onTap: _pickCustomer,
          ),
          const SizedBox(height: 8),
          _bookingRow(
            palette: palette,
            label: 'Vehicle',
            value: _vehicle == null
                ? 'Select vehicle'
                : '${_vehicle!.make} ${_vehicle!.model} • ${_vehicle!.registrationNumber}',
            icon: Icons.directions_car_outlined,
            hasValue: _vehicle != null,
            onTap: _pickVehicle,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _pill(
                  palette: palette,
                  label: 'Date',
                  value: '${today.day} ${_month(today.month)} ${today.year}',
                  icon: Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pill(
                  palette: palette,
                  label: 'Odometer (km)',
                  value: vehicleKm,
                  icon: Icons.speed_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip(palette: palette, label: 'Quick Service', selected: _quickService,
                  onTap: () => setState(() => _quickService = true)),
              const SizedBox(width: 8),
              _chip(palette: palette, label: 'New Job Card', selected: !_quickService,
                  onTap: () => setState(() => _quickService = false)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                ),
              ),
              icon: const Icon(Icons.bolt_rounded, size: 20),
              label: Text(
                _quickService ? 'Start Quick Service' : 'Create Job Card',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _month(int month) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];

  Widget _bookingRow({
    required AppPalette palette,
    required String label,
    required String value,
    required IconData icon,
    required bool hasValue,
    required VoidCallback onTap,
  }) {
    return Material(
      color: palette.cardAlt,
      borderRadius: BorderRadius.circular(AppDimens.radiusTile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusTile),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: hasValue ? palette.primary : palette.border,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: palette.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: hasValue ? palette.textPrimary : palette.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 20, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required AppPalette palette,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.cardAlt,
        borderRadius: BorderRadius.circular(AppDimens.radiusTile),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: palette.textMuted)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.textPrimary)),
              ],
            ),
          ),
          Icon(icon, size: 16, color: palette.textMuted),
        ],
      ),
    );
  }

  Widget _chip({
    required AppPalette palette,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? palette.primary : palette.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
            border: selected ? null : Border.all(color: palette.border),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 12.5, fontWeight: FontWeight.w600,
                color: selected ? palette.onPrimary : palette.textPrimary),
          ),
        ),
      ),
    );
  }
}
