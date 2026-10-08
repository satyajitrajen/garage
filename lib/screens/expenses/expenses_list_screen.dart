import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../widgets/permission_gate.dart';
import '../../utils/permissions.dart';
import '../../models/expense.dart';
import '../../models/payment.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/list_row.dart';
import 'add_expense_screen.dart';
import '../../theme/app_text.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  final _searchController = TextEditingController();
  ExpenseCategory? _selectedCategory;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddExpense() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
  }

  void _openEditExpense(GarageExpense exp) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(existing: exp)),
    );
  }

  void _confirmDeleteExpense(GarageExpense exp) {
    showDialog(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          title: const Text('Delete this expense?'),
          content: Text('"${exp.title}" (${CurrencyFormatter.format(exp.amount)}) will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.absent,
                foregroundColor: palette.onPrimary,
              ),
              onPressed: () async {
                final provider = Provider.of<GarageProvider>(context, listen: false);
                await provider.deleteExpense(exp.id);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                showAppSnackBar(
                  context,
                  'Expense "${exp.title}" deleted',
                  type: SnackBarType.error,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final expenses = provider.expenses.where((e) {
      if (_selectedCategory != null && e.category != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final titleMatches = e.title.toLowerCase().contains(q);
        final vendorMatches = e.vendorName?.toLowerCase().contains(q) ?? false;
        final catMatches = e.category.displayName.toLowerCase().contains(q);
        return titleMatches || vendorMatches || catMatches;
      }
      return true;
    }).toList();
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'Garage Expenses',
          style: GoogleFonts.poppins(
            fontSize: AppText.title,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      // Empty list: its empty state already has the Add button.
      floatingActionButton: provider.expenses.isEmpty ? null : PermissionGate(
        permission: Permissions.expensesManage,
        child: GradientFloatingActionButton(
        onPressed: _openAddExpense,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
      ),
      body: Column(
        children: [
          // Monthly vs Today KPI Card (Exact User Gradient)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(AppDimens.paddingCard),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: palette.border, width: 1),
              boxShadow: AppDimens.cardShadow(palette.textPrimary),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This Month Expenses',
                        style: GoogleFonts.poppins(
                          color: palette.textSecondary,
                          fontSize: AppText.label,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(provider.thisMonthExpenses),
                        style: GoogleFonts.poppins(
                          fontSize: AppText.headline,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Vertical hairline: kept as a sized Container because a
                // Divider is horizontal and a VerticalDivider stretches to
                // the full row height (visual change).
                Container(
                  height: 36,
                  width: 1,
                  color: palette.divider,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Expenses',
                          style: GoogleFonts.poppins(
                            color: palette.textSecondary,
                            fontSize: AppText.label,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(provider.todayExpenses),
                          style: GoogleFonts.poppins(
                            fontSize: AppText.headline,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: 'Search expenses by title or vendor...',
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(height: 10),

          // Category Chips Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Categories'),
                  selected: _selectedCategory == null,
                  selectedColor: palette.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: _selectedCategory == null ? palette.primary : palette.textPrimary,
                    fontWeight: _selectedCategory == null ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                ...ExpenseCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      avatar: Icon(cat.icon, size: 14, color: isSelected ? palette.primary : palette.textMuted),
                      label: Text(cat.displayName),
                      selected: isSelected,
                      selectedColor: palette.primary.withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: isSelected ? palette.primary : palette.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (selected) {
                        setState(() => _selectedCategory = selected ? cat : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Expenses List
          Expanded(
            child: expenses.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No Expenses Found',
                    description: _selectedCategory != null
                        ? 'No expenses logged under "${_selectedCategory!.displayName}".'
                        : 'No expenses recorded in this period.',
                    buttonText: 'Add First Expense',
                    onButtonPressed: _openAddExpense,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 8, bottom: 120),
                    itemCount: expenses.length,
                    separatorBuilder: (_, _) => const RowDivider(),
                    itemBuilder: (context, index) {
                      final exp = expenses[index];
                      return ListRow(
                        title: exp.title,
                        subtitle: [exp.category.displayName, exp.vendorName]
                            .whereType<String>()
                            .join(' · '),
                        detail:
                            '${AppDateFormatter.formatDate(exp.expenseDate)} · ${exp.paymentMode.shortName}',
                        trailingTop: RowAmount(CurrencyFormatter.format(exp.amount)),
                        // Tap edits; delete lives behind a long press with a
                        // confirmation so it is never one stray tap away.
                        onTap: () => _openEditExpense(exp),
                        onLongPress: () => _confirmDeleteExpense(exp),
                      );
                    },
                  )
          ),
        ],
      ),
    );
  }
}
