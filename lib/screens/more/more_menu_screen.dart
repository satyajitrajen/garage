import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../expenses/expenses_list_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../quotations/quotations_list_screen.dart';
import '../../models/staff.dart';
import '../staff/staff_list_screen.dart';
import '../staff/staff_attendance_screen.dart';
import '../staff/staff_salary_screen.dart';
import '../workflow/quick_service_wizard.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final profile = provider.profile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(
          'More Options',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              provider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => provider.toggleTheme(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Workshop banner (Gradient - No Black)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? AppColors.cardGradientDark
                    : AppColors.cardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.blueGradient,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.car_repair_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'GSTIN: ${profile.gstin} • ${profile.city}',
                        style: GoogleFonts.poppins(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. Quick Service Flow Banner (Iridescent Pastel Gradient)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuickServiceWizard()),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? AppColors.cardGradientDark
                        : AppColors.bannerGradient,
                    stops: AppColors.bannerGradientStops,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA7F3D0).withValues(alpha: isDark ? 0.2 : 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF121726),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Service Wizard',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Step-by-step: Customer → Vehicle → Service → Bill',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionTitle(context, 'WORKSHOP MODULES'),
          const SizedBox(height: 8),

          _buildMenuTile(
            context,
            icon: Icons.request_quote_rounded,
            badgeBg: AppColors.badgeOrangeBg,
            color: AppColors.badgeOrangeIcon,
            title: 'Quotations / Estimates',
            subtitle: '${provider.quotations.length} pre-service cost estimates created',
            trailing: '${provider.quotations.length}',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuotationsListScreen()),
              );
            },
          ),
          const SizedBox(height: 8),

          _buildMenuTile(
            context,
            icon: Icons.account_balance_wallet_rounded,
            badgeBg: AppColors.badgeRedBg,
            color: AppColors.badgeRedIcon,
            title: 'Garage Expenses',
            subtitle: "Today: ${CurrencyFormatter.format(provider.todayExpenses)} • Month: ${CurrencyFormatter.formatCompact(provider.thisMonthExpenses)}",
            trailing: '${provider.expenses.length}',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpensesListScreen()),
              );
            },
          ),
          const SizedBox(height: 8),

          _buildMenuTile(
            context,
            icon: Icons.badge_rounded,
            badgeBg: AppColors.badgeBlueBg,
            color: AppColors.badgeBlueIcon,
            title: 'Staff Directory & Roles',
            subtitle: '${provider.staff.length} team members (Mechanics, Electricians)',
            trailing: '${provider.staff.length}',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffListScreen()),
              );
            },
          ),
          const SizedBox(height: 8),

          _buildMenuTile(
            context,
            icon: Icons.calendar_month_rounded,
            badgeBg: AppColors.badgePurpleBg,
            color: AppColors.badgePurpleIcon,
            title: 'Attendance & Payroll Slips',
            subtitle: 'Daily attendance calendar & net salary calculator',
            onTap: () {
              if (provider.staff.isEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffListScreen()),
                );
                return;
              }
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Staff Member', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Choose a member to view attendance calendar or salary slip', style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textMuted)),
                        const SizedBox(height: 16),
                        ...provider.staff.map((s) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: Text(s.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ),
                          title: Text(s.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          subtitle: Text(s.role.displayName),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                                tooltip: 'Attendance',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => StaffAttendanceScreen(staff: s)));
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.receipt_long_rounded, color: AppColors.accent),
                                tooltip: 'Salary Slip',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => StaffSalaryScreen(staff: s)));
                                },
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          _buildSectionTitle(context, 'PREFERENCES & ACTIONS'),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.border,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.badgeBlueBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      provider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppColors.badgeBlueIcon,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    'Dark Mode Theme',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    provider.isDarkMode ? 'Dark slate theme enabled' : 'Light porcelain theme enabled',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                  value: provider.isDarkMode,
                  onChanged: (_) => provider.toggleTheme(),
                  activeTrackColor: AppColors.accent,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.badgeGreenBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_circle_outline_rounded, color: AppColors.badgeGreenIcon, size: 18),
                  ),
                  title: Text(
                    'Quick Expense Entry',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    'Add workshop expense receipt',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required Color badgeBg,
    required Color color,
    required String title,
    required String subtitle,
    String? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trailing,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right_rounded, size: 18),
      ),
    );
  }
}
