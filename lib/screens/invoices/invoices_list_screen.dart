import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/invoice.dart';
import '../../models/payment.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/status_badge.dart';
import '../customers/customers_list_screen.dart';
import '../vehicles/vehicle_selection_screen.dart';
import '../payments/payment_collection_screen.dart';
import 'invoice_preview_screen.dart';

class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<InvoiceStatus?> _tabFilters = [
    null, // All
    InvoiceStatus.paid,
    InvoiceStatus.partial,
    InvoiceStatus.pending,
    InvoiceStatus.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabFilters.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _createNewInvoice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomersListScreen(
          isSelectionMode: true,
          targetAction: VehicleTargetAction.createInvoice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final palette = context.palette;

    final totalInvoiced = provider.invoices
        .where((inv) => inv.status != InvoiceStatus.cancelled)
        .fold(0.0, (sum, inv) => sum + inv.grandTotal);
    final totalCollected = provider.invoices.fold(0.0, (sum, inv) => sum + inv.totalPaidAmount);
    final totalPending = provider.totalPendingPayments;

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoices & Billing', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add_rounded),
            tooltip: 'New Invoice',
            onPressed: _createNewInvoice,
          ),
        ],
      ),
      floatingActionButton: GradientFloatingActionButton(
        onPressed: _createNewInvoice,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Invoice'),
      ),
      body: Column(
        children: [
          // Top Summary KPI Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            // Alt-surface strip: cardAlt is exactly the old light value
            // (0xFFF1F5F9) with a matching dark-mode alt surface.
            color: palette.cardAlt,
            child: Row(
              children: [
                _buildKpiItem('Total Invoiced', CurrencyFormatter.format(totalInvoiced), null),
                // Vertical hairlines: kept as sized Containers because a
                // Divider is horizontal and a VerticalDivider stretches to
                // the full row height (visual change).
                Container(height: 24, width: 1, color: palette.textMuted),
                _buildKpiItem('Collected', CurrencyFormatter.format(totalCollected), palette.paid),
                Container(height: 24, width: 1, color: palette.textMuted),
                _buildKpiItem('Pending Dues', CurrencyFormatter.format(totalPending), palette.pending),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: 'Search by invoice #, customer, plate...',
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: palette.primary,
            unselectedLabelColor: palette.textMuted,
            indicatorColor: palette.primary,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
            tabs: const [
              Tab(text: 'All Invoices'),
              Tab(text: 'Paid'),
              Tab(text: 'Partial'),
              Tab(text: 'Pending'),
              Tab(text: 'Cancelled'),
            ],
          ),

          // Invoices List View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabFilters.map((filter) {
                return _buildInvoicesList(provider, filter);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String label, String value, Color? color) {
    final palette = context.palette;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color ?? palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesList(GarageProvider provider, InvoiceStatus? filter) {
    final palette = context.palette;
    final filtered = provider.invoices.where((inv) {
      if (filter != null && inv.status != filter) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final invMatches = inv.invoiceNumber.toLowerCase().contains(q);
        final customer = provider.getCustomerById(inv.customerId);
        final vehicle = provider.getVehicleById(inv.vehicleId);

        final custMatches = customer?.name.toLowerCase().contains(q) ?? false;
        final vehMatches = vehicle?.registrationNumber.toLowerCase().contains(q) ?? false;

        return invMatches || custMatches || vehMatches;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.receipt_long_outlined,
        title: 'No Invoices Found',
        description: filter != null
            ? 'No invoices currently under status "${filter.displayName}".'
            : 'No invoices created yet. Create a bill for serviced vehicles.',
        buttonText: 'Create Invoice',
        onButtonPressed: _createNewInvoice,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final inv = filtered[index];
        final customer = provider.getCustomerById(inv.customerId);
        final vehicle = provider.getVehicleById(inv.vehicleId);

        return Card(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoiceId: inv.id)),
              );
            },
            borderRadius: BorderRadius.circular(AppDimens.radiusTile),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.paddingCard),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: palette.accent,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (inv.isOverdue) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: palette.pending,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Overdue',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          StatusBadge.fromInvoiceStatus(inv.status),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer?.name ?? 'Customer',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${vehicle?.registrationNumber ?? ""} • ${vehicle?.displayName ?? ""}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(inv.grandTotal),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          if (inv.balanceDue > 0)
                            Text(
                              'Due: ${CurrencyFormatter.format(inv.balanceDue)}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: palette.pending,
                              ),
                            )
                          else
                            Text(
                              'Paid in Full',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: palette.paid,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppDateFormatter.formatDate(inv.invoiceDate),
                        style: GoogleFonts.inter(fontSize: 11.5, color: palette.textMuted),
                      ),
                      if (inv.balanceDue > 0)
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentCollectionScreen(invoice: inv),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: palette.paid.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: palette.paid.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.payment_rounded, size: 13, color: palette.paid),
                                const SizedBox(width: 4),
                                Text(
                                  'Collect',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: palette.paid,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 13, color: palette.paid),
                            const SizedBox(width: 4),
                            Text(
                              'Paid via ${inv.payments.isEmpty ? '—' : inv.payments.last.mode.shortName}',
                              style: GoogleFonts.inter(fontSize: 11.5, color: palette.paid, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
