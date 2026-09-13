import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/invoice.dart';
import '../../models/job_card.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_badge.dart';
import '../customers/customers_list_screen.dart';
import '../customers/add_customer_screen.dart';
import '../vehicles/vehicle_selection_screen.dart';
import '../job_cards/job_cards_list_screen.dart';
import '../job_cards/job_card_detail_screen.dart';
import '../quotations/quotations_list_screen.dart';
import '../invoices/invoices_list_screen.dart';
import '../invoices/invoice_preview_screen.dart';
import '../expenses/expenses_list_screen.dart';
import '../expenses/add_expense_screen.dart';
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
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    AppDateFormatter.formatDayDate(today),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
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
              // -------------------------------------------------------------
              // 1. CORE BENTO ISLAND CARD (BLACK BANNER)
              // -------------------------------------------------------------
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: palette.bannerGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  boxShadow: AppDimens.accentGlow(palette.primary),
                ),
                padding: const EdgeInsets.only(top: 14, left: 12, right: 12, bottom: 12),
                child: Column(
                  children: [
                    // Status Pill Header (Luminous Glass Capsule)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: palette.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 10),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'GARAGE STATUS: ',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                activeJobs.isEmpty
                                    ? 'All clear — no vehicles in workshop'
                                    : '${activeJobs.length} vehicle(s) in workshop',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: palette.ready,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4-Quadrant Metric Tiles (2x2 Grid)
                    Container(
                      decoration: BoxDecoration(
                        color: palette.card,
                        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiTile(
                                  icon: Icons.payments_rounded,
                                  badgeBg: palette.badgeGreenBg,
                                  iconColor: palette.badgeGreenIcon,
                                  value: CurrencyFormatter.format(provider.todayCollection),
                                  label: "TODAY'S COLLECTION",
                                  subtitle: "Month: ${CurrencyFormatter.formatCompact(provider.thisMonthRevenue)}",
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const InvoicesListScreen()),
                                    );
                                  },
                                  palette: palette,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiTile(
                                  icon: Icons.warning_amber_rounded,
                                  badgeBg: palette.badgeRedBg,
                                  iconColor: palette.badgeRedIcon,
                                  value: CurrencyFormatter.format(provider.totalPendingPayments),
                                  label: 'PENDING DUES',
                                  subtitle: '${provider.invoices.where((i) => i.balanceDue > 0).length} unpaid bills',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const InvoicesListScreen()),
                                    );
                                  },
                                  palette: palette,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiTile(
                                  icon: Icons.car_repair_rounded,
                                  badgeBg: palette.badgePurpleBg,
                                  iconColor: palette.badgePurpleIcon,
                                  value: '${provider.activeVehiclesUnderMaintenanceCount}',
                                  label: 'VEHICLES IN BAY',
                                  subtitle: 'Under repair',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const JobCardsListScreen()),
                                    );
                                  },
                                  palette: palette,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiTile(
                                  icon: Icons.receipt_long_rounded,
                                  badgeBg: palette.badgeOrangeBg,
                                  iconColor: palette.badgeOrangeIcon,
                                  value: CurrencyFormatter.format(provider.todayExpenses),
                                  label: "TODAY'S EXPENSES",
                                  subtitle: "Month: ${CurrencyFormatter.formatCompact(provider.thisMonthExpenses)}",
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const ExpensesListScreen()),
                                    );
                                  },
                                  palette: palette,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick Service Wizard Action Banner (Exact User Gradient)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const QuickServiceWizard()),
                          );
                        },
                        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: palette.brandGradient,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                            boxShadow: AppDimens.accentGlow(palette.primary),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.bolt_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
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
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Create job card, bill & collect payment in 60s',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // -------------------------------------------------------------
              // 2. QUICK ACTIONS SHORTCUTS CAROUSEL
              // -------------------------------------------------------------
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickActionChip(
                      context,
                      label: '+ Job Card',
                      icon: Icons.add_task_rounded,
                      color: palette.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomersListScreen(
                              isSelectionMode: true,
                              targetAction: VehicleTargetAction.createJobCard,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      context,
                      label: '+ Customer',
                      icon: Icons.person_add_alt_1_rounded,
                      color: palette.accent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      context,
                      label: '+ Estimate',
                      icon: Icons.request_quote_rounded,
                      color: palette.badgePurpleIcon,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomersListScreen(
                              isSelectionMode: true,
                              targetAction: VehicleTargetAction.createQuotation,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      context,
                      label: '+ Quick Bill',
                      icon: Icons.receipt_long_rounded,
                      color: palette.paid,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomersListScreen(
                              isSelectionMode: true,
                              targetAction: VehicleTargetAction.createInvoice,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      context,
                      label: '+ Expense',
                      icon: Icons.account_balance_wallet_rounded,
                      color: palette.badgeOrangeIcon,
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
              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // 3. LIVE BAY ACTIVITY (ACTIVE FLOOR VEHICLES)
              // -------------------------------------------------------------
              SectionHeader(
                title: 'Live Bay Activity',
                actionText: 'View All (${activeJobs.length})',
                onActionTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JobCardsListScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),

              if (activeJobs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                    border: Border.all(
                      color: palette.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'All bays clear • No vehicles currently under repair',
                      style: GoogleFonts.poppins(
                        color: palette.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              else
                ...activeJobs.take(3).map((jc) {
                  final vehicle = provider.getVehicleById(jc.vehicleId);
                  final customer = provider.getCustomerById(jc.customerId);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                      border: Border.all(
                        color: palette.border,
                        width: 1,
                      ),
                      boxShadow: AppDimens.cardShadow(palette.textPrimary),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: jc.status == JobStatus.inProgress
                                      ? palette.badgeBlueBg
                                      : jc.status == JobStatus.inspection
                                          ? palette.badgeOrangeBg
                                          : palette.badgeRedBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  jc.status == JobStatus.inProgress
                                      ? Icons.build_rounded
                                      : jc.status == JobStatus.inspection
                                          ? Icons.hourglass_top_rounded
                                          : Icons.warning_rounded,
                                  color: jc.status == JobStatus.inProgress
                                      ? palette.badgeBlueIcon
                                      : jc.status == JobStatus.inspection
                                          ? palette.badgeOrangeIcon
                                          : palette.badgeRedIcon,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${vehicle?.registrationNumber ?? "Vehicle"} • ${vehicle?.displayName ?? ""}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: palette.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '${customer?.name ?? ""} • In Bay',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11.5,
                                              color: palette.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        StatusBadge.fromJobStatus(jc.status),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: palette.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // 4. WORKSHOP MODULES SHORTCUTS (6 TILES)
              // -------------------------------------------------------------
              Text(
                'Workshop Modules',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
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
              // 5. FINANCIAL REVENUE BAR CHART (computed from real data)
              // -------------------------------------------------------------
              ..._buildWeeklyRevenueExpenseChart(provider, palette),
              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // 6. RECENT COLLECTIONS & BILLS
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
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    subtitle: Text(
                      '${customer?.name ?? ""} • ${vehicle?.registrationNumber ?? ""}',
                      style: GoogleFonts.poppins(fontSize: 12, color: palette.textMuted),
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
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                            Text(
                              isCancelled ? 'Cancelled' : hasDue ? 'Due' : 'Paid',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
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
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
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

  Widget _buildKpiTile({
    required IconData icon,
    required Color badgeBg,
    required Color iconColor,
    required String value,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required AppPalette palette,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusTile),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusTile),
            border: Border.all(
              color: palette.border,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: Icon(icon, color: iconColor, size: 17),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: palette.textMuted,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: palette.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
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

  Widget _buildQuickActionChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: AppDimens.cardShadow(context.palette.textPrimary),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(title, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// Builds the Weekly Revenue vs Expenses chart using real payment/expense
  /// data bucketed by weekday for the current calendar week (Mon–Sun).
  List<Widget> _buildWeeklyRevenueExpenseChart(GarageProvider provider, AppPalette palette) {
    final now = DateTime.now();
    // Monday of the current week (weekday: Mon=1 .. Sun=7).
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));

    final weeklyRevenue = List<double>.filled(7, 0);
    final weeklyExpenses = List<double>.filled(7, 0);

    for (final p in provider.payments) {
      final dayDiff = DateTime(p.paymentDate.year, p.paymentDate.month, p.paymentDate.day)
          .difference(DateTime(monday.year, monday.month, monday.day))
          .inDays;
      if (dayDiff >= 0 && dayDiff < 7) weeklyRevenue[dayDiff] += p.amount;
    }
    for (final e in provider.expenses) {
      final dayDiff = DateTime(e.expenseDate.year, e.expenseDate.month, e.expenseDate.day)
          .difference(DateTime(monday.year, monday.month, monday.day))
          .inDays;
      if (dayDiff >= 0 && dayDiff < 7) weeklyExpenses[dayDiff] += e.amount;
    }

    // Derive a sensible Y axis: round the max up to a clean value.
    final rawMax = [0.0, ...weeklyRevenue, ...weeklyExpenses].reduce((a, b) => a > b ? a : b);
    final maxY = rawMax <= 0 ? 100.0 : (rawMax * 1.25);

    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(
            color: palette.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Revenue vs Expenses',
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    _buildLegendItem('Income', palette.paid),
                    const SizedBox(width: 8),
                    _buildLegendItem('Expense', palette.pending),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 145,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          final index = val.toInt();
                          if (index >= 0 && index < days.length) {
                            return Text(
                              days[index],
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: palette.textMuted,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < 7; i++)
                      _makeGroupData(
                        i,
                        weeklyRevenue[i],
                        weeklyExpenses[i],
                        incomeColor: palette.paid,
                        expenseColor: palette.pending,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  BarChartGroupData _makeGroupData(
    int x,
    double y1,
    double y2, {
    required Color incomeColor,
    required Color expenseColor,
  }) {
    return BarChartGroupData(
      barsSpace: 4,
      x: x,
      barRods: [
        BarChartRodData(
          toY: y1,
          color: incomeColor,
          width: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        BarChartRodData(
          toY: y2,
          color: expenseColor,
          width: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
