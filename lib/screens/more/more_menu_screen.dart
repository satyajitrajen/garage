import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/api/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/permissions.dart';
import '../../widgets/permission_gate.dart';
import '../auth/garage_switcher.dart';
import '../billing/billing_screen.dart';
import '../team/members_screen.dart';
import '../expenses/expenses_list_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../quotations/quotations_list_screen.dart';
import '../../models/staff.dart';
import '../staff/staff_list_screen.dart';
import '../staff/staff_attendance_screen.dart';
import '../staff/staff_salary_screen.dart';
import '../workflow/quick_service_wizard.dart';
import '../../theme/app_text.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final profile = provider.profile;
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'More Options',
          style: GoogleFonts.inter(
            fontSize: AppText.title,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Workshop banner (brand gradient)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette.cardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppDimens.accentGlow(palette.accent),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: palette.brandGradient,
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
                        style: GoogleFonts.inter(
                          color: palette.textPrimary,
                          fontSize: AppText.subtitle,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'GSTIN: ${profile.gstin} • ${profile.city}',
                        style: GoogleFonts.inter(
                          color: palette.textSecondary,
                          fontSize: AppText.label,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. Quick Service Flow Banner (Brand Gradient)
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
                    colors: palette.brandGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                  boxShadow: AppDimens.accentGlow(palette.primary),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
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
                            style: GoogleFonts.inter(
                              fontSize: AppText.body,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Step-by-step: Customer → Vehicle → Service → Bill',
                            style: GoogleFonts.inter(
                              fontSize: AppText.label,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionTitle(context, 'WORKSHOP MODULES'),
          const SizedBox(height: 8),

          PermissionGate(
            permission: Permissions.quotationsManage,
            child: _buildMenuTile(
              context,
              icon: Icons.request_quote_rounded,
              badgeBg: palette.badgeOrangeBg,
              color: palette.badgeOrangeIcon,
              title: 'Quotations / Estimates',
              subtitle:
                  '${provider.quotations.length} pre-service cost estimates created',
              trailing: '${provider.quotations.length}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const QuotationsListScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          PermissionGate(
            permission: Permissions.expensesManage,
            child: _buildMenuTile(
              context,
              icon: Icons.account_balance_wallet_rounded,
              badgeBg: palette.badgeRedBg,
              color: palette.badgeRedIcon,
              title: 'Garage Expenses',
              subtitle:
                  "Today: ${CurrencyFormatter.format(provider.todayExpenses)} • Month: ${CurrencyFormatter.formatCompact(provider.thisMonthExpenses)}",
              trailing: '${provider.expenses.length}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ExpensesListScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          PermissionGate(
            permission: Permissions.staffManage,
            child: _buildMenuTile(
              context,
              icon: Icons.badge_rounded,
              badgeBg: palette.badgeBlueBg,
              color: palette.badgeBlueIcon,
              title: 'Staff Directory & Roles',
              subtitle:
                  '${provider.staff.length} team members (Mechanics, Electricians)',
              trailing: '${provider.staff.length}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffListScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          PermissionGate(
            permission: Permissions.attendanceManage,
            child: _buildMenuTile(
              context,
              icon: Icons.calendar_month_rounded,
              badgeBg: palette.badgePurpleBg,
              color: palette.badgePurpleIcon,
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
                        Text('Select Staff Member', style: GoogleFonts.inter(fontSize: AppText.title, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Choose a member to view attendance calendar or salary slip', style: GoogleFonts.inter(fontSize: AppText.caption, color: palette.textMuted)),
                        const SizedBox(height: 16),
                        ...provider.staff.map((s) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: palette.primary.withValues(alpha: 0.12),
                            child: Text(s.name.substring(0, 1).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: palette.primary)),
                          ),
                          title: Text(s.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          subtitle: Text(s.role.displayName),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.calendar_month_rounded, color: palette.primary),
                                tooltip: 'Attendance',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => StaffAttendanceScreen(staff: s)));
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.receipt_long_rounded, color: palette.accent),
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
          ),
          const SizedBox(height: 20),

          _buildSectionTitle(context, 'PREFERENCES & ACTIONS'),
          const SizedBox(height: 8),

          PermissionGate(
            permission: Permissions.expensesManage,
            child: Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: palette.border,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: palette.badgeGreenBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.add_circle_outline_rounded,
                          color: palette.badgeGreenIcon, size: 18),
                    ),
                    title: Text(
                      'Quick Expense Entry',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: AppText.body),
                    ),
                    subtitle: Text(
                      'Add workshop expense receipt',
                      style: GoogleFonts.inter(
                          fontSize: AppText.label, color: palette.textMuted),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () {
                      if (!ensurePermission(
                          context, Permissions.expensesManage)) {
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddExpenseScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (!ApiConfig.useMock) ...[
            const SizedBox(height: 20),
            _buildSectionTitle(context, 'ACCOUNT'),
            const SizedBox(height: 8),
            _AccountSection(),
          ],
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
        style: GoogleFonts.inter(
          fontSize: AppText.label,
          fontWeight: FontWeight.w600,
          color: context.palette.textMuted,
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
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.palette.border,
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
            borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: AppText.body),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: AppText.label,
            color: context.palette.textSecondary,
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
                  style: GoogleFonts.inter(
                    fontSize: AppText.label,
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

class _AccountSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final palette = context.palette;
    final m = auth.currentMembership;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text((auth.user?.name.isNotEmpty ?? false)
                  ? auth.user!.name[0].toUpperCase()
                  : '?'),
            ),
            title: Text(auth.user?.name ?? 'Account',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${auth.user?.email ?? ''}${m == null ? '' : ' • ${m.role} • ${m.garageName}'}',
              style: GoogleFonts.inter(
                  fontSize: AppText.label, color: palette.textMuted),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.card_membership_rounded),
            title: const Text('Subscription & billing'),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BillingScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.group_rounded),
            title: const Text('Team logins'),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MembersScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Switch garage'),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () => GarageSwitcherSheet.show(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: () => auth.logout(),
          ),
        ],
      ),
    );
  }
}
