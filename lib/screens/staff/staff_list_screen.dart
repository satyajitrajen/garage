import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/status_badge.dart';
import 'add_staff_screen.dart';
import 'staff_attendance_screen.dart';
import 'staff_salary_screen.dart';

class StaffListScreen extends StatelessWidget {
  const StaffListScreen({super.key});

  void _openAddStaff(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddStaffScreen()),
    );
  }

  void _confirmDeleteStaff(BuildContext context, GarageProvider provider, Staff staff) {
    showDialog(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          title: const Text('Delete Staff Member?'),
          content: Text('Are you sure you want to remove ${staff.name} from the workshop team?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.pending,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await provider.deleteStaff(staff.id);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                showAppSnackBar(
                  context,
                  'Staff member ${staff.name} deleted',
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
    final staffMembers = provider.staff;
    final palette = context.palette;
    final today = DateTime.now();

    final totalMonthlyPayroll = staffMembers.fold<double>(0, (sum, s) => sum + s.monthlySalary);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'Staff & Technicians',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_rounded, color: palette.accent, size: 22),
            tooltip: 'Add Staff Member',
            onPressed: () => _openAddStaff(context),
          ),
        ],
      ),
      floatingActionButton: GradientFloatingActionButton(
        onPressed: () => _openAddStaff(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Staff'),
      ),
      body: Column(
        children: [
          // Top Staff & Attendance Actions Strip
          Container(
            padding: const EdgeInsets.all(16),
            // Alt-surface strip: cardAlt is exactly the old light value
            // (0xFFF1F5F9) with a matching dark-mode alt surface.
            color: palette.cardAlt,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Team (${staffMembers.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Payroll: ${CurrencyFormatter.format(totalMonthlyPayroll)}/mo',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                GradientButton(
                  onPressed: () async {
                    await provider.markAllPresentToday();
                    if (!context.mounted) return;
                    showAppSnackBar(
                      context,
                      'Marked all active staff as Present today!',
                      type: SnackBarType.success,
                    );
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Mark All Present'),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  height: 38,
                  borderRadius: 14,
                ),
              ],
            ),
          ),

          // Staff List
          Expanded(
            child: staffMembers.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.badge_outlined,
                    title: 'No Staff Registered',
                    description: 'Add mechanics, electricians, painters, and helpers to manage workshop jobs.',
                    buttonText: 'Add First Employee',
                    onButtonPressed: () => _openAddStaff(context),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
                    itemCount: staffMembers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final staff = staffMembers[index];
                      final todayAttendance = provider.getAttendanceForStaffOnDate(staff.id, today);
                      final activeJobsCount = provider.getStaffActiveJobCount(staff.id);

                      return Card(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StaffAttendanceScreen(staff: staff),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                          child: Padding(
                            padding: const EdgeInsets.all(AppDimens.paddingCard),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: palette.primary.withValues(alpha: 0.15),
                                      child: Text(
                                        staff.name.substring(0, 1).toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: palette.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            staff.name,
                                            style: GoogleFonts.poppins(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w700,
                                              color: palette.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: palette.accent.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              staff.role.displayName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: palette.accent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(staff.monthlySalary),
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: palette.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'per month',
                                          style: GoogleFonts.poppins(fontSize: 10.5, color: palette.textMuted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.assignment_turned_in_rounded, size: 14, color: palette.inProgress),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$activeJobsCount Active Jobs',
                                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text('Today: ', style: GoogleFonts.poppins(fontSize: 12, color: palette.textMuted)),
                                        if (todayAttendance != null)
                                          StatusBadge.fromAttendanceStatus(todayAttendance.status)
                                        else
                                          Text('Not Marked', style: GoogleFonts.poppins(fontSize: 12, color: palette.pending, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Quick Actions row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        // padding 12 keeps the default >=48dp tap
                                        // target explicit; icon visual unchanged.
                                        IconButton(
                                          padding: const EdgeInsets.all(12),
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          tooltip: 'Edit Staff Details',
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AddStaffScreen(staffToEdit: staff),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          padding: const EdgeInsets.all(12),
                                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: palette.pending),
                                          tooltip: 'Delete Staff',
                                          onPressed: () => _confirmDeleteStaff(context, provider, staff),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => StaffSalaryScreen(staff: staff)),
                                            );
                                          },
                                          icon: const Icon(Icons.receipt_long_rounded, size: 15),
                                          label: const Text('Salary Slip'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            textStyle: GoogleFonts.poppins(fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => StaffAttendanceScreen(staff: staff)),
                                            );
                                          },
                                          icon: const Icon(Icons.calendar_month_rounded, size: 15),
                                          label: const Text('Attendance'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            textStyle: GoogleFonts.poppins(fontSize: 12),
                                          ),
                                        ),
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
