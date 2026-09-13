import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../providers/garage_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/date_formatter.dart';
import 'staff_salary_screen.dart';
import '../../theme/app_text.dart';

class StaffAttendanceScreen extends StatefulWidget {
  final Staff staff;

  const StaffAttendanceScreen({super.key, required this.staff});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  late DateTime _currentMonth;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  void _changeMonth(int delta) {
    final target = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    // Never navigate into the future — attendance for days that haven't
    // happened yet would corrupt salary summaries.
    if (target.isAfter(currentMonthStart)) return;
    setState(() => _currentMonth = target);
  }

  Future<void> _markAttendance(AttendanceStatus status) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (day.isAfter(today)) {
      showAppSnackBar(context, 'Attendance cannot be marked for a future date', type: SnackBarType.error);
      return;
    }

    final provider = Provider.of<GarageProvider>(context, listen: false);
    await provider.markAttendance(
      staffId: widget.staff.id,
      date: _selectedDate,
      status: status,
    );
    if (!mounted) return;

    showAppSnackBar(
      context,
      'Marked ${status.displayName} on ${AppDateFormatter.formatDayDate(_selectedDate)}',
      type: SnackBarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GarageProvider>(context);
    final palette = context.palette;

    final salarySummary = provider.calculateMonthlySalarySummary(
      widget.staff.id,
      _currentMonth.month,
      _currentMonth.year,
    );

    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;

    final selectedRecord = provider.getAttendanceForStaffOnDate(widget.staff.id, _selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.staff.name} - Attendance', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_rounded),
            tooltip: 'View Salary Slip',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffSalaryScreen(staff: widget.staff),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Header Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    AppDateFormatter.formatMonthYear(_currentMonth),
                    style: GoogleFonts.inter(
                      fontSize: AppText.title,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Monthly Summary KPI Grid
            Row(
              children: [
                _buildSummaryBadge('Present', '${salarySummary["presentDays"] ?? 0}', palette.present),
                const SizedBox(width: 8),
                _buildSummaryBadge('Half Day', '${salarySummary["halfDays"] ?? 0}', palette.halfDay),
                const SizedBox(width: 8),
                _buildSummaryBadge('Absent', '${salarySummary["absentDays"] ?? 0}', palette.absent),
                const SizedBox(width: 8),
                _buildSummaryBadge('Leaves', '${salarySummary["leaveDays"] ?? 0}', palette.leave),
              ],
            ),
            const SizedBox(height: 16),

            // Calendar Grid Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  // Weekday Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                      final isSunday = day == 'S';
                      return SizedBox(
                        width: 36,
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: AppText.caption,
                            color: isSunday ? palette.pending : palette.textMuted,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Days Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: (firstWeekday - 1) + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < firstWeekday - 1) {
                        return const SizedBox.shrink();
                      }

                      final dayNum = index - (firstWeekday - 1) + 1;
                      final date = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
                      final isSelected = DateUtils.isSameDay(_selectedDate, date);
                      final isSunday = date.weekday == DateTime.sunday;
                      final record = provider.getAttendanceForStaffOnDate(widget.staff.id, date);

                      Color? dotColor;
                      if (record != null) {
                        switch (record.status) {
                          case AttendanceStatus.present:
                            dotColor = palette.present;
                            break;
                          case AttendanceStatus.halfDay:
                            dotColor = palette.halfDay;
                            break;
                          case AttendanceStatus.absent:
                            dotColor = palette.absent;
                            break;
                          case AttendanceStatus.leave:
                            dotColor = palette.leave;
                            break;
                        }
                      }

                      return InkWell(
                        onTap: () {
                          setState(() => _selectedDate = date);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? palette.primary.withOpacity(0.2)
                                : (isSunday ? palette.cardAlt : Colors.transparent),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? palette.primary : palette.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: GoogleFonts.inter(
                                  fontSize: AppText.caption,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSunday ? palette.pending : palette.textPrimary,
                                ),
                              ),
                              if (dotColor != null) ...[
                                const SizedBox(height: 3),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Attendance Action Pad for Selected Date
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
                      Text(
                        AppDateFormatter.formatDayDate(_selectedDate),
                        style: GoogleFonts.inter(fontSize: AppText.title, fontWeight: FontWeight.w700),
                      ),
                      if (selectedRecord != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Status: ${selectedRecord.status.displayName}',
                            style: GoogleFonts.inter(
                              fontSize: AppText.label,
                              fontWeight: FontWeight.w700,
                              color: palette.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _markAttendance(AttendanceStatus.present),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.present,
                            foregroundColor: palette.onPrimary,
                          ),
                          child: const Text('Present'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _markAttendance(AttendanceStatus.halfDay),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.halfDay,
                            foregroundColor: palette.onPrimary,
                          ),
                          child: const Text('Half Day'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _markAttendance(AttendanceStatus.absent),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.absent,
                            foregroundColor: palette.onPrimary,
                          ),
                          child: const Text('Absent'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _markAttendance(AttendanceStatus.leave),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.leave,
                            foregroundColor: palette.onPrimary,
                          ),
                          child: const Text('Paid Leave'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBadge(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: GoogleFonts.inter(
                fontSize: AppText.title,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: AppText.label,
                fontWeight: FontWeight.w600,
                color: context.palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
