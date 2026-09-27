import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/job_card.dart';
import '../models/quotation.dart';
import '../models/staff.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isCompact;

  /// Palette-backed color resolver used by the named status factories.
  ///
  /// The factories cannot be `const` anymore, but their signatures are
  /// unchanged; at build time the badge resolves its color from
  /// `context.palette` so dark screens get the dark-palette accents instead
  /// of baked-in light-theme constants. Direct constructions that pass
  /// [color] explicitly (e.g. `StatusBadge.forExpenseCategory`) keep the
  /// original mechanic: one color drives the 12%-alpha background, the 25%-
  /// alpha border, the icon and the text.
  final Color Function(AppPalette palette)? paletteColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isCompact = false,
  }) : paletteColor = null;

  const StatusBadge._themed({
    required this.label,
    this.icon,
    this.isCompact = false,
    required this.paletteColor,
  }) : color = Colors.transparent; // placeholder; resolved from palette in build

  factory StatusBadge.fromInvoiceStatus(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return StatusBadge._themed(
          label: 'PAID',
          icon: Icons.check_circle_outline_rounded,
          paletteColor: (p) => p.paid,
        );
      case InvoiceStatus.partial:
        return StatusBadge._themed(
          label: 'PARTIAL',
          icon: Icons.timelapse_rounded,
          paletteColor: (p) => p.partial,
        );
      case InvoiceStatus.pending:
        return StatusBadge._themed(
          label: 'PENDING',
          icon: Icons.error_outline_rounded,
          paletteColor: (p) => p.pending,
        );
      case InvoiceStatus.cancelled:
        return StatusBadge._themed(
          label: 'CANCELLED',
          icon: Icons.cancel_outlined,
          paletteColor: (p) => p.textMuted,
        );
    }
  }

  factory StatusBadge.fromJobStatus(JobStatus status) {
    switch (status) {
      case JobStatus.received:
        return StatusBadge._themed(
          label: status.shortName.toUpperCase(),
          icon: Icons.input_rounded,
          paletteColor: (p) => p.received,
        );
      case JobStatus.inspection:
        return StatusBadge._themed(
          label: status.shortName.toUpperCase(),
          icon: Icons.search_rounded,
          paletteColor: (p) => p.accent,
        );
      case JobStatus.inProgress:
        return StatusBadge._themed(
          label: status.shortName.toUpperCase(),
          icon: Icons.build_rounded,
          paletteColor: (p) => p.inProgress,
        );
      case JobStatus.waitingParts:
        return StatusBadge._themed(
          label: status.shortName.toUpperCase(),
          icon: Icons.hourglass_top_rounded,
          paletteColor: (p) => p.partial,
        );
      case JobStatus.readyForDelivery:
        return StatusBadge._themed(
          label: status.shortName.toUpperCase(),
          icon: Icons.thumb_up_alt_outlined,
          paletteColor: (p) => p.ready,
        );
      case JobStatus.delivered:
        return StatusBadge._themed(
          label: status.shortName.toUpperCase(),
          icon: Icons.verified_rounded,
          paletteColor: (p) => p.delivered,
        );
      case JobStatus.cancelled:
        return StatusBadge._themed(
          label: status.shortName.toUpperCase(),
          icon: Icons.close_rounded,
          paletteColor: (p) => p.textMuted,
        );
    }
  }

  factory StatusBadge.fromQuotationStatus(QuotationStatus status) {
    switch (status) {
      case QuotationStatus.draft:
        return StatusBadge._themed(
          label: 'DRAFT',
          icon: Icons.edit_note_rounded,
          paletteColor: (p) => p.textMuted,
        );
      case QuotationStatus.sent:
        return StatusBadge._themed(
          label: 'SENT',
          icon: Icons.send_rounded,
          paletteColor: (p) => p.accent,
        );
      case QuotationStatus.approved:
        return StatusBadge._themed(
          label: 'APPROVED',
          icon: Icons.check_circle_rounded,
          paletteColor: (p) => p.paid,
        );
      case QuotationStatus.converted:
        return StatusBadge._themed(
          label: 'CONVERTED',
          icon: Icons.swap_horiz_rounded,
          paletteColor: (p) => p.received,
        );
      case QuotationStatus.rejected:
        return StatusBadge._themed(
          label: 'DECLINED',
          icon: Icons.close_rounded,
          paletteColor: (p) => p.pending,
        );
    }
  }

  factory StatusBadge.fromAttendanceStatus(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return StatusBadge._themed(
          label: 'P',
          isCompact: true,
          paletteColor: (p) => p.present,
        );
      case AttendanceStatus.halfDay:
        return StatusBadge._themed(
          label: 'HD',
          isCompact: true,
          paletteColor: (p) => p.halfDay,
        );
      case AttendanceStatus.absent:
        return StatusBadge._themed(
          label: 'A',
          isCompact: true,
          paletteColor: (p) => p.absent,
        );
      case AttendanceStatus.leave:
        return StatusBadge._themed(
          label: 'L',
          isCompact: true,
          paletteColor: (p) => p.leave,
        );
    }
  }

  factory StatusBadge.forExpenseCategory(
    ExpenseCategory category, {
    required AppPalette palette,
  }) {
    // Defensive fallback: if a future ExpenseCategory value is missing from
    // the palette map, render muted instead of crashing on a null color.
    final color = palette.categoryColors[category] ?? palette.textMuted;
    return StatusBadge(
      label: category.displayName,
      color: color,
    );
  }

  /// 'IN PROGRESS' -> 'In progress'. Compact attendance codes stay as-is.
  static String _sentenceCase(String raw) {
    if (raw.isEmpty || raw.length <= 2) return raw;
    final lower = raw.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColor = paletteColor?.call(context.palette) ?? color;
    // One quiet style everywhere: tinted fill, coloured text, no icon or
    // border, sentence case. Status colour carries the meaning on its own.
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isCompact ? label : _sentenceCase(label),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: resolvedColor,
          fontSize: AppText.label,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
