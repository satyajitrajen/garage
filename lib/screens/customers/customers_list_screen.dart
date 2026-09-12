import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/search_bar_widget.dart';
import '../vehicles/vehicle_selection_screen.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.isSelectionMode ? 'Select Customer' : 'Customers',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: AppColors.accent, size: 22),
            tooltip: 'Add Customer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: GradientFloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Customer'),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${customers.length} Customers Found',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Tap to select / view',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 84),
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final vehicles = provider.getVehiclesForCustomer(customer.id);
                      final outstandingBalance = provider.getCustomerOutstandingBalance(customer.id);

                      return Card(
                        child: InkWell(
                          onTap: () => _onCustomerSelected(customer),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primary.withOpacity(0.12),
                                  child: Text(
                                    customer.name.substring(0, 1).toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone_rounded,
                                            size: 13,
                                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            customer.phone,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Vehicles preview pills
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.directions_car_rounded, size: 12, color: AppColors.accent),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${vehicles.length} ${vehicles.length == 1 ? "Vehicle" : "Vehicles"}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white : const Color(0xFF334155),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                           if (vehicles.isNotEmpty)
                                             Container(
                                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                               decoration: BoxDecoration(
                                                 color: AppColors.accent.withValues(alpha: 0.10),
                                                 borderRadius: BorderRadius.circular(8),
                                               ),
                                               child: Text(
                                                 vehicles.first.registrationNumber,
                                                 style: GoogleFonts.poppins(
                                                   fontSize: 10.5,
                                                   fontWeight: FontWeight.w700,
                                                   color: AppColors.accent,
                                                 ),
                                               ),
                                             ),
                                         ],
                                       ),
                                     ],
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 Column(
                                   crossAxisAlignment: CrossAxisAlignment.end,
                                   children: [
                                     if (outstandingBalance > 0)
                                       Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                         decoration: BoxDecoration(
                                           color: AppColors.pending.withValues(alpha: 0.12),
                                           borderRadius: BorderRadius.circular(6),
                                         ),
                                         child: Text(
                                           'Due: ${CurrencyFormatter.format(outstandingBalance)}',
                                           style: GoogleFonts.poppins(
                                             fontSize: 11,
                                             fontWeight: FontWeight.w700,
                                             color: AppColors.pending,
                                           ),
                                         ),
                                       ),
                                     const SizedBox(height: 8),
                                     Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         IconButton(
                                           icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.paid, size: 20),
                                           tooltip: 'WhatsApp',
                                           onPressed: () {
                                             ScaffoldMessenger.of(context).showSnackBar(
                                               SnackBar(content: Text('WhatsApping ${customer.effectiveWhatsApp}...')),
                                             );
                                           },
                                         ),
                                         const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.textMuted),
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
                  ),
          ),
        ],
      ),
    );
  }
}
