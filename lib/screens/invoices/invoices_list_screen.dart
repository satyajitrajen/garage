import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/invoice.dart';
import '../../models/payment.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalInvoiced = provider.invoices
        .where((inv) => inv.status != InvoiceStatus.cancelled)
        .fold(0.0, (sum, inv) => sum + inv.grandTotal);
    final totalCollected = provider.invoices.fold(0.0, (sum, inv) => sum + inv.totalPaidAmount);
    final totalPending = provider.totalPendingPayments;

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoices & Billing', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: Row(
              children: [
                _buildKpiItem('Total Invoiced', CurrencyFormatter.format(totalInvoiced), isDark, null),
                Container(height: 24, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                _buildKpiItem('Collected', CurrencyFormatter.format(totalCollected), isDark, AppColors.paid),
                Container(height: 24, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                _buildKpiItem('Pending Dues', CurrencyFormatter.format(totalPending), isDark, AppColors.pending),
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
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
            indicatorColor: AppColors.primary,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5),
            tabs: const [
              Tab(text: 'All Invoices'),
              Tab(text: 'Paid'),
              Tab(text: 'Partial'),
              Tab(text: 'Pending'),
            ],
          ),

          // Invoices List View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabFilters.map((filter) {
                return _buildInvoicesList(provider, filter, isDark);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String label, String value, bool isDark, Color? color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color ?? (isDark ? Colors.white : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesList(GarageProvider provider, InvoiceStatus? filter, bool isDark) {
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
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      StatusBadge.fromInvoiceStatus(inv.status),
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
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${vehicle?.registrationNumber ?? ""} • ${vehicle?.displayName ?? ""}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
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
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          if (inv.balanceDue > 0)
                            Text(
                              'Due: ${CurrencyFormatter.format(inv.balanceDue)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.pending,
                              ),
                            )
                          else
                            Text(
                              'Paid in Full',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.paid,
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
                        style: GoogleFonts.poppins(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted),
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
                              color: AppColors.paid.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.paid.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.payment_rounded, size: 13, color: AppColors.paid),
                                const SizedBox(width: 4),
                                Text(
                                  'Collect',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.paid,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.paid),
                            const SizedBox(width: 4),
                            Text(
                              'Paid via ${inv.payments.isEmpty ? '—' : inv.payments.last.mode.shortName}',
                              style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.paid, fontWeight: FontWeight.w600),
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
