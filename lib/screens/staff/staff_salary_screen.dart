import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/payment.dart';
import '../../models/staff.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/permissions.dart';
import '../../theme/app_text.dart';
import '../../utils/error_message.dart';
import '../../widgets/permission_gate.dart';
import '../../l10n/app_language.dart';

class StaffSalaryScreen extends StatefulWidget {
  final Staff staff;

  const StaffSalaryScreen({super.key, required this.staff});

  @override
  State<StaffSalaryScreen> createState() => _StaffSalaryScreenState();
}

class _StaffSalaryScreenState extends State<StaffSalaryScreen> {
  final _advanceAmountController = TextEditingController();
  final _advanceReasonController = TextEditingController();

  late DateTime _selectedMonth;
  bool _isDisbursing = false;

  /// In-flight latch: a double-tap on "Give Advance" must not record the
  /// advance (and its linked expense) twice.
  bool _isSaving = false;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  @override
  void dispose() {
    _advanceAmountController.dispose();
    _advanceReasonController.dispose();
    super.dispose();
  }

  /// Records the advance. Returns true on success; fields are cleared only
  /// after the server confirms. The caller keeps the dialog open on failure
  /// so the entry can be corrected and retried.
  Future<bool> _giveAdvance() async {
    if (_isSaving) return false;
    final amount = double.tryParse(_advanceAmountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      showAppSnackBar(context, tr('Please enter a valid advance amount'), type: SnackBarType.error);
      return false;
    }

    setState(() => _isSaving = true);
    final provider = Provider.of<GarageProvider>(context, listen: false);
    try {
      await provider.addSalaryAdvance(
        staffId: widget.staff.id,
        amount: amount,
        reason: _advanceReasonController.text.trim().isEmpty ? null : _advanceReasonController.text.trim(),
      );
      if (!mounted) return true;

      _advanceAmountController.clear();
      _advanceReasonController.clear();
      showAppSnackBar(
        context,
        'Salary advance of ${CurrencyFormatter.format(amount)} recorded for ${widget.staff.name}!',
        type: SnackBarType.success,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Asks before paying out: a salary payout records an expense and settles
  /// the month's advances, so it shouldn't happen on a single stray tap.
  Future<PaymentMode?> _confirmPayout(double netPayable) {
    var mode = PaymentMode.cash;
    return showDialog<PaymentMode>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Pay ${CurrencyFormatter.format(netPayable)}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.staff.name}, ${AppDateFormatter.formatMonthYear(_selectedMonth)}. '
                "This is recorded as an expense and settles the month's advances.",
              ),
              const SizedBox(height: 14),
              Text(tr('Paid by'), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in const [PaymentMode.cash, PaymentMode.upi, PaymentMode.bankTransfer])
                    ChoiceChip(
                      label: Text(m.displayName),
                      selected: mode == m,
                      onSelected: (_) => setDialogState(() => mode = m),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, mode),
              child: Text(tr('Pay salary')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disburse(double netPayable) async {
    // Latch: a double-tap must not record the payout twice.
    if (_isDisbursing) return;
    final mode = await _confirmPayout(netPayable);
    if (mode == null || !mounted) return;
    setState(() => _isDisbursing = true);
    final provider = Provider.of<GarageProvider>(context, listen: false);
    try {
      await provider.disburseSalary(
        staffId: widget.staff.id,
        month: _selectedMonth.month,
        year: _selectedMonth.year,
        netPayable: netPayable,
        paymentMode: mode,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Salary of ${CurrencyFormatter.format(netPayable)} disbursed & recorded as expense for ${widget.staff.name}!',
        type: SnackBarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        errorMessage(e),
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isDisbursing = false);
    }
  }

  void _showAddAdvanceDialog() {
    showDialog(
      context: context,
      // StatefulBuilder so the dialog repaints when _isSaving flips: both
      // buttons stay disabled until the request settles.
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final palette = ctx.palette;
          return AlertDialog(
            title: Text(tr('Record Salary Advance'), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Advance loan given to ${widget.staff.name}. This will be auto-deducted from monthly salary payout.',
                  style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _advanceAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr('Advance Amount (₹) *'),
                    prefixIcon: Icon(Icons.currency_rupee_rounded, color: palette.primary),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _advanceReasonController,
                  decoration: InputDecoration(
                    labelText: tr('Reason / Remarks'),
                    hintText: 'e.g. Medical emergency / Festival',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
              ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(ctx),
                child: Text(tr('Cancel')),
              ),
              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        setDialogState(() {}); // repaint with buttons disabled
                        final ok = await _giveAdvance();
                        if (!ctx.mounted) return;
                        if (ok) Navigator.pop(ctx);
                        setDialogState(() {}); // failure: re-enable for retry
                      },
                child: Text(tr('Give Advance')),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final palette = context.palette;

    final summary = provider.calculateMonthlySalarySummary(
      widget.staff.id,
      _selectedMonth.month,
      _selectedMonth.year,
    );

    final advances = provider.getAdvancesForStaff(
      widget.staff.id,
      month: _selectedMonth.month,
      year: _selectedMonth.year,
    );

    final baseSalary = (summary['baseSalary'] as double?) ?? widget.staff.monthlySalary;
    final absentDeduction = (summary['absentDeduction'] as double?) ?? 0.0;
    final halfDayDeduction = (summary['halfDayDeduction'] as double?) ?? 0.0;
    final totalAdvances = (summary['totalAdvances'] as double?) ?? 0.0;
    final netPayable = (summary['netPayable'] as double?) ?? baseSalary;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.staff.name} - Payroll', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          PermissionGate(
            permission: Permissions.advancesManage,
            child: IconButton(
              icon: const Icon(Icons.add_card_rounded),
              tooltip: tr('Record Advance'),
              onPressed: _showAddAdvanceDialog,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Salary Slip Card
            Container(
              padding: const EdgeInsets.all(AppDimens.paddingCard),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                border: Border.all(color: palette.border),
                boxShadow: AppDimens.cardShadow(palette.textPrimary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('MONTHLY PAYSLIP'), style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary, letterSpacing: 1)),
                          // ‹ Month › — past payslips can be viewed and paid;
                          // the arrow stops at the current month.
                          Row(
                            children: [
                              IconButton(
                                tooltip: tr('Previous month'),
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.chevron_left_rounded),
                                onPressed: () => setState(() => _selectedMonth =
                                    DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1)),
                              ),
                              Flexible(
                                child: Text(
                                  AppDateFormatter.formatMonthYear(_selectedMonth),
                                  // One line: "October 2026" must not wrap.
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.fade,
                                  style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: tr('Next month'),
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.chevron_right_rounded),
                                onPressed: _isCurrentMonth
                                    ? null
                                    : () => setState(() => _selectedMonth =
                                        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: palette.cardAlt,
                          borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                        ),
                        child: Text(
                          widget.staff.role.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Attendance Counts Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (final (label, key, color) in [
                        (tr('Present'), 'presentDays', palette.present),
                        (tr('Half Day'), 'halfDays', palette.halfDay),
                        (tr('Absent'), 'absentDays', palette.absent),
                        (tr('Leave'), 'leaveDays', palette.leave),
                      ])
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildMiniPill(label, '${summary[key] ?? 0}', color),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Earnings & Deductions Breakdown
                  Text(tr('Earnings & Allowances'), style: GoogleFonts.poppins(fontSize: AppText.body, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _buildSalaryLine(tr('Base Monthly Salary'), CurrencyFormatter.format(baseSalary)),
                  const Divider(height: 20),

                  Text(tr('Deductions & Advances'), style: GoogleFonts.poppins(fontSize: AppText.body, fontWeight: FontWeight.w700, color: palette.pending)),
                  const SizedBox(height: 8),
                  if (absentDeduction > 0)
                    _buildSalaryLine('Absent Deduction (${summary["absentDays"]} day${summary["absentDays"] == 1 ? "" : "s"})', '- ${CurrencyFormatter.format(absentDeduction)}', isDeduction: true),
                  if (halfDayDeduction > 0)
                    _buildSalaryLine('Half Day Deduction (${summary["halfDays"]} day${summary["halfDays"] == 1 ? "" : "s"})', '- ${CurrencyFormatter.format(halfDayDeduction)}', isDeduction: true),
                  if (totalAdvances > 0)
                    _buildSalaryLine(tr('Salary Advances Deducted'), '- ${CurrencyFormatter.format(totalAdvances)}', isDeduction: true),
                  if (absentDeduction == 0 && halfDayDeduction == 0 && totalAdvances == 0)
                    _buildSalaryLine(tr('No deductions this month'), CurrencyFormatter.format(0)),

                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(tr('Net salary'), style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.format(netPayable),
                            style: GoogleFonts.poppins(
                              fontSize: AppText.display,
                              fontWeight: FontWeight.w700,
                              color: palette.paid,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Advances History Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(tr('Salary Advances Log'), style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700)),
                      ),
                      PermissionGate(
                        permission: Permissions.advancesManage,
                        child: TextButton.icon(
                          onPressed: _showAddAdvanceDialog,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(tr('Give Advance')),
                        ),
                      ),
                    ],
                  ),
                  if (advances.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'No advances given in ${AppDateFormatter.formatMonthYear(_selectedMonth)}',
                      style: GoogleFonts.poppins(fontSize: AppText.caption, color: palette.textMuted),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    ...advances.map((adv) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppDateFormatter.formatDate(adv.date),
                                  style: GoogleFonts.poppins(fontSize: AppText.caption, fontWeight: FontWeight.w600),
                                ),
                                if (adv.reason != null)
                                  Text(adv.reason!, style: GoogleFonts.poppins(fontSize: AppText.label, color: palette.textMuted)),
                              ],
                            ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyFormatter.format(adv.amount),
                              style: GoogleFonts.poppins(fontSize: AppText.body, fontWeight: FontWeight.w700, color: palette.pending),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mark Salary Paid Button: once the month is paid it turns into a
            // read-only "paid" state so the same payout can't be recorded twice.
            Builder(builder: (context) {
              final paid = provider.salaryPaymentFor(
                widget.staff.id,
                _selectedMonth.month,
                _selectedMonth.year,
              );
              final monthLabel = AppDateFormatter.formatMonthYear(_selectedMonth);
              // Recording a payout is an advances.manage write.
              return PermissionGate(
                permission: Permissions.advancesManage,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: paid != null || _isDisbursing
                        ? null
                        : () => _disburse(netPayable),
                    icon: Icon(paid != null
                        ? Icons.check_circle_rounded
                        : Icons.payments_rounded),
                    label: Text(paid != null
                        ? 'Salary paid for $monthLabel (${CurrencyFormatter.format(paid.amount)})'
                        : _isDisbursing
                            ? tr('Recording payout...')
                            : tr('Disburse & Mark Salary Paid')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: palette.paid,
                      foregroundColor: palette.onPrimary,
                      disabledBackgroundColor: palette.paid.withValues(alpha: 0.15),
                      disabledForegroundColor: palette.paid,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPill(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(count, style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSalaryLine(String label, String val, {bool isDeduction = false}) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: AppText.body, color: palette.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            val,
            style: GoogleFonts.poppins(
              fontSize: AppText.body,
              fontWeight: FontWeight.w700,
              color: isDeduction ? palette.pending : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
