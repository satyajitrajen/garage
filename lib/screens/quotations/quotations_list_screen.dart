import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../widgets/permission_gate.dart';
import '../../utils/permissions.dart';
import '../../models/quotation.dart';
import '../../providers/garage_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/list_row.dart';
import '../../widgets/status_badge.dart';
import '../customers/customers_list_screen.dart';
import '../vehicles/vehicle_selection_screen.dart';
import 'quotation_detail_screen.dart';
import '../../theme/app_text.dart';
import '../../l10n/app_language.dart';

class QuotationsListScreen extends StatefulWidget {
  const QuotationsListScreen({super.key});

  @override
  State<QuotationsListScreen> createState() => _QuotationsListScreenState();
}

class _QuotationsListScreenState extends State<QuotationsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<QuotationStatus?> _tabFilters = [
    null, // All
    QuotationStatus.sent,
    QuotationStatus.approved,
    QuotationStatus.converted,
    QuotationStatus.draft,
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

  void _createNewQuotation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomersListScreen(
          isSelectionMode: true,
          targetAction: VehicleTargetAction.createQuotation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Estimates'), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      // Empty list: its empty state already has the Add button.
      floatingActionButton: provider.quotations.isEmpty ? null : PermissionGate(
        permission: Permissions.quotationsManage,
        child: GradientFloatingActionButton(
        onPressed: _createNewQuotation,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('New Estimate')),
      ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: tr('Search by EST#, customer, plate...'),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: AppText.body),
            tabs: [
              Tab(text: tr('All Estimates')),
              Tab(text: tr('Sent')),
              Tab(text: tr('Approved')),
              Tab(text: tr('Converted')),
              Tab(text: tr('Drafts')),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabFilters.map((filter) {
                return _buildQuotationsList(provider, filter);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationsList(GarageProvider provider, QuotationStatus? filter) {
    final filtered = provider.quotations.where((q) {
      if (filter != null && q.status != filter) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final qMatches = q.quotationNumber.toLowerCase().contains(query);
        final customer = provider.getCustomerById(q.customerId);
        final vehicle = provider.getVehicleById(q.vehicleId);

        final custMatches = customer?.name.toLowerCase().contains(query) ?? false;
        final vehMatches = vehicle?.registrationNumber.toLowerCase().contains(query) ?? false;

        return qMatches || custMatches || vehMatches;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      final String description = _searchQuery.trim().isNotEmpty
          ? 'Nothing matches "${_searchQuery.trim()}".'
          : filter != null
              ? 'No estimates with status "${filter.displayName}".'
              : tr('Send customers a price before you start work. Approved estimates become jobs.');
      // The create CTA is a write action — gated like the FAB; staff without
      // quotations.manage still see the informational empty state.
      return PermissionGate(
        permission: Permissions.quotationsManage,
        fallback: EmptyStateWidget(
          icon: Icons.request_quote_outlined,
          title: _searchQuery.trim().isEmpty && filter == null ? tr('No estimates yet') : tr('No matches'),
          description: description,
        ),
        child: EmptyStateWidget(
          icon: Icons.request_quote_outlined,
          title: _searchQuery.trim().isEmpty && filter == null ? tr('No estimates yet') : tr('No matches'),
          description: description,
          buttonText: tr('Create Estimate'),
          onButtonPressed: _createNewQuotation,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const RowDivider(),
      itemBuilder: (context, index) {
        final quote = filtered[index];
        final customer = provider.getCustomerById(quote.customerId);
        final vehicle = provider.getVehicleById(quote.vehicleId);
        return ListRow(
          overline: '${quote.quotationNumber} · ${AppDateFormatter.formatDate(quote.createdAt)}',
          title: customer?.name ?? tr('Customer'),
          subtitle: [vehicle?.registrationNumber, vehicle?.displayName].whereType<String>().join(' · '),
          detail: 'Valid ${quote.validityDays} days',
          trailingTop: RowAmount(CurrencyFormatter.format(quote.grandTotal)),
          trailingBottom: StatusBadge.fromQuotationStatus(quote.status),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: quote.id)),
          ),
        );
      },
    );
  }
}
