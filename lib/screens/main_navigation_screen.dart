import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/garage_provider.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';
import 'dashboard/dashboard_screen.dart';
import 'job_cards/job_cards_list_screen.dart';
import 'customers/customers_list_screen.dart';
import 'invoices/invoices_list_screen.dart';
import 'more/more_menu_screen.dart';
import '../../theme/app_text.dart';
import '../l10n/app_language.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    DashboardScreen(),
    JobCardsListScreen(),
    CustomersListScreen(),
    InvoicesListScreen(),
    MoreMenuScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final palette = context.palette;

    final activeVehiclesCount = provider.activeVehiclesUnderMaintenanceCount;
    final pendingInvoicesCount = provider.invoices.where((i) => i.balanceDue > 0).length;

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (provider.loadError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: palette.absent),
              const SizedBox(height: 12),
              Text(
                tr('Failed to load garage data'),
                style: GoogleFonts.poppins(
                  fontSize: AppText.title,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: provider.load, child: Text(tr('Retry'))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusSheet),
              border: Border.all(color: palette.border, width: 1),
              boxShadow: AppDimens.cardShadow(palette.textPrimary),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: tr('Home'),
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.car_repair_outlined,
                  selectedIcon: Icons.car_repair_rounded,
                  label: tr('Jobs'),
                  badgeCount: activeVehiclesCount,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.people_alt_outlined,
                  selectedIcon: Icons.people_alt_rounded,
                  label: tr('Customers'),
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long_rounded,
                  label: tr('Bills'),
                  badgeCount: pendingInvoicesCount,
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.menu_rounded,
                  selectedIcon: Icons.density_medium_rounded,
                  label: tr('More'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          borderRadius: BorderRadius.circular(AppDimens.radiusSheet),
          child: SizedBox(
            height: 56,
            // Scale the icon + label down to fit with large system text.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              // The selected tab is one black pill around icon and label.
              child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? context.palette.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isSelected ? selectedIcon : icon,
                        size: 20,
                        color: isSelected
                            ? context.palette.onPrimary
                            : context.palette.textSecondary,
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          top: -3,
                          right: -5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.palette.pending,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${badgeCount > 9 ? '9+' : badgeCount}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: AppText.micro,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: context.palette.onPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: AppText.micro,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? context.palette.onPrimary
                        : context.palette.textSecondary,
                  ),
                ),
              ],
            ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
