import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../widgets/permission_gate.dart';
import '../../utils/permissions.dart';
import '../../models/staff.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/error_message.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/list_row.dart';
import '../../widgets/status_badge.dart';
import 'add_staff_screen.dart';
import 'staff_attendance_screen.dart';
import 'staff_salary_screen.dart';
import '../../theme/app_text.dart';
import '../../l10n/app_language.dart';

class StaffListScreen extends StatelessWidget {
  const StaffListScreen({super.key});

  void _showStaffActions(BuildContext context, GarageProvider provider, Staff staff) {
    void go(Widget screen) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    showModalBottomSheet<void>(
      context: context,
      // Rounded-top sheet, matching every other sheet in the app.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusSheet),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(staff.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text(staff.role.displayName),
            ),
            const Divider(height: 1),
            // Write actions are hidden from staff without the matching
            // permission; read-only navigation stays open to everyone.
            PermissionGate(
              permission: Permissions.attendanceManage,
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(tr('Attendance')),
                onTap: () => go(StaffAttendanceScreen(staff: staff)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(tr('Salary slip')),
              onTap: () => go(StaffSalaryScreen(staff: staff)),
            ),
            PermissionGate(
              permission: Permissions.staffManage,
              child: ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(tr('Edit details')),
                onTap: () => go(AddStaffScreen(staffToEdit: staff)),
              ),
            ),
            PermissionGate(
              permission: Permissions.staffManage,
              child: ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: ctx.palette.absent),
                title: Text(tr('Remove from staff'), style: TextStyle(color: ctx.palette.absent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteStaff(context, provider, staff);
                },
              ),
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
          title: Text(tr('Delete Staff Member?')),
          content: Text(
            'Are you sure you want to remove ${staff.name} from the workshop team? '
            'This will also remove their attendance and salary records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Cancel'), style: TextStyle(color: palette.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.absent,
                foregroundColor: palette.onPrimary,
              ),
              onPressed: () async {
                try {
                  await provider.deleteStaff(staff.id);
                } catch (e) {
                  // Failure keeps the dialog open so the user can retry.
                  if (!ctx.mounted) return;
                  showAppSnackBar(ctx, errorMessage(e), type: SnackBarType.error);
                  return;
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                showAppSnackBar(
                  context,
                  'Staff member ${staff.name} deleted',
                  type: SnackBarType.success,
                );
              },
              child: Text(tr('Delete')),
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
          tr('Staff & Technicians'),
          style: GoogleFonts.poppins(
            fontSize: AppText.title,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      // Empty list: its empty state already has the Add button.
      floatingActionButton: provider.staff.isEmpty ? null : PermissionGate(
        permission: Permissions.staffManage,
        child: GradientFloatingActionButton(
        onPressed: () => _openAddStaff(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Add Staff')),
      ),
      ),
      body: Column(
        children: [
          // Top Staff & Attendance Actions Strip
          Container(
            padding: const EdgeInsets.all(AppDimens.paddingScreen),
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
                  child: PermissionGate(
                    permission: Permissions.attendanceManage,
                    child: GradientButton(
                      onPressed: () async {
                        try {
                          await provider.markAllPresentToday();
                        } catch (e) {
                          if (!context.mounted) return;
                          showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
                          return;
                        }
                        if (!context.mounted) return;
                        showAppSnackBar(
                          context,
                          tr('Marked all active staff as Present today!'),
                          type: SnackBarType.success,
                        );
                      },
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: Text(tr('Mark All Present')),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      height: 38,
                      borderRadius: AppDimens.radiusButton,
                    ),
                  ),
                ),
                ],
              ],
            ),
          ),

          // Staff List
          Expanded(
            child: staffMembers.isEmpty
                ? // The add CTA is a staff.manage write — hide it like the FAB.
                  PermissionGate(
                    permission: Permissions.staffManage,
                    fallback: EmptyStateWidget(
                      icon: Icons.badge_outlined,
                      title: tr('No staff yet'),
                      description:
                          tr('Add mechanics, electricians, painters, and helpers to manage workshop jobs.'),
                    ),
                    child: EmptyStateWidget(
                      icon: Icons.badge_outlined,
                      title: tr('No staff yet'),
                      description:
                          tr('Add mechanics, electricians, painters, and helpers to manage workshop jobs.'),
                      buttonText: tr('Add First Employee'),
                      onButtonPressed: () => _openAddStaff(context),
                    ),
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
                        // The two things done most often, one tap away.
                        footer: Wrap(
                          spacing: 8,
                          children: [
                            PermissionGate(
                              permission: Permissions.attendanceManage,
                              child: _RowAction(
                                icon: Icons.calendar_month_outlined,
                                label: tr('Attendance'),
                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => StaffAttendanceScreen(staff: staff))),
                              ),
                            ),
                            _RowAction(
                              icon: Icons.payments_outlined,
                              label: tr('Salary'),
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => StaffSalaryScreen(staff: staff))),
                            ),
                          ],
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

/// Small outlined shortcut button shown under each staff row.
class _RowAction extends StatelessWidget {
  const _RowAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: GoogleFonts.poppins(fontSize: AppText.caption, fontWeight: FontWeight.w600),
          foregroundColor: context.palette.textPrimary,
          side: BorderSide(color: context.palette.border),
        ),
      );
}
