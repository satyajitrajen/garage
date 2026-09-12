import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_colors.dart';
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
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff Member?'),
        content: Text('Are you sure you want to remove ${staff.name} from the workshop team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pending),
            onPressed: () {
              provider.deleteStaff(staff.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Staff member ${staff.name} deleted'),
                  backgroundColor: AppColors.pending,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final staffMembers = provider.staff;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();

    final totalMonthlyPayroll = staffMembers.fold<double>(0, (sum, s) => sum + s.monthlySalary);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
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
            icon: const Icon(Icons.person_add_rounded, color: AppColors.accent, size: 22),
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
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
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
                  onPressed: () {
                    provider.markAllPresentToday();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Marked all active staff as Present today!'),
                        backgroundColor: AppColors.paid,
                      ),
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
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                      child: Text(
                                        staff.name.substring(0, 1).toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
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
                                            staff.name,
                                            style: GoogleFonts.poppins(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              staff.role.displayName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.accent,
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
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'per month',
                                          style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.textMuted),
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
                                        Icon(Icons.assignment_turned_in_rounded, size: 14, color: AppColors.inProgress),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$activeJobsCount Active Jobs',
                                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text('Today: ', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
                                        if (todayAttendance != null)
                                          StatusBadge.fromAttendanceStatus(todayAttendance.status)
                                        else
                                          Text('Not Marked', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.pending, fontWeight: FontWeight.w600)),
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
                                        IconButton(
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
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.pending),
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
