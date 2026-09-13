import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_dimens.dart';
import 'app_palette.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();
    const palette = AppPalette.light;
    return ThemeData(
      useMaterial3: true,
      extensions: const <ThemeExtension<dynamic>>[AppPalette.light],
      brightness: Brightness.light,
      primaryColor: palette.primary,
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme.light(
        primary: palette.primary,
        secondary: palette.primaryDark,
        surface: palette.surface,
        error: palette.absent,
        onPrimary: palette.onPrimary,
        onSecondary: Colors.white,
        onSurface: palette.textPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
            fontSize: 24, fontWeight: FontWeight.w700, color: palette.textPrimary, letterSpacing: -0.5),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            fontSize: 20, fontWeight: FontWeight.w700, color: palette.textPrimary, letterSpacing: -0.3),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontSize: 17, fontWeight: FontWeight.w600, color: palette.textPrimary),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
            fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.textPrimary),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            fontSize: 14, fontWeight: FontWeight.w500, color: palette.textPrimary),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            fontSize: 13, fontWeight: FontWeight.w400, color: palette.textSecondary),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
            fontSize: 11.5, fontWeight: FontWeight.w400, color: palette.textMuted),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
            fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelMedium: baseTextTheme.labelMedium?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w500),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
            fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: palette.textPrimary,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          side: BorderSide(color: palette.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.cardAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(color: palette.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide(color: palette.absent),
        ),
        hintStyle: GoogleFonts.inter(color: palette.textMuted, fontSize: 13),
        labelStyle: GoogleFonts.inter(
            color: palette.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: palette.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
          textStyle: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusFAB),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1, space: 1),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.primary,
        unselectedLabelColor: palette.textMuted,
        indicatorColor: palette.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? palette.primary : palette.textMuted),
        trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? palette.primaryLight : palette.border),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? palette.primary : Colors.transparent),
        side: BorderSide(color: palette.textMuted, width: 1.4),
      ),
    );
  }
}
