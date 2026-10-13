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
import 'job_card_detail_screen.dart';
import '../../theme/app_text.dart';
import 'start_job_screen.dart';
import '../../l10n/app_language.dart';

class JobCardsListScreen extends StatefulWidget {
  const JobCardsListScreen({super.key});

  @override
  State<JobCardsListScreen> createState() => _JobCardsListScreenState();
}

class _JobCardsListScreenState extends State<JobCardsListScreen> {
  // Selected status filter (null = all), shown as chips with counts.
  JobStatus? _filter;
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _createNewJobCard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StartJobScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Jobs'), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      // Empty list: its empty state already has the Add button.
      floatingActionButton: provider.jobCards.isEmpty ? null : PermissionGate(
        permission: Permissions.jobcardsManage,
        child: GradientFloatingActionButton(
        onPressed: _createNewJobCard,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('New Job Card')),
      ),
      ),
      // No jobs yet: just the empty state, no search box or filters.
      body: provider.jobCards.isEmpty
          ? _buildJobCardList(provider, null)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: CustomSearchBar(
                    controller: _searchController,
                    hintText: tr('Search by JC#, plate or customer'),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                // Status filters with counts, so the workload reads at a glance.
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final status in _tabFilters) ...[
                        _filterChip(provider, status),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                Expanded(child: _buildJobCardList(provider, _filter)),
              ],
            ),
    );
  }

  Widget _filterChip(GarageProvider provider, JobStatus? status) {
    final palette = Theme.of(context);
    final count = status == null
        ? provider.jobCards.length
        : provider.jobCards.where((jc) => jc.status == status).length;
    final selected = _filter == status;
    return ChoiceChip(
      label: Text('${status == null ? tr('All') : status.shortName} $count'),
      selected: selected,
      showCheckmark: false,
      labelStyle: GoogleFonts.poppins(
        fontSize: AppText.caption,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? palette.colorScheme.onPrimary : palette.colorScheme.onSurface,
      ),
      selectedColor: palette.colorScheme.onSurface,
      onSelected: (_) => setState(() => _filter = status),
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
      final String description = _searchQuery.trim().isNotEmpty
          ? 'No job cards match "${_searchQuery.trim()}".'
          : filterStatus != null
              ? 'No vehicles currently matching status "${filterStatus.displayName}".'
              : tr('When a car comes in, start a job with its registration number.');
      // The create CTA is a write action — gated like the FAB; staff without
      // jobcards.manage still see the informational empty state.
      return PermissionGate(
        permission: Permissions.jobcardsManage,
        fallback: EmptyStateWidget(
          icon: Icons.assignment_outlined,
          title: _searchQuery.trim().isNotEmpty || filterStatus != null ? tr('No matches') : tr('No jobs yet'),
          description: description,
        ),
        child: EmptyStateWidget(
          icon: Icons.assignment_outlined,
          title: _searchQuery.trim().isNotEmpty || filterStatus != null ? tr('No matches') : tr('No jobs yet'),
          description: description,
          buttonText: tr('Start a job'),
          onButtonPressed: _createNewJobCard,
        ),
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
        final isLate = open && jc.promisedDeliveryDate.isBefore(DateTime.now());

        return ListRow(
          overline: jc.jobCardNumber,
          title: vehicle?.registrationNumber ?? tr('Unknown vehicle'),
          subtitle: [vehicle?.displayName, customer?.name].whereType<String>().join(' · '),
          detail: [
            staff?.name ?? tr('Unassigned'),
            if (open)
              isLate
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
