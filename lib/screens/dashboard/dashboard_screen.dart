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
import '../../widgets/status_badge.dart';
import '../../widgets/subscription_banner.dart';
import '../customers/customer_detail_screen.dart';
import '../customers/customers_list_screen.dart';
import '../invoices/invoice_preview_screen.dart';
import '../invoices/invoices_list_screen.dart';
import '../job_cards/job_card_detail_screen.dart';
import '../job_cards/job_cards_list_screen.dart';
import '../workflow/quick_service_wizard.dart';
import '../../utils/error_message.dart';

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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const SubscriptionBanner(),
            TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search plate, phone or name',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
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
                    child: ElevatedButton.icon(
                      onPressed: () => _push(
                          const CustomersListScreen(isSelectionMode: true)),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New job card'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _push(const QuickServiceWizard()),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('Quick bill'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _MoneyToday(provider: provider),
              const SizedBox(height: 24),
              _SectionTitle(
                'In the workshop',
                count: provider.activeJobCards.length,
                action: 'All jobs',
                onAction: () => _push(const JobCardsListScreen()),
              ),
              _workshopList(provider, palette),
              const SizedBox(height: 24),
              _SectionTitle(
                'Recent bills',
                action: 'All bills',
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
          child: Column(
            children: [
              Text('No match for "$_query"',
                  style: GoogleFonts.poppins(color: palette.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _push(const CustomersListScreen()),
                child: const Text('Add a customer'),
              ),
            ],
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
      return const _Empty('No vehicles in the workshop.');
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
              color: late ? palette.absent : palette.textMuted,
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
    if (bills.isEmpty) return const _Empty('No bills yet.');
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
                      fontSize: AppText.body, fontWeight: FontWeight.w600)),
              Text(
                switch (inv.status) {
                  InvoiceStatus.paid => 'Paid',
                  InvoiceStatus.cancelled => 'Cancelled',
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
            borderRadius: BorderRadius.circular(8),
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
                            fontSize: AppText.title,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ),
                ],
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          figure('Collected today', provider.todayCollection, palette.textPrimary),
          figure('Spent today', provider.todayExpenses, palette.textPrimary),
          figure(
            'Due from customers',
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
            if (i > 0) Divider(height: 1, indent: 14, color: palette.divider),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
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
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: trailing!,
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
            style: GoogleFonts.poppins(color: context.palette.textMuted)),
      );
}
