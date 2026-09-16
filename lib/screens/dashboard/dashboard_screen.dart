import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/invoice.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/book_service_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/subscription_banner.dart';
import '../customers/customers_list_screen.dart';
import '../job_cards/job_cards_list_screen.dart';
import '../job_cards/job_card_detail_screen.dart';
import '../quotations/quotations_list_screen.dart';
import '../invoices/invoices_list_screen.dart';
import '../invoices/invoice_preview_screen.dart';
import '../expenses/expenses_list_screen.dart';
import '../staff/staff_list_screen.dart';
import '../workflow/quick_service_wizard.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final palette = context.palette;

    final today = DateTime.now();
    final activeJobs = provider.activeJobCards;
    final recentInvoices = provider.recentInvoices;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: palette.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.car_repair_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: AppText.title,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    AppDateFormatter.formatDayDate(today),
                    style: GoogleFonts.inter(
                      fontSize: AppText.label,
                      fontWeight: FontWeight.w500,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.flash_on_rounded, color: palette.primary, size: 22),
            tooltip: 'Quick Service Wizard',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuickServiceWizard()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await context.read<GarageProvider>().refresh();
          } catch (e) {
            if (!context.mounted) return;
            showAppSnackBar(
              context,
              e.toString().replaceFirst('Exception: ', ''),
              type: SnackBarType.error,
            );
          }
        },
        child: SingleChildScrollView(
          // Always scrollable so pull-to-refresh works even when the content
          // fits the viewport.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // SaaS subscription status (hidden when active / mock mode).
              const SubscriptionBanner(),

              // -------------------------------------------------------------
              // 1. BOOK A SERVICE (HERO)
              // -------------------------------------------------------------
              const BookServiceCard(),
              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // 2. TODAY CARD (COLLECTION / EXPENSES / SPARKLINE / DUES)
              // -------------------------------------------------------------
              _buildTodayCard(context, provider, palette),
              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // 3. LIVE FLOOR (ACTIVE VEHICLES)
              // -------------------------------------------------------------
              SectionHeader(
                title: 'Live Floor',
                actionText: 'View All (${activeJobs.length})',
                onActionTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JobCardsListScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildLiveFloorStrip(context, provider, palette),
              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // 4. WORKSHOP MODULES SHORTCUTS (6 TILES)
              // -------------------------------------------------------------
              Text(
                'Workshop Modules',
                style: GoogleFonts.inter(
                  fontSize: AppText.body,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.05,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildModuleTile(
                    context,
                    title: 'Customers',
                    icon: Icons.people_alt_rounded,
                    count: '${provider.customers.length}',
                    color: palette.accent,
                    badgeBg: palette.badgeBlueBg,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersListScreen())),
                  ),
                  _buildModuleTile(
                    context,
                    title: 'Job Cards',
                    icon: Icons.assignment_rounded,
                    count: '${provider.activeVehiclesUnderMaintenanceCount}',
                    color: palette.badgePurpleIcon,
                    badgeBg: palette.badgePurpleBg,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobCardsListScreen())),
                  ),
                  _buildModuleTile(
                    context,
                    title: 'Quotations',
                    icon: Icons.request_quote_rounded,
                    count: '${provider.quotations.length}',
                    color: palette.badgeOrangeIcon,
                    badgeBg: palette.badgeOrangeBg,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuotationsListScreen())),
                  ),
                  _buildModuleTile(
                    context,
                    title: 'Invoices',
                    icon: Icons.receipt_long_rounded,
                    count: '${provider.invoices.length}',
                    color: palette.paid,
                    badgeBg: palette.badgeGreenBg,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesListScreen())),
                  ),
                  _buildModuleTile(
                    context,
                    title: 'Expenses',
                    icon: Icons.account_balance_wallet_rounded,
                    count: '${provider.expenses.length}',
                    color: palette.pending,
                    badgeBg: palette.badgeRedBg,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesListScreen())),
                  ),
                  _buildModuleTile(
                    context,
                    title: 'Staff Team',
                    icon: Icons.badge_rounded,
                    count: '${provider.staff.length}',
                    color: palette.primary,
                    badgeBg: palette.badgeBlueBg,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffListScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // 5. RECENT COLLECTIONS & BILLS
              // -------------------------------------------------------------
              SectionHeader(
                title: 'Recent Collections & Bills',
                actionText: 'All Invoices',
                onActionTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InvoicesListScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),

              ...recentInvoices.take(3).map((inv) {
                final customer = provider.getCustomerById(inv.customerId);
                final vehicle = provider.getVehicleById(inv.vehicleId);
                // A cancelled invoice zeroes out its balance, so the paid/settled
                // branch below must never claim it — check cancellation first.
                final isCancelled = inv.status == InvoiceStatus.cancelled;
                final hasDue = !isCancelled && inv.balanceDue > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                    border: Border.all(
                      color: palette.border,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoiceId: inv.id)),
                      );
                    },
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? palette.badgeRedBg
                            : hasDue
                                ? palette.badgeOrangeBg
                                : palette.badgeGreenBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCancelled
                            ? Icons.cancel_outlined
                            : hasDue
                                ? Icons.timelapse_rounded
                                : Icons.check_circle_rounded,
                        color: isCancelled
                            ? palette.cancelled
                            : hasDue
                                ? palette.badgeOrangeIcon
                                : palette.badgeGreenIcon,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      inv.invoiceNumber,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: AppText.body),
                    ),
                    subtitle: Text(
                      '${customer?.name ?? ""} • ${vehicle?.registrationNumber ?? ""}',
                      style: GoogleFonts.inter(fontSize: AppText.label, color: palette.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(inv.grandTotal),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: AppText.body),
                            ),
                            Text(
                              isCancelled ? 'Cancelled' : hasDue ? 'Due' : 'Paid',
                              style: GoogleFonts.inter(
                                fontSize: AppText.label,
                                fontWeight: FontWeight.w600,
                                color: isCancelled
                                    ? palette.cancelled
                                    : hasDue
                                        ? palette.pending
                                        : palette.paid,
                              ),
                            ),
                            if (inv.isOverdue) ...[
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: palette.pending,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'Overdue',
                                  style: GoogleFonts.inter(
                                    fontSize: AppText.micro,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: palette.textMuted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 84),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCard(BuildContext context, GarageProvider provider, AppPalette palette) {
    final pendingCount = provider.invoices
        .where((inv) => inv.status != InvoiceStatus.cancelled && inv.balanceDue > 0)
        .length;
    final pendingTotal = provider.totalPendingPayments;

    // Mon–Sun totals of payments received this week, drawn as a sparkline.
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weeklyCollections = List<double>.filled(7, 0);
    for (final p in provider.payments) {
      final dayDiff = DateTime(p.paymentDate.year, p.paymentDate.month, p.paymentDate.day)
          .difference(DateTime(monday.year, monday.month, monday.day))
          .inDays;
      if (dayDiff >= 0 && dayDiff < 7) weeklyCollections[dayDiff] += p.amount;
    }
    final hasWeeklyData = weeklyCollections.any((v) => v > 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.paddingCard),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: palette.border),
        boxShadow: AppDimens.cardShadow(palette.textPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: GoogleFonts.inter(
              fontSize: AppText.subtitle,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collection',
                      style: GoogleFonts.inter(
                        fontSize: AppText.label,
                        fontWeight: FontWeight.w600,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(provider.todayCollection),
                      style: GoogleFonts.inter(
                        fontSize: AppText.title,
                        fontWeight: FontWeight.w800,
                        color: palette.paid,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses',
                      style: GoogleFonts.inter(
                        fontSize: AppText.label,
                        fontWeight: FontWeight.w600,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(provider.todayExpenses),
                      style: GoogleFonts.inter(
                        fontSize: AppText.title,
                        fontWeight: FontWeight.w800,
                        color: palette.pending,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasWeeklyData) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  lineTouchData: const LineTouchData(enabled: false),
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < 7; i++) FlSpot(i.toDouble(), weeklyCollections[i]),
                      ],
                      isCurved: true,
                      barWidth: 2.5,
                      color: palette.primary,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            palette.primary.withValues(alpha: 0.22),
                            palette.primary.withValues(alpha: 0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (pendingCount > 0)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InvoicesListScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 16, color: palette.pending),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${CurrencyFormatter.format(pendingTotal)} due across $pendingCount bills',
                          style: GoogleFonts.inter(
                            fontSize: AppText.caption,
                            fontWeight: FontWeight.w700,
                            color: palette.pending,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: palette.pending),
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                'No pending dues',
                style: GoogleFonts.inter(
                  fontSize: AppText.caption,
                  fontWeight: FontWeight.w600,
                  color: palette.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveFloorStrip(BuildContext context, GarageProvider provider, AppPalette palette) {
    final activeJobs = provider.activeJobCards;

    if (activeJobs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: palette.border),
        ),
        child: Center(
          child: Text(
            'All clear — no vehicles in workshop',
            style: GoogleFonts.inter(
              fontSize: AppText.caption,
              fontWeight: FontWeight.w500,
              color: palette.textMuted,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: activeJobs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final jc = activeJobs[index];
          final vehicle = provider.getVehicleById(jc.vehicleId);
          return Container(
            // 210 so the widest status badge (WAITING PARTS) fits beside the
            // registration number on one line instead of overflowing.
            width: 210,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: palette.border),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => JobCardDetailScreen(jobCardId: jc.id)),
                  );
                },
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vehicle?.registrationNumber ?? 'Vehicle',
                              style: GoogleFonts.inter(
                                fontSize: AppText.body,
                                fontWeight: FontWeight.w800,
                                color: palette.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge.fromJobStatus(jc.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vehicle?.displayName ?? '',
                        style: GoogleFonts.inter(
                          fontSize: AppText.label,
                          fontWeight: FontWeight.w500,
                          color: palette.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModuleTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String count,
    required Color color,
    required Color badgeBg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: context.palette.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 17),
                    ),
                    Text(
                      count,
                      style: GoogleFonts.inter(
                        fontSize: AppText.body,
                        fontWeight: FontWeight.w800,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: AppText.caption,
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
