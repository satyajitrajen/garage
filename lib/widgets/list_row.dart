import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_palette.dart';
import '../theme/app_text.dart';

/// Dense, full-width list row used by every list screen: title and one or two
/// muted detail lines on the left, a figure and a status on the right.
/// Rows sit edge to edge on a white surface separated by hairlines, so a long
/// list scans like a ledger instead of a stack of cards.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.overline,
    this.subtitle,
    this.detail,
    this.trailingTop,
    this.trailingBottom,
    this.onTap,
    this.onLongPress,
  });

  /// Small muted line above the title (e.g. a document number).
  final String? overline;
  final String title;
  final String? subtitle;
  final String? detail;
  final Widget? trailingTop;
  final Widget? trailingBottom;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    TextStyle muted(double size) =>
        GoogleFonts.poppins(fontSize: size, color: palette.textSecondary);
    return Material(
      color: palette.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (overline != null)
                      Text(overline!,
                          style: GoogleFonts.poppins(
                              fontSize: AppText.label, color: palette.textMuted)),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: AppText.body,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary)),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted(AppText.caption)),
                    if (detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(detail!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: AppText.label, color: palette.textMuted)),
                      ),
                  ],
                ),
              ),
              if (trailingTop != null || trailingBottom != null) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ?trailingTop,
                    if (trailingTop != null && trailingBottom != null)
                      const SizedBox(height: 6),
                    ?trailingBottom,
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Right-aligned money figure for [ListRow.trailingTop].
class RowAmount extends StatelessWidget {
  const RowAmount(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.poppins(
          fontSize: AppText.body,
          fontWeight: FontWeight.w600,
          color: color ?? context.palette.textPrimary));
}

/// Hairline between [ListRow]s, inset to the text column.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 16, color: context.palette.divider);
}
