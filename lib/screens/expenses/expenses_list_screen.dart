import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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
import '../../widgets/status_badge.dart';
import 'add_expense_screen.dart';

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
          title: const Text('Delete Expense?'),
          content: Text('Are you sure you want to delete "${exp.title}" (${CurrencyFormatter.format(exp.amount)})?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.pending,
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
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: palette.accent, size: 22),
            tooltip: 'Add Expense',
            onPressed: _openAddExpense,
          ),
        ],
      ),
      floatingActionButton: GradientFloatingActionButton(
        onPressed: _openAddExpense,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(provider.thisMonthExpenses),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
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
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(provider.todayExpenses),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
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
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
                    itemCount: expenses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final exp = expenses[index];
                      // Per-category accent from the palette map (same source
                      // as StatusBadge.forExpenseCategory) — replaces the old
                      // all-orange badge mapping.
                      final categoryColor = palette.categoryColors[exp.category];

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: categoryColor?.withValues(alpha: 0.12) ?? palette.badgeOrangeBg,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  exp.category.icon,
                                  color: categoryColor ?? palette.badgeOrangeIcon,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exp.title,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        StatusBadge.forExpenseCategory(exp.category, palette: palette),
                                        if (exp.vendorName != null) ...[
                                          const SizedBox(width: 6),
                                          Text(exp.vendorName!, style: GoogleFonts.poppins(fontSize: 11.5, color: palette.textMuted)),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          AppDateFormatter.formatDate(exp.expenseDate),
                                          style: GoogleFonts.poppins(fontSize: 11, color: palette.textMuted),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            // Neutral chip on a white card: cardAlt is
                                            // exactly the old light value (0xFFF1F5F9).
                                            color: palette.cardAlt,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            exp.paymentMode.shortName,
                                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(exp.amount),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: palette.pending,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // padding 12 + default 48dp constraints keep
                                      // the icon visual at 18 while the tap target
                                      // stays >= 44px.
                                      IconButton(
                                        padding: const EdgeInsets.all(12),
                                        icon: Icon(Icons.edit_outlined, size: 18, color: palette.textMuted),
                                        tooltip: 'Edit Expense',
                                        onPressed: () => _openEditExpense(exp),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        padding: const EdgeInsets.all(12),
                                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: palette.textMuted),
                                        tooltip: 'Delete Expense',
                                        onPressed: () => _confirmDeleteExpense(exp),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
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
