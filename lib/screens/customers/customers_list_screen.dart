import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../widgets/list_row.dart';
import '../../widgets/permission_gate.dart';
import '../../utils/permissions.dart';
import '../../models/customer.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_palette.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/search_bar_widget.dart';
import '../vehicles/vehicle_selection_screen.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';
import '../../theme/app_text.dart';
import '../../l10n/app_language.dart';

class CustomersListScreen extends StatefulWidget {
  final bool isSelectionMode;
  final VehicleTargetAction targetAction;

  const CustomersListScreen({
    super.key,
    this.isSelectionMode = false,
    this.targetAction = VehicleTargetAction.createJobCard,
  });

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCustomerSelected(Customer customer) {
    if (widget.isSelectionMode) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VehicleSelectionScreen(
            customer: customer,
            targetAction: widget.targetAction,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerDetailScreen(customer: customer),
        ),
      );
    }
  }

  /// Empty list / search miss. The "Add New Customer" CTA is only offered to
  /// members with customers.manage (staff see the state without it).
  EmptyStateWidget _emptyState({required bool withCta}) {
    return EmptyStateWidget(
      icon: Icons.people_outline_rounded,
      title: _searchQuery.isEmpty ? tr('No customers yet') : tr('No matches'),
      description: _searchQuery.isEmpty
          ? tr('Customers are added when you start their first job, or add one now.')
          : 'Nothing matches "$_searchQuery". Try a plate, phone number or name.',
      buttonText: withCta && _searchQuery.isEmpty ? tr('Add customer') : null,
      onButtonPressed: withCta
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
              );
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final customers = provider.searchCustomers(_searchQuery);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          widget.isSelectionMode ? tr('Select Customer') : tr('Customers'),
          style: GoogleFonts.poppins(
            fontSize: AppText.title,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      // Empty list: its empty state already has the Add button.
      floatingActionButton: provider.customers.isEmpty ? null : PermissionGate(
        permission: Permissions.customersManage,
        child: GradientFloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('New Customer')),
      ),
      ),
      body: Column(
        children: [
          // Search Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: tr('Search by name, phone, or vehicle plate...'),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Count bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.isSelectionMode
                    ? switch (widget.targetAction) {
                        VehicleTargetAction.createInvoice =>
                          tr('Choose the customer for this bill'),
                        VehicleTargetAction.createQuotation =>
                          tr('Choose the customer for this estimate'),
                        _ => tr('Choose the customer for this job'),
                      }
                    : '${customers.length} customer${customers.length == 1 ? '' : 's'}',
                style: GoogleFonts.poppins(
                  fontSize: AppText.caption,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Customer Cards List
          Expanded(
            child: customers.isEmpty
                ? PermissionGate(
                    permission: Permissions.customersManage,
                    fallback: _emptyState(withCta: false),
                    child: _emptyState(withCta: true),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 8, bottom: 120),
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const RowDivider(),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final vehicles = provider.getVehiclesForCustomer(customer.id);
                      final due = provider.getCustomerOutstandingBalance(customer.id);
                      return ListRow(
                        title: customer.name,
                        subtitle: customer.phone,
                        detail: vehicles.isEmpty
                            ? tr('No vehicle')
                            : vehicles.map((v) => v.registrationNumber).join(', '),
                        trailingTop: due > 0
                            ? RowAmount('${CurrencyFormatter.format(due)} due',
                                color: palette.pending)
                            : null,
                        onTap: () => _onCustomerSelected(customer),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
