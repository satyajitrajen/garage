import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_config.dart';
import '../../models/staff.dart';
import '../../providers/auth_provider.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/permissions.dart';
import '../../widgets/permission_gate.dart';
import '../auth/garage_switcher.dart';
import '../billing/billing_screen.dart';
import '../catalog/price_list_screen.dart';
import '../expenses/expenses_list_screen.dart';
import '../quotations/quotations_list_screen.dart';
import '../settings/garage_settings_screen.dart';
import '../staff/staff_attendance_screen.dart';
import '../staff/staff_list_screen.dart';
import '../staff/staff_salary_screen.dart';
import '../team/members_screen.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  void _openPayroll(BuildContext context, GarageProvider provider) {
    if (provider.staff.isEmpty) {
      _push(context, const StaffListScreen());
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusSheet)),
      ),
      builder: (ctx) => SafeArea(
        // Scrolls when the roster is taller than the sheet.
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Choose a staff member',
                    style: GoogleFonts.poppins(
                        fontSize: AppText.title, fontWeight: FontWeight.w600)),
              ),
              for (final s in provider.staff)
                ListTile(
                  title: Text(s.name),
                  subtitle: Text(s.role.displayName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.calendar_month_outlined),
                        tooltip: 'Attendance',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _push(context, StaffAttendanceScreen(staff: s));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.receipt_long_outlined),
                        tooltip: 'Salary slip',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _push(context, StaffSalaryScreen(staff: s));
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GarageProvider>();
    final palette = context.palette;
    final profile = provider.profile;
    final headerDetail = [
      if (profile.gstin.isNotEmpty) 'GSTIN ${profile.gstin}',
      if (profile.city.isNotEmpty) profile.city,
    ].join(' · ');

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name,
                    style: GoogleFonts.poppins(
                        fontSize: AppText.headline, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  headerDetail.isEmpty ? 'GSTIN and address not set' : headerDetail,
                  style: GoogleFonts.poppins(
                    fontSize: AppText.caption,
                    color: headerDetail.isEmpty ? palette.pending : palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _Group(title: 'Workshop', children: [
            PermissionGate(
              permission: Permissions.jobcardsManage,
              child: _Item(
                icon: Icons.inventory_2_outlined,
                title: 'Spare parts & price list',
                value: '${provider.catalog.length}',
                onTap: () => _push(context, const PriceListScreen()),
              ),
            ),
            PermissionGate(
              permission: Permissions.quotationsManage,
              child: _Item(
                icon: Icons.request_quote_outlined,
                title: 'Estimates',
                value: '${provider.quotations.length}',
                onTap: () => _push(context, const QuotationsListScreen()),
              ),
            ),
            PermissionGate(
              permission: Permissions.expensesManage,
              child: _Item(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Expenses',
                value: '${CurrencyFormatter.format(provider.thisMonthExpenses)} this month',
                onTap: () => _push(context, const ExpensesListScreen()),
              ),
            ),
            PermissionGate(
              permission: Permissions.staffManage,
              child: _Item(
                icon: Icons.people_outline_rounded,
                title: 'Staff',
                value: '${provider.staff.length}',
                onTap: () => _push(context, const StaffListScreen()),
              ),
            ),
            PermissionGate(
              permission: Permissions.attendanceManage,
              child: _Item(
                icon: Icons.calendar_month_outlined,
                title: 'Attendance & payroll',
                onTap: () => _openPayroll(context, provider),
              ),
            ),
          ]),
          PermissionGate(
            permission: Permissions.settingsManage,
            child: _Group(title: 'Garage', children: [
              _Item(
                icon: Icons.storefront_outlined,
                title: 'Garage settings',
                value: profile.gstin.isEmpty ? 'Add GSTIN' : null,
                valueColor: palette.pending,
                onTap: () => _push(context, const GarageSettingsScreen()),
              ),
            ]),
          ),
          if (!ApiConfig.useMock) const _AccountGroup(),
        ],
      ),
    );
  }
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final m = auth.currentMembership;
    void push(Widget s) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => s));
    return _Group(
      title: 'Account',
      footer: [
        auth.user?.email,
        if (m != null) '${m.role} at ${m.garageName}',
      ].whereType<String>().join(' · '),
      children: [
        _Item(
          icon: Icons.credit_card_outlined,
          title: 'Subscription',
          onTap: () => push(const BillingScreen()),
        ),
        _Item(
          icon: Icons.group_outlined,
          title: 'Team logins',
          onTap: () => push(const MembersScreen()),
        ),
        _Item(
          icon: Icons.swap_horiz_rounded,
          title: 'Switch garage',
          onTap: () => GarageSwitcherSheet.show(context),
        ),
        _Item(
          icon: Icons.logout_rounded,
          title: 'Sign out',
          showChevron: false,
          onTap: auth.logout,
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children, this.footer});
  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: AppText.caption,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary)),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: palette.border),
            ),
            child: Column(children: [
              for (var i = 0; i < children.length; i++)
                i == 0 ? children[i] : _Divided(child: children[i]),
            ]),
          ),
          if (footer != null && footer!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(footer!,
                  style: GoogleFonts.poppins(
                      fontSize: AppText.label, color: palette.textMuted)),
            ),
        ],
      ),
    );
  }
}

class _Divided extends StatelessWidget {
  const _Divided({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.palette.divider)),
        ),
        child: child,
      );
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.valueColor,
    this.showChevron = true,
  });
  final IconData icon;
  final String title;
  final String? value;
  final Color? valueColor;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: AppText.body, fontWeight: FontWeight.w500)),
            ),
            if (value != null)
              Flexible(
                child: Text(value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.poppins(
                        fontSize: AppText.caption,
                        color: valueColor ?? palette.textMuted)),
              ),
            if (showChevron) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: palette.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}
