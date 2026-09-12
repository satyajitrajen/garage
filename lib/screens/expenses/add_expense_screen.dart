import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/expense.dart';
import '../../models/payment.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';

class AddExpenseScreen extends StatefulWidget {
  /// Non-null puts the screen in edit mode: fields are prefilled from this
  /// expense and saving updates it (id and any fields the form does not
  /// edit, e.g. receiptPath, are preserved).
  final GarageExpense? existing;

  const AddExpenseScreen({super.key, this.existing});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();
  final _notesController = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.consumables;
  PaymentMode _paymentMode = PaymentMode.cash;
  DateTime _expenseDate = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    // Edit mode: prefill everything from the expense being edited.
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _amountController.text = existing.amount.toStringAsFixed(2);
      _vendorController.text = existing.vendorName ?? '';
      _notesController.text = existing.notes ?? '';
      _category = existing.category;
      _paymentMode = existing.paymentMode;
      _expenseDate = existing.expenseDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _expenseDate = date);
    }
  }

  Future<void> _saveExpense() async {
    // Latch: a fast double-tap on Save must not create two expenses.
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final provider = Provider.of<GarageProvider>(context, listen: false);
    final title = _titleController.text.trim().isEmpty
        ? _category.displayName
        : _titleController.text.trim();
    final vendor = _vendorController.text.trim().isEmpty ? null : _vendorController.text.trim();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        // Edit mode: copyWith keeps the expense id so the repository updates
        // the existing record in place instead of minting a new one.
        final edited = widget.existing!.copyWith(
          title: title,
          category: _category,
          amount: amount,
          expenseDate: _expenseDate,
          paymentMode: _paymentMode,
          vendorName: vendor,
          notes: notes,
        );

        await provider.updateExpense(edited);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense "${edited.title}" updated!'),
            backgroundColor: AppColors.paid,
          ),
        );

        Navigator.pop(context, edited);
      } else {
        final expense = GarageExpense(
          id: const Uuid().v4(),
          title: title,
          category: _category,
          amount: amount,
          expenseDate: _expenseDate,
          paymentMode: _paymentMode,
          vendorName: vendor,
          notes: notes,
        );

        await provider.addExpense(expense);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense of ${CurrencyFormatter.format(amount)} recorded!'),
            backgroundColor: AppColors.paid,
          ),
        );

        Navigator.pop(context, expense);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.pending,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Garage Expense' : 'Add Garage Expense', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expense Category Picker
              Text(
                'Expense Category *',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategory.values.map((cat) {
                  final isSelected = _category == cat;
                  return ChoiceChip(
                    avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : AppColors.primary),
                    label: Text(cat.displayName),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _category = cat;
                          if (_titleController.text.isEmpty) {
                            _titleController.text = cat.displayName;
                          }
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Title / Description
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Expense Title / Description *',
                  hintText: 'e.g. Brake cleaner sprays / Monthly electricity',
                  prefixIcon: Icon(Icons.edit_note_rounded, color: AppColors.primary),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 14),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  labelText: 'Amount Spent (₹) *',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Date Picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expense Date',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                ),
                              ),
                              Text(
                                AppDateFormatter.formatDate(_expenseDate),
                                style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Paid Via (Payment Mode)
              Text(
                'Paid Via Mode',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PaymentMode.values.map((mode) {
                  final isSelected = _paymentMode == mode;
                  return ChoiceChip(
                    label: Text(mode.displayName),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _paymentMode = mode);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Vendor / Supplier Name
              TextFormField(
                controller: _vendorController,
                decoration: const InputDecoration(
                  labelText: 'Vendor / Paid To (Optional)',
                  hintText: 'e.g. National Spares / Electricity Board',
                  prefixIcon: Icon(Icons.storefront_rounded),
                ),
              ),
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes / Receipt Details',
                  hintText: 'e.g. Bill #8891, paid for 10 cans',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveExpense,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_isEditing ? 'Save Changes' : 'Save Expense'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
