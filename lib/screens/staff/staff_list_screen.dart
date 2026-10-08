import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../widgets/permission_gate.dart';
import '../../utils/permissions.dart';
import '../../models/staff.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/list_row.dart';
import '../../widgets/status_badge.dart';
import 'add_staff_screen.dart';
import 'staff_attendance_screen.dart';
import 'staff_salary_screen.dart';
import '../../theme/app_text.dart';

class StaffListScreen extends StatelessWidget {
  const StaffListScreen({super.key});

  void _showStaffActions(BuildContext context, GarageProvider provider, Staff staff) {
    void go(Widget screen) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(staff.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text(staff.role.displayName),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Attendance'),
              onTap: () => go(StaffAttendanceScreen(staff: staff)),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Salary slip'),
              onTap: () => go(StaffSalaryScreen(staff: staff)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit details'),
              onTap: () => go(AddStaffScreen(staffToEdit: staff)),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: ctx.palette.absent),
              title: Text('Remove from staff', style: TextStyle(color: ctx.palette.absent)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteStaff(context, provider, staff);
              },
            ),
          ],
        ),
      ),
    );
  }

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
                foregroundColor: palette.onPrimary,
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
            fontSize: AppText.title,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      floatingActionButton: PermissionGate(
        permission: Permissions.staffManage,
        child: GradientFloatingActionButton(
        onPressed: () => _openAddStaff(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Staff'),
      ),
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
                          fontSize: AppText.label,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Payroll: ${CurrencyFormatter.format(totalMonthlyPayroll)}/mo',
                        style: GoogleFonts.poppins(
                          fontSize: AppText.body,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Nothing to mark until someone active is on the roster.
                if (staffMembers.any((s) => s.isActive)) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: GradientButton(
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
                ),
                ],
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
                    padding: const EdgeInsets.only(top: 8, bottom: 120),
                    itemCount: staffMembers.length,
                    separatorBuilder: (_, _) => const RowDivider(),
                    itemBuilder: (context, index) {
                      final staff = staffMembers[index];
                      final todayAttendance = provider.getAttendanceForStaffOnDate(staff.id, today);
                      final activeJobsCount = provider.getStaffActiveJobCount(staff.id);
                      return ListRow(
                        title: staff.name,
                        subtitle: staff.role.displayName,
                        detail: [
                          staff.phone,
                          if (activeJobsCount > 0)
                            '$activeJobsCount active ${activeJobsCount == 1 ? 'job' : 'jobs'}',
                        ].join(' · '),
                        trailingTop: RowAmount('${CurrencyFormatter.format(staff.monthlySalary)}/mo'),
                        trailingBottom: todayAttendance == null
                            ? null
                            : StatusBadge.fromAttendanceStatus(todayAttendance.status),
                        onTap: () => _showStaffActions(context, provider, staff),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
