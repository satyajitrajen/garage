import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/job_card.dart';
import '../../models/vehicle.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/permissions.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/permission_gate.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/subscription_banner.dart';
import '../customers/customer_detail_screen.dart';
import '../customers/customers_list_screen.dart';
import '../invoices/invoice_preview_screen.dart';
import '../invoices/invoices_list_screen.dart';
import '../job_cards/job_card_detail_screen.dart';
import '../job_cards/job_cards_list_screen.dart';
import '../job_cards/start_job_screen.dart';
import '../catalog/price_list_screen.dart';
import '../settings/garage_settings_screen.dart';
import '../workflow/quick_service_wizard.dart';
import '../../utils/error_message.dart';
import '../../l10n/app_language.dart';

/// Home: find a car, start work, see what's on the floor and what's owed.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _refresh() async {
    try {
      await context.read<GarageProvider>().refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e),
          type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GarageProvider>();
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(provider.profile.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              AppDateFormatter.formatDayDate(DateTime.now()),
              style: GoogleFonts.poppins(
                  fontSize: AppText.label, color: palette.textMuted),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppDimens.paddingScreen, 4, AppDimens.paddingScreen, 24),
          children: [
            const SubscriptionBanner(),
            TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: tr('Search plate, phone or name'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: tr('Clear'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (_query.isNotEmpty)
              ..._searchResults(provider, palette)
            else ...[
              Row(
                children: [
                  Expanded(
                    child: PermissionGate(
                      permission: Permissions.jobcardsManage,
                      child: ElevatedButton.icon(
                        onPressed: () => _push(const StartJobScreen()),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(tr('New job card')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PermissionGate(
                      permission: Permissions.invoicesManage,
                      child: OutlinedButton.icon(
                        onPressed: () => _push(const QuickServiceWizard()),
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: Text(tr('Quick bill')),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SetupCard(provider: provider, push: _push),
              _MoneyToday(provider: provider),
              const SizedBox(height: 24),
              _SectionTitle(
                tr('In the workshop'),
                count: provider.activeJobCards.length,
                action: tr('All jobs'),
                onAction: () => _push(const JobCardsListScreen()),
              ),
              _workshopList(provider, palette),
              const SizedBox(height: 24),
              _SectionTitle(
                tr('Recent bills'),
                action: tr('All bills'),
                onAction: () => _push(const InvoicesListScreen()),
              ),
              _billsList(provider, palette),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _searchResults(GarageProvider provider, AppPalette palette) {
    final q = _query.toLowerCase();
    final plateQ = q.replaceAll(' ', '');
    final vehicles = provider.vehicles
        .where((v) =>
            v.registrationNumber.toLowerCase().replaceAll(' ', '').contains(plateQ))
        .take(8)
        .toList();
    final customers = provider.customers
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.phone.replaceAll(' ', '').contains(plateQ))
        .take(8)
        .toList();
    if (vehicles.isEmpty && customers.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: EmptyStateWidget(
            icon: Icons.search_off_rounded,
            title: 'No results found for "$_query"',
            description: tr('Try a different plate, phone number or name.'),
            buttonText: tr('Add a customer'),
            onButtonPressed: () => _push(const CustomersListScreen()),
          ),
        ),
      ];
    }
    return [
      _Group(children: [
        for (final v in vehicles)
          _vehicleRow(v, provider.getCustomerById(v.customerId), palette),
        for (final c in customers)
          _Row(
            title: c.name,
            subtitle: c.phone,
            onTap: () => _push(CustomerDetailScreen(customer: c)),
          ),
      ]),
    ];
  }

  Widget _vehicleRow(Vehicle v, Customer? owner, AppPalette palette) => _Row(
        title: v.registrationNumber,
        subtitle: [v.displayName, if (owner != null) owner.name].join(' · '),
        onTap: owner == null
            ? null
            : () => _push(CustomerDetailScreen(customer: owner)),
      );

  Widget _workshopList(GarageProvider provider, AppPalette palette) {
    final jobs = provider.activeJobCards
      ..sort((a, b) => a.promisedDeliveryDate.compareTo(b.promisedDeliveryDate));
    if (jobs.isEmpty) {
      return _Empty(tr('No vehicles in the workshop.'));
    }
    return _Group(children: [
      for (final jc in jobs.take(5)) _jobRow(jc, provider, palette),
    ]);
  }

  Widget _jobRow(JobCard jc, GarageProvider provider, AppPalette palette) {
    final v = provider.getVehicleById(jc.vehicleId);
    final c = provider.getCustomerById(jc.customerId);
    final late = jc.promisedDeliveryDate.isBefore(DateTime.now());
    return _Row(
      title: v?.registrationNumber ?? jc.jobCardNumber,
      subtitle: [v?.displayName, c?.name].whereType<String>().join(' · '),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge.fromJobStatus(jc.status),
          const SizedBox(height: 4),
          Text(
            late
                ? 'Late · ${AppDateFormatter.formatTime(jc.promisedDeliveryDate)}'
                : 'Due ${AppDateFormatter.formatRelative(jc.promisedDeliveryDate)}',
            style: GoogleFonts.poppins(
              fontSize: AppText.label,
              color: late ? palette.pending : palette.textMuted,
              fontWeight: late ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
      onTap: () => _push(JobCardDetailScreen(jobCardId: jc.id)),
    );
  }

  Widget _billsList(GarageProvider provider, AppPalette palette) {
    final bills = provider.recentInvoices.take(4).toList();
    if (bills.isEmpty) return _Empty(tr('No bills yet.'));
    return _Group(children: [
      for (final inv in bills)
        _Row(
          title: provider.getCustomerById(inv.customerId)?.name ??
              inv.invoiceNumber,
          subtitle:
              '${inv.invoiceNumber} · ${AppDateFormatter.formatShortDate(inv.invoiceDate)}',
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(CurrencyFormatter.format(inv.grandTotal),
                  style: GoogleFonts.poppins(
                      fontSize: AppText.subtitle,
                      fontWeight: FontWeight.w600)),
              Text(
                switch (inv.status) {
                  InvoiceStatus.paid => tr('Paid'),
                  InvoiceStatus.cancelled => tr('Cancelled'),
                  _ => '${CurrencyFormatter.format(inv.balanceDue)} due',
                },
                style: GoogleFonts.poppins(
                  fontSize: AppText.label,
                  color: switch (inv.status) {
                    InvoiceStatus.paid => palette.paid,
                    InvoiceStatus.cancelled => palette.textMuted,
                    _ => palette.pending,
                  },
                ),
              ),
            ],
          ),
          onTap: () => _push(InvoicePreviewScreen(invoiceId: inv.id)),
        ),
    ]);
  }
}

/// First-run guide: three steps that make the garage ready to bill. Each
/// ticks itself off from real data and the card disappears once all are done.
class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.provider, required this.push});
  final GarageProvider provider;
  final void Function(Widget) push;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = provider.profile;
    final steps = [
      (
        tr('Add your garage details'),
        tr('Address and GSTIN print on every bill'),
        p.addressLine.trim().isNotEmpty || p.gstin.trim().isNotEmpty,
        const GarageSettingsScreen() as Widget,
      ),
      (
        tr('Add your common parts and labour'),
        tr('Save prices once, add them to any job in a tap'),
        provider.catalog.isNotEmpty,
        const PriceListScreen() as Widget,
      ),
      (
        tr('Open your first job'),
        "Start with the car's registration number",
        provider.jobCards.isNotEmpty,
        const StartJobScreen() as Widget,
      ),
    ];
    final done = steps.where((s) => s.$3).length;
    if (done == steps.length) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusTile),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(tr('Get set up'),
                      style: GoogleFonts.poppins(
                          fontSize: AppText.subtitle,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary)),
                ),
                Text('$done of ${steps.length} done',
                    style: GoogleFonts.poppins(
                        fontSize: AppText.label, color: palette.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: done / steps.length,
                minHeight: 6,
                backgroundColor: palette.border,
                color: palette.paid,
              ),
            ),
            const SizedBox(height: 4),
            for (final s in steps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.$3 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: s.$3 ? palette.paid : palette.textSecondary,
                ),
                title: Text(s.$1,
                    style: GoogleFonts.poppins(
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w600,
                      color: s.$3 ? palette.textSecondary : palette.textPrimary,
                      decoration: s.$3 ? TextDecoration.lineThrough : null,
                    )),
                subtitle: s.$3 ? null : Text(s.$2),
                trailing: s.$3 ? null : const Icon(Icons.chevron_right_rounded),
                onTap: s.$3 ? null : () => push(s.$4),
              ),
          ],
        ),
      ),
    );
  }
}

