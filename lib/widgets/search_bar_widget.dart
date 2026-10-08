import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';
import '../theme/app_text.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final Widget? trailing;

  const CustomSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      // Clip to the rounded shape so nothing inside paints over the border.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusInput),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(Icons.search_rounded, color: palette.textMuted, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.poppins(
                fontSize: AppText.subtitle,
                color: palette.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.poppins(
                  color: palette.textMuted,
                  fontSize: AppText.body,
                ),
                // The app's input theme fills fields grey; inside this bar
                // that drew a square box over the right edge and border.
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                isDense: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: palette.textMuted),
              onPressed: () {
                controller.clear();
                onChanged?.call('');
                onClear?.call();
              },
            ),
          if (trailing != null) ...[
            Container(
              height: 24,
              width: 1,
              color: palette.border,
            ),
            trailing!,
          ],
        ],
      ),
    );
  }
}
