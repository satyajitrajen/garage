import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/job_card.dart';
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
import 'job_card_detail_screen.dart';

class JobCardsListScreen extends StatefulWidget {
  const JobCardsListScreen({super.key});

  @override
  State<JobCardsListScreen> createState() => _JobCardsListScreenState();
}

class _JobCardsListScreenState extends State<JobCardsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<JobStatus?> _tabFilters = [
    null, // All
    JobStatus.inProgress,
    JobStatus.inspection,
    JobStatus.waitingParts,
    JobStatus.readyForDelivery,
    JobStatus.delivered,
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

  void _createNewJobCard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomersListScreen(
          isSelectionMode: true,
          targetAction: VehicleTargetAction.createJobCard,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text('Job Cards & Workshop', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task_rounded),
            tooltip: 'New Job Card',
            onPressed: _createNewJobCard,
          ),
        ],
      ),
      floatingActionButton: GradientFloatingActionButton(
        onPressed: _createNewJobCard,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Job Card'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: 'Search by JC#, vehicle plate, or customer...',
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Status Filter Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: palette.primary,
            unselectedLabelColor: palette.textMuted,
            indicatorColor: palette.primary,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5),
            tabs: const [
              Tab(text: 'All Jobs'),
              Tab(text: 'In Progress'),
              Tab(text: 'Inspection'),
              Tab(text: 'Waiting Parts'),
              Tab(text: 'Ready for Delivery'),
              Tab(text: 'Delivered'),
            ],
          ),

          // Job Cards List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabFilters.map((filterStatus) {
                return _buildJobCardList(provider, filterStatus);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCardList(GarageProvider provider, JobStatus? filterStatus) {
    final palette = context.palette;
    final filtered = provider.jobCards.where((jc) {
      if (filterStatus != null && jc.status != filterStatus) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final jcMatches = jc.jobCardNumber.toLowerCase().contains(q);
        final vehicle = provider.getVehicleById(jc.vehicleId);
        final customer = provider.getCustomerById(jc.customerId);

        final vehicleMatches = vehicle?.registrationNumber.toLowerCase().contains(q) ?? false;
        final customerMatches = customer?.name.toLowerCase().contains(q) ?? false;

        return jcMatches || vehicleMatches || customerMatches;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.assignment_outlined,
        title: 'No Job Cards Found',
        description: filterStatus != null
            ? 'No vehicles currently matching status "${filterStatus.displayName}".'
            : 'No active job cards found in the system.',
        buttonText: 'Create New Job Card',
        onButtonPressed: _createNewJobCard,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final jc = filtered[index];
        final customer = provider.getCustomerById(jc.customerId);
        final vehicle = provider.getVehicleById(jc.vehicleId);
        final staff = jc.assignedStaffId != null ? provider.getStaffById(jc.assignedStaffId!) : null;

        return Card(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => JobCardDetailScreen(jobCardId: jc.id)),
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
                        jc.jobCardNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: palette.accent,
                        ),
                      ),
                      StatusBadge.fromJobStatus(jc.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle?.registrationNumber ?? 'Unknown Plate',
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${vehicle?.displayName ?? ""} • ${customer?.name ?? ""}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (jc.items.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(jc.grandTotal),
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: palette.textPrimary,
                              ),
                            ),
                            Text(
                              '${jc.items.length} items',
                              style: GoogleFonts.poppins(fontSize: 11, color: palette.textMuted),
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
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 13, color: palette.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            staff?.name ?? 'Unassigned',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 13, color: palette.accent),
                          const SizedBox(width: 4),
                          Text(
                            AppDateFormatter.formatRelative(jc.promisedDeliveryDate),
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: palette.accent,
                            ),
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
