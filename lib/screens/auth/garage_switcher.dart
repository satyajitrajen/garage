import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';

/// Garage switcher for multi-garage accounts. Switching reloads all data.
class GarageSwitcherSheet extends StatelessWidget {
  const GarageSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const GarageSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Switch garage',
                style: GoogleFonts.poppins(
                    fontSize: AppText.title, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Signed in as ${auth.user?.name ?? ''} (${auth.user?.email ?? ''})',
              style: GoogleFonts.poppins(
                  fontSize: AppText.caption, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: auth.memberships.length,
                itemBuilder: (ctx, i) {
                  final m = auth.memberships[i];
                  final selected = m.garageId == auth.garageId;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(m.garageName.isEmpty
                          ? '?'
                          : m.garageName[0].toUpperCase()),
                    ),
                    title: Text(m.garageName,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${m.role}${m.isActive ? '' : ' • deactivated'}'),
                    trailing:
                        selected ? const Icon(Icons.check_rounded) : null,
                    selected: selected,
                    onTap: () async {
                      if (selected) {
                        Navigator.pop(context);
                        return;
                      }
                      Navigator.pop(context);
                      await auth.selectGarage(m.garageId);
                      if (!context.mounted) return;
                      try {
                        await context.read<GarageProvider>().load();
                      } catch (_) {
                        if (!context.mounted) return;
                        showAppSnackBar(
                            context, 'Switched garage but reload failed.',
                            type: SnackBarType.error);
                      }
                    },
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.pop(context);
                await context.read<AuthProvider>().logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
