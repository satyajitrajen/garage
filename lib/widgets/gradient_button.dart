import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

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
    this.borderRadius = 16,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = onPressed != null;

    final contentColor = textColor ?? (isDark ? Colors.white : const Color(0xFF0F172A));

    final effectiveTextStyle = GoogleFonts.poppins(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: isEnabled ? contentColor : contentColor.withValues(alpha: 0.5),
    );

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.55,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppColors.cardGradientDark : AppColors.bannerGradient,
            stops: AppColors.bannerGradientStops,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA7F3D0).withValues(alpha: isDark ? 0.15 : 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.cardGradientDark : AppColors.bannerGradient,
          stops: AppColors.bannerGradientStops,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusFAB),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA7F3D0).withValues(alpha: isDark ? 0.2 : 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
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
                  data: IconThemeData(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    size: 20,
                  ),
                  child: icon,
                ),
                const SizedBox(width: 8),
                DefaultTextStyle(
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
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
