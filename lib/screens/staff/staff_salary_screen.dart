import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';

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

  void _giveAdvance() {
    final amount = double.tryParse(_advanceAmountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid advance amount')),
      );
      return;
    }

    final provider = Provider.of<GarageProvider>(context, listen: false);
    provider.addSalaryAdvance(
      staffId: widget.staff.id,
      amount: amount,
      reason: _advanceReasonController.text.trim().isEmpty ? null : _advanceReasonController.text.trim(),
    );

    _advanceAmountController.clear();
    _advanceReasonController.clear();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Salary advance of ₹${amount.toInt()} recorded for ${widget.staff.name}!'),
        backgroundColor: AppColors.paid,
      ),
    );
  }

  void _showAddAdvanceDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Record Salary Advance', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Advance loan given to ${widget.staff.name}. This will be auto-deducted from monthly salary payout.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _advanceAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Advance Amount (₹) *',
                prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MONTHLY PAYSLIP', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1)),
                          Text(AppDateFormatter.formatMonthYear(_selectedMonth), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.staff.role.displayName,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
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
                      _buildMiniPill('Present', '${summary["presentDays"] ?? 0}', AppColors.present),
                      _buildMiniPill('Half Day', '${summary["halfDays"] ?? 0}', AppColors.halfDay),
                      _buildMiniPill('Absent', '${summary["absentDays"] ?? 0}', AppColors.absent),
                      _buildMiniPill('Leave', '${summary["leaveDays"] ?? 0}', AppColors.leave),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Earnings & Deductions Breakdown
                  Text('Earnings & Allowances', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _buildSalaryLine('Base Monthly Salary', CurrencyFormatter.format(baseSalary), isDark),
                  const Divider(height: 20),

                  Text('Deductions & Advances', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.pending)),
                  const SizedBox(height: 8),
                  if (absentDeduction > 0)
                    _buildSalaryLine('Absent Deduction (${summary["absentDays"]} days)', '- ${CurrencyFormatter.format(absentDeduction)}', isDark, isDeduction: true),
                  if (halfDayDeduction > 0)
                    _buildSalaryLine('Half Day Deduction (${summary["halfDays"]} days)', '- ${CurrencyFormatter.format(halfDayDeduction)}', isDark, isDeduction: true),
                  if (totalAdvances > 0)
                    _buildSalaryLine('Salary Advances Deducted', '- ${CurrencyFormatter.format(totalAdvances)}', isDark, isDeduction: true),
                  if (absentDeduction == 0 && halfDayDeduction == 0 && totalAdvances == 0)
                    _buildSalaryLine('No deductions this month', '₹0', isDark),

                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Net Salary Payout:', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(
                        CurrencyFormatter.format(netPayable),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.paid,
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
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Salary Advances Log', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
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
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    ...advances.map((adv) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppDateFormatter.formatDate(adv.date),
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                if (adv.reason != null)
                                  Text(adv.reason!, style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textMuted)),
                              ],
                            ),
                            Text(
                              CurrencyFormatter.format(adv.amount),
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.pending),
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
                onPressed: () {
                  final provider = Provider.of<GarageProvider>(context, listen: false);
                  final now = DateTime.now();
                  provider.disburseSalary(
                    staffId: widget.staff.id,
                    month: now.month,
                    year: now.year,
                    netPayable: netPayable,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Salary of ${CurrencyFormatter.format(netPayable)} disbursed & recorded as expense for ${widget.staff.name}!'),
                      backgroundColor: AppColors.paid,
                    ),
                  );
                },
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Disburse & Mark Salary Paid'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.paid,
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
          Text(count, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSalaryLine(String label, String val, bool isDark, {bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 13.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            val,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDeduction ? AppColors.pending : (isDark ? Colors.white : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
