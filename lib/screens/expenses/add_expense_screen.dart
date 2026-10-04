import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../data/api/api_exception.dart';
import '../../models/expense.dart';
import '../../models/payment.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../theme/app_text.dart';

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

  // Receipt photo: _receiptBytes is what's shown (new pick or the saved one);
  // _receiptChanged/_receiptRemoved say what to sync after the expense saves.
  Uint8List? _receiptBytes;
  bool _receiptLoading = false;
  bool _receiptChanged = false;
  bool _receiptRemoved = false;

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
      if (existing.receiptPath != null) _loadReceipt(existing.id);
    }
  }

  Future<void> _loadReceipt(String expenseId) async {
    setState(() => _receiptLoading = true);
    try {
      final bytes =
          await context.read<GarageProvider>().fetchExpenseReceipt(expenseId);
      if (mounted) setState(() => _receiptBytes = bytes);
    } catch (_) {
      // Missing/unreadable receipt: the form still works without a preview.
    } finally {
      if (mounted) setState(() => _receiptLoading = false);
    }
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
          source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (!mounted) return;
        showAppSnackBar(context, 'Photo is too large (max 5 MB)',
            type: SnackBarType.error);
        return;
      }
      setState(() {
        _receiptBytes = bytes;
        _receiptChanged = true;
        _receiptRemoved = false;
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Could not open the camera or gallery',
          type: SnackBarType.error);
    }
  }

  void _removeReceipt() => setState(() {
        _receiptBytes = null;
        _receiptChanged = false;
        _receiptRemoved = widget.existing?.receiptPath != null;
      });

  /// Uploads/removes the receipt once the expense exists. Returns false when
  /// that failed (the expense itself is already saved).
  Future<bool> _syncReceipt(GarageProvider provider, String expenseId) async {
    try {
      if (_receiptChanged && _receiptBytes != null) {
        await provider.uploadExpenseReceipt(expenseId, _receiptBytes!);
      } else if (_receiptRemoved) {
        await provider.deleteExpenseReceipt(expenseId);
      }
      return true;
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e is ApiException
              ? 'Expense saved, but receipt failed: ${e.userMessage}'
              : 'Expense saved, but the receipt could not be uploaded',
          type: SnackBarType.error,
        );
      }
      return false;
    }
  }

  Widget _buildReceiptSection(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receipt photo',
            style: GoogleFonts.poppins(
                fontSize: AppText.body, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_receiptLoading)
          const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()))
        else if (_receiptBytes != null)
          Stack(
            children: [
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(
                        child: Image.memory(_receiptBytes!,
                            errorBuilder: (_, _, _) => const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Preview not available'))))),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                  child: Image.memory(_receiptBytes!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                          height: 80,
                          alignment: Alignment.center,
                          color: palette.cardAlt,
                          child: const Text('Receipt attached'))),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton.filledTonal(
                  tooltip: 'Remove receipt',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _removeReceipt,
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickReceipt(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(_receiptBytes == null ? 'Take photo' : 'Retake'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickReceipt(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
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
    // The picker can outlive this State (theme flip pops the route).
    if (!mounted) return;
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
        await _syncReceipt(provider, edited.id);
        if (!mounted) return;

        showAppSnackBar(
          context,
          'Expense "${edited.title}" updated!',
          type: SnackBarType.success,
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

        final created = await provider.addExpense(expense);
        await _syncReceipt(provider, created.id);
        if (!mounted) return;

        showAppSnackBar(
          context,
          'Expense of ${CurrencyFormatter.format(amount)} recorded!',
          type: SnackBarType.success,
        );

        Navigator.pop(context, expense);
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

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
                style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategory.values.map((cat) {
                  final isSelected = _category == cat;
                  return ChoiceChip(
                    avatar: Icon(cat.icon, size: 16, color: isSelected ? palette.onPrimary : palette.primary),
                    label: Text(cat.displayName),
                    selected: isSelected,
                    selectedColor: palette.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? palette.onPrimary : palette.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: AppText.caption,
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
                decoration: InputDecoration(
                  labelText: 'Expense Title / Description *',
                  hintText: 'e.g. Brake cleaner sprays / Monthly electricity',
                  prefixIcon: Icon(Icons.edit_note_rounded, color: palette.primary),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 14),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(fontSize: AppText.headline, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Amount Spent (₹) *',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: palette.primary),
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
                borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: palette.primary, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expense Date',
                                style: GoogleFonts.poppins(
                                  fontSize: AppText.label,
                                  color: palette.textMuted,
                                ),
                              ),
                              Text(
                                AppDateFormatter.formatDate(_expenseDate),
                                style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Icon(Icons.edit_calendar_rounded, size: 18, color: palette.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Paid Via (Payment Mode)
              Text(
                'Paid Via Mode',
                style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
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
                    selectedColor: palette.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? palette.onPrimary : palette.textPrimary,
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
              const SizedBox(height: 20),
              _buildReceiptSection(context),
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
