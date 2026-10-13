import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../customers/add_customer_screen.dart';
import '../customers/customers_list_screen.dart';
import 'create_job_card_screen.dart';
import '../../l10n/app_language.dart';

/// "New job card" starts from the car, the way a garage counter works: type
/// the plate, pick the vehicle (its owner comes with it), or add it with the
/// plate already filled in.
class StartJobScreen extends StatefulWidget {
  const StartJobScreen({super.key});

  @override
  State<StartJobScreen> createState() => _StartJobScreenState();
}

class _StartJobScreenState extends State<StartJobScreen> {
  final _plate = TextEditingController();

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  void _open(Customer customer, Vehicle vehicle) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobCardScreen(customer: customer, vehicle: vehicle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GarageProvider>();
    final palette = context.palette;
    final query = GarageProvider.normalizeRegistration(_plate.text);

    final matches = query.isEmpty
        ? <Vehicle>[]
        : provider.vehicles
            .where((v) =>
                GarageProvider.normalizeRegistration(v.registrationNumber)
                    .contains(query))
            .take(20)
            .toList();
    final exact = matches.any(
        (v) => GarageProvider.normalizeRegistration(v.registrationNumber) == query);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Start a job'))),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.paddingScreen),
        children: [
          Text(
            tr('Which car is in?'),
            style: GoogleFonts.poppins(
                fontSize: AppText.title, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            tr('Type the registration number. Returning cars come with their owner and history.'),
            style: GoogleFonts.poppins(
                fontSize: AppText.caption, color: palette.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _plate,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            style: GoogleFonts.poppins(
                fontSize: AppText.title,
                fontWeight: FontWeight.w600,
                letterSpacing: 1),
            decoration: const InputDecoration(
              hintText: 'e.g. MH12AB1234',
              prefixIcon: Icon(Icons.pin_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          for (final v in matches) _vehicleTile(provider, palette, v),
          if (query.length >= 4 && !exact) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: palette.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.add_rounded, color: palette.primary),
                ),
                title: Text('Add ${_plate.text.trim().toUpperCase()}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text(tr('New car: enter the owner and vehicle details')),
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddCustomerScreen(
                      startJobImmediately: true,
                      initialRegistration: _plate.text.trim().toUpperCase(),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const CustomersListScreen(isSelectionMode: true),
                ),
              ),
              icon: const Icon(Icons.people_alt_outlined, size: 18),
              label: Text(tr('Pick from customers instead')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleTile(GarageProvider provider, AppPalette palette, Vehicle v) {
    final owner = provider.getCustomerById(v.customerId);
    final openJob = provider.activeJobCards.any((jc) => jc.vehicleId == v.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: palette.cardAlt,
          child: Icon(Icons.directions_car_filled_rounded, color: palette.textPrimary),
        ),
        title: Text(v.registrationNumber,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        subtitle: Text([
          v.displayName,
          if (owner != null) owner.name,
          if (openJob) 'already in the workshop',
        ].join(' · ')),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: owner == null ? null : () => _open(owner, v),
      ),
    );
  }
}
