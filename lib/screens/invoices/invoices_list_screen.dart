import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../widgets/permission_gate.dart';
import '../../utils/permissions.dart';
import '../../models/invoice.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_palette.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/list_row.dart';
import '../../widgets/status_badge.dart';
import '../customers/customers_list_screen.dart';
import '../vehicles/vehicle_selection_screen.dart';
import 'invoice_preview_screen.dart';
import '../../theme/app_text.dart';

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
        title: Text('Bills', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      // Empty list: its empty state already has the Add button.
      floatingActionButton: provider.invoices.isEmpty ? null : PermissionGate(
        permission: Permissions.invoicesManage,
        child: GradientFloatingActionButton(
        onPressed: _createNewInvoice,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Bill'),
      ),
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
                _buildKpiItem('Billed', CurrencyFormatter.format(totalInvoiced), null),
                _buildKpiItem('Collected', CurrencyFormatter.format(totalCollected), null),
                _buildKpiItem('Due', CurrencyFormatter.format(totalPending),
                    totalPending > 0 ? palette.pending : null),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: 'Search by bill #, customer, plate...',
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: AppText.body),
            tabs: const [
              Tab(text: 'All Bills'),
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
            style: GoogleFonts.poppins(
              fontSize: AppText.label,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppText.body,
              fontWeight: FontWeight.w700,
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
        title: 'No Bills Found',
        description: filter != null
            ? 'No bills with status "${filter.displayName}".'
            : 'No bills yet. Create a bill for serviced vehicles.',
        buttonText: 'Create Bill',
        onButtonPressed: _createNewInvoice,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const RowDivider(),
      itemBuilder: (context, index) {
        final inv = filtered[index];
        final customer = provider.getCustomerById(inv.customerId);
        final vehicle = provider.getVehicleById(inv.vehicleId);
        final open = inv.balanceDue > 0 && inv.status != InvoiceStatus.cancelled;

        return ListRow(
          overline: '${inv.invoiceNumber} · ${AppDateFormatter.formatDate(inv.invoiceDate)}',
          title: customer?.name ?? 'Customer',
          subtitle: [vehicle?.registrationNumber, vehicle?.displayName].whereType<String>().join(' · '),
          trailingTop: RowAmount(CurrencyFormatter.format(inv.grandTotal)),
          trailingBottom: open
              ? Text(
                  inv.isOverdue
                      ? 'Overdue · ${CurrencyFormatter.format(inv.balanceDue)}'
                      : '${CurrencyFormatter.format(inv.balanceDue)} due',
                  style: GoogleFonts.poppins(
                    fontSize: AppText.label,
                    fontWeight: FontWeight.w500,
                    color: inv.isOverdue ? palette.absent : palette.pending,
                  ),
                )
              : StatusBadge.fromInvoiceStatus(inv.status),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoiceId: inv.id)),
          ),
        );
      },
    );
  }
}
