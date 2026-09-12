import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/quotation.dart';
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
import 'quotation_detail_screen.dart';

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
    null,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quotations & Estimates', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add_rounded),
            tooltip: 'New Estimate',
            onPressed: _createNewQuotation,
          ),
        ],
      ),
      floatingActionButton: GradientFloatingActionButton(
        onPressed: _createNewQuotation,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Estimate'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: 'Search by EST#, customer, plate...',
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
            indicatorColor: AppColors.primary,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5),
            tabs: const [
              Tab(text: 'All Estimates'),
              Tab(text: 'Sent'),
              Tab(text: 'Approved'),
              Tab(text: 'Converted'),
              Tab(text: 'Drafts'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabFilters.map((filter) {
                return _buildQuotationsList(provider, filter, isDark);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationsList(GarageProvider provider, QuotationStatus? filter, bool isDark) {
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
      return EmptyStateWidget(
        icon: Icons.request_quote_outlined,
        title: 'No Estimates Found',
        description: filter != null
            ? 'No quotations currently with status "${filter.displayName}".'
            : 'No estimates created yet. Create an estimate for your customers.',
        buttonText: 'Create Estimate',
        onButtonPressed: _createNewQuotation,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final quote = filtered[index];
        final customer = provider.getCustomerById(quote.customerId);
        final vehicle = provider.getVehicleById(quote.vehicleId);

        return Card(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: quote.id)),
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
                        quote.quotationNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      StatusBadge.fromQuotationStatus(quote.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer?.name ?? '',
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(quote.grandTotal),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${quote.items.length} items',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
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
                        'Created: ${AppDateFormatter.formatDate(quote.createdAt)}',
                        style: GoogleFonts.poppins(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted),
                      ),
                      Text(
                        'Valid: ${quote.validityDays} Days',
                        style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.accent, fontWeight: FontWeight.w600),
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
