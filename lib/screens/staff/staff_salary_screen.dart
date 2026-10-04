import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../theme/app_text.dart';

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

  Future<void> _giveAdvance() async {
    final amount = double.tryParse(_advanceAmountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      showAppSnackBar(context, 'Please enter a valid advance amount', type: SnackBarType.error);
      return;
    }

    final provider = Provider.of<GarageProvider>(context, listen: false);
    await provider.addSalaryAdvance(
      staffId: widget.staff.id,
      amount: amount,
      reason: _advanceReasonController.text.trim().isEmpty ? null : _advanceReasonController.text.trim(),
    );
    if (!mounted) return;

    _advanceAmountController.clear();
    _advanceReasonController.clear();
    Navigator.pop(context);

    showAppSnackBar(
      context,
      'Salary advance of ${CurrencyFormatter.format(amount)} recorded for ${widget.staff.name}!',
      type: SnackBarType.success,
    );
  }

  void _showAddAdvanceDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          title: Text('Record Salary Advance', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Advance Amount (₹) *',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: palette.primary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _advanceReasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason / Remarks',
                  hintText: 'e.g. Medical emergency / Festival',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
            ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _giveAdvance,
              child: const Text('Give Advance'),
            ),
          ],
        );
      },
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
          IconButton(
            icon: const Icon(Icons.add_card_rounded),
            tooltip: 'Record Advance',
            onPressed: _showAddAdvanceDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Salary Slip Card
            Container(
              padding: const EdgeInsets.all(20),
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
                          Text('MONTHLY PAYSLIP', style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.primary, letterSpacing: 1)),
                          Text(AppDateFormatter.formatMonthYear(_selectedMonth), style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: palette.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.staff.role.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: AppText.label, fontWeight: FontWeight.w700, color: palette.primary),
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
                        ('Present', 'presentDays', palette.present),
                        ('Half Day', 'halfDays', palette.halfDay),
                        ('Absent', 'absentDays', palette.absent),
                        ('Leave', 'leaveDays', palette.leave),
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
                  Text('Earnings & Allowances', style: GoogleFonts.poppins(fontSize: AppText.body, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _buildSalaryLine('Base Monthly Salary', CurrencyFormatter.format(baseSalary)),
                  const Divider(height: 20),

                  Text('Deductions & Advances', style: GoogleFonts.poppins(fontSize: AppText.body, fontWeight: FontWeight.w700, color: palette.pending)),
                  const SizedBox(height: 8),
                  if (absentDeduction > 0)
                    _buildSalaryLine('Absent Deduction (${summary["absentDays"]} days)', '- ${CurrencyFormatter.format(absentDeduction)}', isDeduction: true),
                  if (halfDayDeduction > 0)
                    _buildSalaryLine('Half Day Deduction (${summary["halfDays"]} days)', '- ${CurrencyFormatter.format(halfDayDeduction)}', isDeduction: true),
                  if (totalAdvances > 0)
                    _buildSalaryLine('Salary Advances Deducted', '- ${CurrencyFormatter.format(totalAdvances)}', isDeduction: true),
                  if (absentDeduction == 0 && halfDayDeduction == 0 && totalAdvances == 0)
                    _buildSalaryLine('No deductions this month', CurrencyFormatter.format(0)),

                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Net Salary Payout:', style: GoogleFonts.poppins(fontSize: AppText.title, fontWeight: FontWeight.w700)),
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
                        child: Text('Salary Advances Log', style: GoogleFonts.poppins(fontSize: AppText.subtitle, fontWeight: FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: _showAddAdvanceDialog,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Give Advance'),
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

            // Mark Salary Paid Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final provider = Provider.of<GarageProvider>(context, listen: false);
                  final now = DateTime.now();
                  await provider.disburseSalary(
                    staffId: widget.staff.id,
                    month: now.month,
                    year: now.year,
                    netPayable: netPayable,
                  );
                  if (!context.mounted) return;
                  showAppSnackBar(
                    context,
                    'Salary of ${CurrencyFormatter.format(netPayable)} disbursed & recorded as expense for ${widget.staff.name}!',
                    type: SnackBarType.success,
                  );
                },
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Disburse & Mark Salary Paid'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: palette.paid,
                  foregroundColor: palette.onPrimary,
                ),
              ),
            ),
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
