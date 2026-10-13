import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_config.dart';
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
import '../staff/staff_list_screen.dart';
import '../team/members_screen.dart';
import '../../l10n/app_language.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  void _pickLanguage(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusSheet)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in AppLanguage.supported.entries)
              ListTile(
                title: Text(entry.value),
                trailing: entry.key == AppLanguage.code
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  AppLanguage.instance.set(entry.key);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Same visibility rule PermissionGate applies to each child, lifted to the
  /// group so an empty bordered card never renders.
  bool _anyChildVisible(BuildContext context, List<String> permissions) {
    try {
      final auth = context.watch<AuthProvider>();
      return !auth.isAuthenticated || permissions.any(auth.can);
    } catch (_) {
      // No AuthProvider in scope — everything visible, like PermissionGate.
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GarageProvider>();
    final palette = context.palette;
    final profile = provider.profile;
    final staffItem = _Item(
      icon: Icons.people_outline_rounded,
      title: tr('Staff & payroll'),
      value: '${provider.staff.length}',
      onTap: () => _push(context, const StaffListScreen()),
    );
    final headerDetail = [
      if (profile.gstin.isNotEmpty) 'GSTIN ${profile.gstin}',
      if (profile.city.isNotEmpty) profile.city,
    ].join(' · ');

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: Text(tr('More'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            AppDimens.paddingScreen, 4, AppDimens.paddingScreen, 32),
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
                  headerDetail.isEmpty ? tr('GSTIN and address not set') : headerDetail,
                  style: GoogleFonts.poppins(
                    fontSize: AppText.caption,
                    color: headerDetail.isEmpty ? palette.pending : palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Skip the whole group card when every child is gated off — mirror
          // PermissionGate's visibility rule (mock mode / unauthenticated
          // shows everything, owners bypass, otherwise any one permission).
          if (_anyChildVisible(context, const [
            Permissions.jobcardsManage,
            Permissions.quotationsManage,
            Permissions.expensesManage,
            Permissions.staffManage,
            Permissions.attendanceManage,
          ]))
            _Group(title: tr('Workshop'), children: [
            PermissionGate(
              permission: Permissions.jobcardsManage,
              child: _Item(
                icon: Icons.inventory_2_outlined,
                title: tr('Spare parts & price list'),
                value: '${provider.catalog.length}',
                onTap: () => _push(context, const PriceListScreen()),
              ),
            ),
            PermissionGate(
              permission: Permissions.quotationsManage,
              child: _Item(
                icon: Icons.request_quote_outlined,
                title: tr('Estimates'),
                value: '${provider.quotations.length}',
                onTap: () => _push(context, const QuotationsListScreen()),
              ),
            ),
            PermissionGate(
              permission: Permissions.expensesManage,
              child: _Item(
                icon: Icons.account_balance_wallet_outlined,
                title: tr('Expenses'),
                value: '${CurrencyFormatter.format(provider.thisMonthExpenses)} this month',
                onTap: () => _push(context, const ExpensesListScreen()),
              ),
            ),
            // Attendance and salary live on each staff row, so one entry
            // serves both the staff.manage and attendance.manage roles.
            PermissionGate(
              permission: Permissions.staffManage,
              fallback: PermissionGate(
                permission: Permissions.attendanceManage,
                child: staffItem,
              ),
              child: staffItem,
            ),
          ]),
          PermissionGate(
            permission: Permissions.settingsManage,
            child: _Group(title: tr('Garage'), children: [
              _Item(
                icon: Icons.storefront_outlined,
                title: tr('Garage settings'),
                value: profile.gstin.isEmpty ? tr('Add GSTIN') : null,
                valueColor: palette.pending,
                onTap: () => _push(context, const GarageSettingsScreen()),
              ),
            ]),
          ),
          _Group(title: tr('Language'), children: [
            _Item(
              icon: Icons.translate_rounded,
              title: 'Language / भाषा',
              value: AppLanguage.supported[AppLanguage.code],
              onTap: () => _pickLanguage(context),
            ),
          ]),
          if (!ApiConfig.useMock) const _AccountGroup(),
        ],
      ),
    );
  }
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup();

  /// Sign out behind a confirmation so a stray tap can't end the session.
  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Sign out?')),
        content: Text(
            tr('You will need to sign in again to access this garage.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Sign out')),
          ),
        ],
      ),
    );
    if (ok == true) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final m = auth.currentMembership;
    void push(Widget s) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => s));
    return _Group(
      title: tr('Account'),
      footer: [
        auth.user?.email,
        if (m != null) '${m.role} at ${m.garageName}',
      ].whereType<String>().join(' · '),
      children: [
        _Item(
          icon: Icons.credit_card_outlined,
          title: tr('Subscription'),
          onTap: () => push(const BillingScreen()),
        ),
        _Item(
          icon: Icons.group_outlined,
          title: tr('Team logins'),
          onTap: () => push(const MembersScreen()),
        ),
        _Item(
          icon: Icons.swap_horiz_rounded,
          title: tr('Switch garage'),
          onTap: () => GarageSwitcherSheet.show(context),
        ),
        _Item(
          icon: Icons.logout_rounded,
          title: tr('Sign out'),
          showChevron: false,
          onTap: () => _confirmSignOut(context),
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
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingCard, vertical: AppDimens.paddingCard),
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
