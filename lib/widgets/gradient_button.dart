import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget label;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? textColor;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.padding,
    this.width,
    this.height,
    this.borderRadius = AppDimens.radiusButton,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isEnabled = onPressed != null;
    final contentColor = textColor ?? palette.onPrimary;

    final effectiveTextStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: isEnabled ? contentColor : contentColor.withValues(alpha: 0.5),
    );

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.55,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: palette.primary,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    IconTheme(
                      data: IconThemeData(
                        color: isEnabled ? contentColor : contentColor.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      child: icon!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  DefaultTextStyle(
                    style: effectiveTextStyle,
                    child: label,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GradientFloatingActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final Widget label;

  const GradientFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusFAB),
        boxShadow: AppDimens.accentGlow(palette.primary),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimens.radiusFAB),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme(
                  data: IconThemeData(color: palette.onPrimary, size: 20),
                  child: icon,
                ),
                const SizedBox(width: 8),
                DefaultTextStyle(
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: palette.onPrimary,
                  ),
                  child: label,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
