import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/garage_provider.dart';
import '../theme/app_colors.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/quotations/quotations_list_screen.dart';
import '../screens/expenses/expenses_list_screen.dart';
import '../screens/staff/staff_list_screen.dart';
import '../screens/workflow/quick_service_wizard.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          // Drawer Header with Garage Branding
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.car_repair_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nexory Garage',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Multi-Brand Auto Care',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              children: [
                _buildNavItem(
                  context,
                  title: 'Dashboard',
                  icon: Icons.dashboard_rounded,
                  route: 'dashboard',
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != 'dashboard') {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 0)),
                        (route) => false,
                      );
                    }
                  },
                ),
                _buildNavItem(
                  context,
                  title: 'Customers Fleet',
                  icon: Icons.people_alt_rounded,
                  route: 'customers',
                  badgeCount: provider.customers.length,
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != 'customers') {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 2)),
                        (route) => false,
                      );
                    }
                  },
                ),
                _buildNavItem(
                  context,
                  title: 'Job Cards / Floor',
                  icon: Icons.assignment_rounded,
                  route: 'job_cards',
                  badgeCount: provider.activeVehiclesUnderMaintenanceCount,
                  badgeColor: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != 'job_cards') {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 1)),
                        (route) => false,
                      );
                    }
                  },
                ),
                _buildNavItem(
                  context,
                  title: 'Quotations & Estimates',
                  icon: Icons.request_quote_rounded,
                  route: 'quotations',
                  badgeCount: provider.quotations.length,
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != 'quotations') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QuotationsListScreen()),
                      );
                    }
                  },
                ),
                _buildNavItem(
                  context,
                  title: 'Invoices & Billing',
                  icon: Icons.receipt_long_rounded,
                  route: 'invoices',
                  badgeCount: provider.invoices.length,
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != 'invoices') {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 3)),
                        (route) => false,
                      );
                    }
                  },
                ),
                _buildNavItem(
                  context,
                  title: 'Garage Expenses',
                  icon: Icons.account_balance_wallet_rounded,
                  route: 'expenses',
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != 'expenses') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ExpensesListScreen()),
                      );
                    }
                  },
                ),
                _buildNavItem(
                  context,
                  title: 'Staff & Attendance',
                  icon: Icons.badge_rounded,
                  route: 'staff',
                  badgeCount: provider.staff.length,
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != 'staff') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StaffListScreen()),
                      );
                    }
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Divider(),
                ),
                _buildNavItem(
                  context,
                  title: 'Quick Service Flow',
                  icon: Icons.bolt_rounded,
                  route: 'wizard',
                  iconColor: AppColors.primary,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuickServiceWizard()),
                    );
                  },
                ),
              ],
            ),
          ),

          // Bottom Bar with Dark Mode Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isDark ? 'Dark Theme' : 'Light Theme',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: provider.isDarkMode,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => provider.toggleTheme(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    required VoidCallback onTap,
    int? badgeCount,
    Color? badgeColor,
    Color? iconColor,
  }) {
    final isSelected = currentRoute == route;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        dense: true,
        leading: Icon(
          icon,
          color: isSelected
              ? AppColors.primary
              : (iconColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white : AppColors.textPrimary),
          ),
        ),
        trailing: badgeCount != null && badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor != null ? Colors.white : (isDark ? Colors.white : const Color(0xFF475569)),
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