/// Today's money in three plain figures. Tapping "Due" opens the bills list.
class _MoneyToday extends StatelessWidget {
  const _MoneyToday({required this.provider});
  final GarageProvider provider;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget figure(String label, double value, Color color, {VoidCallback? onTap}) =>
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: AppText.label, color: palette.textMuted)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(CurrencyFormatter.format(value),
                        style: GoogleFonts.poppins(
                            fontSize: AppText.headline,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ),
                ],
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingCard),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          figure(tr('Collected today'), provider.todayCollection, palette.textPrimary),
          figure(tr('Spent today'), provider.todayExpenses, palette.textPrimary),
          figure(
            tr('Due from customers'),
            provider.totalPendingPayments,
            provider.totalPendingPayments > 0 ? palette.pending : palette.textPrimary,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const InvoicesListScreen())),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.count, this.action, this.onAction});
  final String title;
  final int? count;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null ? title : '$title ($count)',
              style: GoogleFonts.poppins(
                  fontSize: AppText.body, fontWeight: FontWeight.w600),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// A bordered group of divided rows: dense, scannable, one surface.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1, indent: AppDimens.paddingCard, color: palette.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle, this.trailing, this.onTap});
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingCard, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: AppText.body, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: AppText.label, color: palette.textSecondary)),
                ],
              ),
            ),
            // Scale the trailing block down rather than overflow on narrow
            // screens or with large text.
            if (trailing != null) ...[
              const SizedBox(width: 12),
              // Tight + right-aligned: a loose Flexible left the unused
              // half of its slot empty after the amount, so amounts floated
              // mid-row instead of lining up on the right edge.
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: trailing!,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: AppText.body, color: context.palette.textMuted)),
      );
}
