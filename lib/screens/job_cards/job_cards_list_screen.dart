import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../widgets/permission_gate.dart';
import '../../utils/permissions.dart';
import '../../models/job_card.dart';
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
import 'job_card_detail_screen.dart';
import '../../theme/app_text.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text('Job Cards & Workshop', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: PermissionGate(
        permission: Permissions.jobcardsManage,
        child: GradientFloatingActionButton(
        onPressed: _createNewJobCard,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Job Card'),
      ),
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
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: AppText.body),
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
        description: _searchQuery.trim().isNotEmpty
            ? 'No job cards match "${_searchQuery.trim()}".'
            : filterStatus != null
                ? 'No vehicles currently matching status "${filterStatus.displayName}".'
                : 'No job cards yet.',
        buttonText: 'Create New Job Card',
        onButtonPressed: _createNewJobCard,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const RowDivider(),
      itemBuilder: (context, index) {
        final jc = filtered[index];
        final customer = provider.getCustomerById(jc.customerId);
        final vehicle = provider.getVehicleById(jc.vehicleId);
        final staff = jc.assignedStaffId != null ? provider.getStaffById(jc.assignedStaffId!) : null;
        final open = jc.status != JobStatus.delivered && jc.status != JobStatus.cancelled;
        final late = open && jc.promisedDeliveryDate.isBefore(DateTime.now());

        return ListRow(
          overline: jc.jobCardNumber,
          title: vehicle?.registrationNumber ?? 'Unknown vehicle',
          subtitle: [vehicle?.displayName, customer?.name].whereType<String>().join(' · '),
          detail: [
            staff?.name ?? 'Unassigned',
            if (open)
              late
                  ? 'Late, promised ${AppDateFormatter.formatRelative(jc.promisedDeliveryDate)}'
                  : 'Promised ${AppDateFormatter.formatRelative(jc.promisedDeliveryDate)}',
          ].join(' · '),
          trailingTop: jc.items.isEmpty ? null : RowAmount(CurrencyFormatter.format(jc.grandTotal)),
          trailingBottom: StatusBadge.fromJobStatus(jc.status),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => JobCardDetailScreen(jobCardId: jc.id)),
          ),
        );
      },
    );
  }
}
