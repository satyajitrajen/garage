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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final customers = provider.searchCustomers(_searchQuery);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          widget.isSelectionMode ? 'Select Customer' : 'Customers',
          style: GoogleFonts.poppins(
            fontSize: AppText.title,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      floatingActionButton: PermissionGate(
        permission: Permissions.customersManage,
        child: GradientFloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Customer'),
      ),
      ),
      body: Column(
        children: [
          // Search Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: 'Search by name, phone, or vehicle plate...',
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
                    ? 'Choose the customer for this job'
                    : '${customers.length} customers',
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
                ? EmptyStateWidget(
                    icon: Icons.people_outline_rounded,
                    title: 'No Customers Found',
                    description: _searchQuery.isEmpty
                        ? 'Your customer database is empty. Add your first customer!'
                        : 'No results found for "$_searchQuery". Try another search term.',
                    buttonText: 'Add New Customer',
                    onButtonPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                      );
                    },
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
                            ? 'No vehicle'
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
