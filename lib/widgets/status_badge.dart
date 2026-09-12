import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/job_card.dart';
import '../models/quotation.dart';
import '../models/staff.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isCompact;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isCompact = false,
  });

  factory StatusBadge.fromInvoiceStatus(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return const StatusBadge(
          label: 'PAID',
          color: AppColors.paid,
          icon: Icons.check_circle_outline_rounded,
        );
      case InvoiceStatus.partial:
        return const StatusBadge(
          label: 'PARTIAL',
          color: AppColors.partial,
          icon: Icons.timelapse_rounded,
        );
      case InvoiceStatus.pending:
        return const StatusBadge(
          label: 'PENDING',
          color: AppColors.pending,
          icon: Icons.error_outline_rounded,
        );
      case InvoiceStatus.cancelled:
        return const StatusBadge(
          label: 'CANCELLED',
          color: AppColors.textMuted,
          icon: Icons.cancel_outlined,
        );
    }
  }

  factory StatusBadge.fromJobStatus(JobStatus status) {
    switch (status) {
      case JobStatus.received:
        return StatusBadge(
          label: status.shortName.toUpperCase(),
          color: AppColors.received,
          icon: Icons.input_rounded,
        );
      case JobStatus.inspection:
        return StatusBadge(
          label: status.shortName.toUpperCase(),
          color: AppColors.accent,
          icon: Icons.search_rounded,
        );
      case JobStatus.inProgress:
        return StatusBadge(
          label: status.shortName.toUpperCase(),
          color: AppColors.inProgress,
          icon: Icons.build_rounded,
        );
      case JobStatus.waitingParts:
        return StatusBadge(
          label: status.shortName.toUpperCase(),
          color: AppColors.partial,
          icon: Icons.hourglass_top_rounded,
        );
      case JobStatus.readyForDelivery:
        return StatusBadge(
          label: status.shortName.toUpperCase(),
          color: AppColors.ready,
          icon: Icons.thumb_up_alt_outlined,
        );
      case JobStatus.delivered:
        return StatusBadge(
          label: status.shortName.toUpperCase(),
          color: AppColors.delivered,
          icon: Icons.verified_rounded,
        );
      case JobStatus.cancelled:
        return StatusBadge(
          label: status.shortName.toUpperCase(),
          color: AppColors.textMuted,
          icon: Icons.close_rounded,
        );
    }
  }

  factory StatusBadge.fromQuotationStatus(QuotationStatus status) {
    switch (status) {
      case QuotationStatus.draft:
        return const StatusBadge(
          label: 'DRAFT',
          color: AppColors.textMuted,
          icon: Icons.edit_note_rounded,
        );
      case QuotationStatus.sent:
        return const StatusBadge(
          label: 'SENT',
          color: AppColors.accent,
          icon: Icons.send_rounded,
        );
      case QuotationStatus.approved:
        return const StatusBadge(
          label: 'APPROVED',
          color: AppColors.paid,
          icon: Icons.check_circle_rounded,
        );
      case QuotationStatus.converted:
        return const StatusBadge(
          label: 'CONVERTED',
          color: AppColors.received,
          icon: Icons.swap_horiz_rounded,
        );
      case QuotationStatus.rejected:
        return const StatusBadge(
          label: 'DECLINED',
          color: AppColors.pending,
          icon: Icons.close_rounded,
        );
    }
  }

  factory StatusBadge.fromAttendanceStatus(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return const StatusBadge(
          label: 'P',
          color: AppColors.present,
          isCompact: true,
        );
      case AttendanceStatus.halfDay:
        return const StatusBadge(
          label: 'HD',
          color: AppColors.halfDay,
          isCompact: true,
        );
      case AttendanceStatus.absent:
        return const StatusBadge(
          label: 'A',
          color: AppColors.absent,
          isCompact: true,
        );
      case AttendanceStatus.leave:
        return const StatusBadge(
          label: 'L',
          color: AppColors.leave,
          isCompact: true,
        );
    }
  }

  factory StatusBadge.forExpenseCategory(
    ExpenseCategory category, {
    required AppPalette palette,
  }) {
    final color = palette.categoryColors[category]!;
    return StatusBadge(
      label: category.displayName,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 7 : 9,
        vertical: isCompact ? 3 : 4.5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null && !isCompact) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: isCompact ? 9.5 : 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
