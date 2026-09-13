# Transit Red Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin the garage app to the "Transit Red" system (red #F01018 accents, white surfaces, Inter, light-only) and add two hero surfaces (dashboard Book-a-Service card, invoice e-ticket with QR).

**Architecture:** The UI is palette-driven (`AppPalette` ThemeExtension + ThemeData + 69 `context.palette` sites), so the re-skin is a token flip plus per-surface gradient remapping; dark mode is deleted outright; two new hero widgets are added on existing data paths only.

**Tech Stack:** Flutter, provider, google_fonts (Inter), qr_flutter (new), existing GarageProvider/MockGarageRepository.

**Spec:** `docs/superpowers/specs/2026-09-13-transit-red-design-system-design.md` (§ numbers below refer to it)

**Working rules for every task:** explicit `git add` paths only (never `-A`/`.`); never stage docs plan/spec edits unless the task says so; `flutter analyze` must be "No issues found!" and `flutter test` all-green before every commit; new commit, never amend, never push.

---

### Task 1: Remove dark mode end-to-end

**Files:** `lib/theme/app_theme.dart`, `lib/theme/app_palette.dart`, `lib/main.dart`, `lib/providers/garage_provider.dart:104-111`, `lib/screens/dashboard/dashboard_screen.dart:92-101`, `lib/screens/more/more_menu_screen.dart:323-349`, `lib/screens/main_navigation_screen.dart`.

- [ ] **Step 1: Delete the dark ThemeData.** In `lib/theme/app_theme.dart` remove the entire `static ThemeData get darkTheme { ... }` getter (lines 188–366). The file then contains only `lightTheme`. (Keep all `AppColors`/`GoogleFonts.poppins` references in `lightTheme` for now — Task 4 rewrites them.)

- [ ] **Step 2: Delete the dark palette instance.** In `lib/theme/app_palette.dart` remove `static const dark = AppPalette(...)` entirely (the second const instance, around lines 106–180). Keep `static const light = ...` and the class body unchanged. Also delete the threshold-lerp special-casing ONLY if it references `dark` (it doesn't — `copyWith() => this` and `lerp` are instance methods; leave them).

- [ ] **Step 3: Simplify main.dart.** Replace the whole `NexoryGarageApp.build` with:

```dart
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GarageProvider>(
      create: (_) => GarageProvider(MockGarageRepository())..load(),
      child: MaterialApp(
        title: 'Nexory Garage Management',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainNavigationScreen(),
      ),
    );
  }
```

(the `Selector<GarageProvider, bool>` wrapper, `darkTheme:` and `themeMode:` lines are gone; `provider` import stays for ChangeNotifierProvider).

- [ ] **Step 4: Remove the toggle from the provider.** Delete `lib/providers/garage_provider.dart` lines 104–111:

```dart
  // Theme mode toggle
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
```

- [ ] **Step 5: Remove toggle UI.** In `dashboard_screen.dart` delete the theme IconButton in `actions:` (the one with `provider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded`, ~:93-100). In `more_menu_screen.dart` delete the `SwitchListTile(...)` block and the `const Divider(height: 1)` immediately above it (~:323-349) — the settings card keeps its other ListTiles.

- [ ] **Step 6: De-isDark `main_navigation_screen.dart`.** The nav file has an `isDark` local and `_buildNavItem(..., required bool isDark)`:
  - Delete the `final isDark = Theme.of(context).brightness == Brightness.dark;` local.
  - `_buildNavItem`: drop the `isDark` parameter and all its call-site arguments; replace the selected-chip ternary (~:170-183) with the LIGHT branch only:

```dart
                  decoration: BoxDecoration(
                    color: isSelected ? context.palette.textPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
```

  - Read the rest of `_buildNavItem` and remove any other `isDark` ternaries the same way (keep the light-branch value).
  - The nav container border ternary `Colors.white.withValues(alpha: isDark ? 0.15 : 0.8)` → `Colors.white.withValues(alpha: 0.8)` (Task 2 replaces this container anyway).

- [ ] **Step 7: Gates.** `flutter analyze` → No issues found! (fix any now-unused import/local it reports). `flutter test` → 22/22.

- [ ] **Step 8: Commit**

```bash
git add lib/theme/app_theme.dart lib/theme/app_palette.dart lib/main.dart lib/providers/garage_provider.dart lib/screens/dashboard/dashboard_screen.dart lib/screens/more/more_menu_screen.dart lib/screens/main_navigation_screen.dart
git commit -m "refactor: remove dark mode (light-only app)"
```

---

### Task 2: Transit Red palette + gradient consumer remap

**Files:** `lib/theme/app_palette.dart`, `lib/screens/dashboard/dashboard_screen.dart`, `lib/screens/more/more_menu_screen.dart`, `lib/screens/main_navigation_screen.dart`, `lib/screens/expenses/expenses_list_screen.dart`, `lib/screens/payments/payment_collection_screen.dart`.

- [ ] **Step 1: Revalue the light palette.** In `app_palette.dart` replace the values of `static const light = AppPalette(...)` with (field names are the existing constructor params — keep the `categoryColors` KEYS exactly as they are today, only change the Color values; keys in order get red, amber, green, blue, purple, then gray if there is a 6th):

```dart
  static const light = AppPalette(
    background: Color(0xFFF5F4F4),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF8F8F8),
    textPrimary: Color(0xFF171717),
    textSecondary: Color(0xFF656565),
    textMuted: Color(0xFF989898),
    border: Color(0xFFE8E8E8),
    divider: Color(0xFFEEEEEE),
    primary: Color(0xFFF01018),
    primaryLight: Color(0xFFFFF0F1),
    primaryDark: Color(0xFFD90E16),
    accent: Color(0xFFF01018),
    onPrimary: Color(0xFFFFFFFF),
    paid: Color(0xFF25A75B),
    partial: Color(0xFFF59E0B),
    pending: Color(0xFFF59E0B),
    inProgress: Color(0xFFF59E0B),
    received: Color(0xFF656565),
    ready: Color(0xFF25A75B),
    delivered: Color(0xFF25A75B),
    cancelled: Color(0xFF989898),
    present: Color(0xFF25A75B),
    halfDay: Color(0xFFF59E0B),
    absent: Color(0xFFEF4444),
    leave: Color(0xFF989898),
    badgeRedBg: Color(0xFFFFF0F1),
    badgeRedIcon: Color(0xFFF01018),
    badgeOrangeBg: Color(0xFFFEF3E2),
    badgeOrangeIcon: Color(0xFFB45309),
    badgePurpleBg: Color(0xFFF3E8FF),
    badgePurpleIcon: Color(0xFF7E22CE),
    badgeGreenBg: Color(0xFFE7F6EE),
    badgeGreenIcon: Color(0xFF1E7E46),
    badgeBlueBg: Color(0xFFE8F1FD),
    badgeBlueIcon: Color(0xFF1D4ED8),
    paperBg: Color(0xFFFFFFFF),
    paperHeaderBg: Color(0xFFF8F8F8),
    bannerGradient: [Color(0xFF1A1A1A), Color(0xFF111111)],
    cardGradient: [Color(0xFFFFFFFF), Color(0xFFF8F8F8)],
    blueGradient: [Color(0xFFF01018), Color(0xFFD90E16)],
    categoryColors: { /* same keys, values: 0xFFF01018, 0xFFF59E0B, 0xFF25A75B, 0xFF1D4ED8, 0xFF7E22CE (+ 0xFF656565 if a 6th key exists) */ },
  );
```

- [ ] **Step 2: Rename `blueGradient` → `brandGradient`.** In `app_palette.dart`: rename the constructor param, field (`final List<Color> bannerGradient, cardGradient, blueGradient;` → `... brandGradient;`) and the light instance key. Then update all call sites (grep confirms exactly these): `payment_collection_screen.dart:238`, `dashboard_screen.dart:52`, `more_menu_screen.dart:73` → `palette.brandGradient`.

- [ ] **Step 3: Remap old bannerGradient consumers (spec §3 table).**
  - `main_navigation_screen.dart` (~:80-94) nav container: replace gradient+border+glow with

```dart
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: palette.border, width: 1),
              boxShadow: AppDimens.cardShadow(palette.textPrimary),
            ),
```

  - `expenses_list_screen.dart` (~:135-151) KPI card: `gradient: LinearGradient(...)` → `color: palette.card`; border ternary → `Border.all(color: palette.border, width: 1)`; `boxShadow: AppDimens.cardShadow(palette.textPrimary)`. Remove the file's now-unused `isDark` local if analyzer flags it.
  - `more_menu_screen.dart` wizard banner (~:110-145): `colors: palette.bannerGradient, stops: AppColors.bannerGradientStops` → `colors: palette.brandGradient` (drop the `stops:` line). On this RED surface: title/subtitle text colors → `Colors.white` / `Colors.white70`; the icon chip keeps its shape with `color: Colors.white.withValues(alpha: 0.2)` and white icon; border → `Colors.white.withValues(alpha: 0.15)`; glow → `AppDimens.accentGlow(palette.primary)`.
  - `dashboard_screen.dart` (~:300-344) Quick Service action banner: same treatment as the more-menu banner (brandGradient, white text, glass icon chip, white@0.15 border, `accentGlow(palette.primary)`) AND replace the navy bolt chip literal (~:330-344) with:

```dart
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.bolt_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
```

  (the old `Color(0xFF121726)` literal and its "both themes" comment are deleted).

- [ ] **Step 4: Dashboard bento island on black.** The outer bento Container (~:138-150) keeps `colors: palette.bannerGradient` but drops `stops: AppColors.bannerGradientStops` (2-color gradient needs none) and uses `boxShadow: AppDimens.accentGlow(palette.primary)`. Status pill (~:154-203): bg ternary → `Colors.white.withValues(alpha: 0.10)`; border ternary → `Colors.white.withValues(alpha: 0.15)`; `'GARAGE STATUS: '` label color `palette.textSecondary` → `Colors.white70`; value keeps `palette.ready`. The AppBar car chip (~:48-57) `colors: palette.brandGradient` → `color: palette.primary` (solid, drop LinearGradient). Remove the file's `isDark` local if now unused.

- [ ] **Step 5: Gates.** `flutter analyze` → clean. `flutter test` → 22/22 (the smoke test boots the app with the new palette).

- [ ] **Step 6: Commit**

```bash
git add lib/theme/app_palette.dart lib/screens/dashboard/dashboard_screen.dart lib/screens/more/more_menu_screen.dart lib/screens/main_navigation_screen.dart lib/screens/expenses/expenses_list_screen.dart lib/screens/payments/payment_collection_screen.dart
git commit -m "feat: transit red palette with per-surface gradient remap"
```

---

### Task 3: AppDimens radii + shadow tuning

**Files:** `lib/theme/app_dimens.dart`.

- [ ] **Step 1: New values (spec §4).**

```dart
class AppDimens {
  static const double radiusCard = 16;
  static const double radiusTile = 12;
  static const double radiusInput = 12;
  static const double radiusButton = 12;
  static const double radiusBadge = 8;
  static const double radiusFAB = 16;
  static const double radiusSheet = 24;
  static const double paddingScreen = 16;
  static const double paddingCard = 16;

  /// Reference elevation: cards `0 2 8 @3.5%`, floating panels `0 8 24 @6%`.
  static List<BoxShadow> cardShadow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.035), blurRadius: 8, offset: const Offset(0, 2)),
      ];
  static List<BoxShadow> accentGlow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8)),
      ];
}
```

- [ ] **Step 2: Gates + commit.** `flutter analyze` clean, `flutter test` 22/22.

```bash
git add lib/theme/app_dimens.dart
git commit -m "style: transit radii and near-invisible elevation"
```

---

### Task 4: ThemeData rewrite (Inter + new component themes)

**Files:** `lib/theme/app_theme.dart` (full rewrite), `lib/utils/app_snack_bar.dart:19-21`.

- [ ] **Step 1: Replace app_theme.dart with:**

```dart
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
      colorScheme: const ColorScheme.light(
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
        iconTheme: const IconThemeData(color: palette.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          side: const BorderSide(color: palette.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.cardAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: const BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: const BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: const BorderSide(color: palette.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: const BorderSide(color: palette.absent),
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
          side: const BorderSide(color: palette.border, width: 1.2),
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
      dividerTheme: const DividerThemeData(color: palette.divider, thickness: 1, space: 1),
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
        side: const BorderSide(color: palette.textMuted, width: 1.4),
      ),
    );
  }
}
```

Note: `const palette = AppPalette.light;` works only if every field is const-able — it is (all const Colors/lists). If the analyzer complains about `palette.absent` in a const ColorScheme (it shouldn't — the instance is const), drop the local and inline `AppPalette.light.x`.

- [ ] **Step 2: Snack bar colors.** In `lib/utils/app_snack_bar.dart` replace the AppColors switch (lines 19-21) with:

```dart
    SnackBarType.success => AppPalette.light.paid,
    SnackBarType.error => AppPalette.light.absent,
    SnackBarType.info => AppPalette.light.textPrimary,
```

and swap the `app_colors.dart` import for `../theme/app_palette.dart`. (`info` deliberately moves from brand red to near-black — red is reserved for actions; spec §1 ratio rule.)

- [ ] **Step 3: Gates + commit.** `flutter analyze` clean, `flutter test` 22/22.

```bash
git add lib/theme/app_theme.dart lib/utils/app_snack_bar.dart
git commit -m "feat: transit ThemeData (Inter, red primary, new component themes)"
```

---

### Task 5: Typography sweep — Poppins → Inter

**Files:** every file under `lib/` containing `GoogleFonts.poppins` (~405 sites, ~40 files).

- [ ] **Step 1: Mechanical swap.** Replace `GoogleFonts.poppins(` → `GoogleFonts.inter(` in all files under `lib/` (PowerShell: `Get-ChildItem -Recurse lib -Filter *.dart | ForEach-Object { (Get-Content $_.FullName) -replace 'GoogleFonts\.poppins\(', 'GoogleFonts.inter(' | Set-Content $_.FullName }` — or per-file in the editor). `GoogleFonts.poppinsTextTheme(` → `GoogleFonts.interTextTheme(` if any remain outside app_theme.dart (Task 4 already rewrote it).

- [ ] **Step 2: Verify zero remnants.** `grep -r "poppins" lib/` → zero hits.

- [ ] **Step 3: Gates + commit.**

```bash
flutter analyze   # clean
flutter test      # 22/22
git add lib
git commit -m "style: Inter typography across the app"
```

(`git add lib` is acceptable HERE and only here — Task 5 intentionally spans all of lib/. If the repo has unexpected dirty files under lib, add them individually instead.)

---

### Task 6: Baseline widgets + AppColors retirement

**Files:** `lib/widgets/search_bar_widget.dart`, `lib/widgets/gradient_button.dart`, `lib/widgets/empty_state_widget.dart`, delete `lib/theme/app_colors.dart`.

- [ ] **Step 1: search_bar_widget.dart.** Replace the `app_colors.dart` import with `../theme/app_palette.dart` + add `import 'package:flutter/material.dart';` is already there. Replace:
  - `:48` `color: AppColors.textMuted` → capture `final palette = context.palette;` at the top of `build` and use `palette.textMuted`
  - `:56` `isDark ? Colors.white : AppColors.textPrimary` → `palette.textPrimary`
  - `:61` `isDark ? const Color(0xFF64748B) : AppColors.textMuted` → `palette.textMuted`
  - `:74` `AppColors.textMuted` → `palette.textMuted`
  - Delete the widget's `isDark` local. If the widget is a `StatelessWidget` without a BuildContext local, use `Theme.of(context).extension<AppPalette>()!` via the existing `AppPaletteContext` extension (`context.palette` — import `../theme/app_palette.dart`).

- [ ] **Step 2: gradient_button.dart — full rewrite (solid red CTA):**

```dart
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
```

(The class keeps its name/API — call sites unchanged.)

- [ ] **Step 3: empty_state_widget.dart.** Swap the `app_colors.dart` import for `app_palette.dart`; capture `final palette = context.palette;` in build; replace `AppColors.primary.withOpacity(0.08)` → `palette.primaryLight`, `AppColors.primary` → `palette.primary`, `isDark ? Colors.white : AppColors.textPrimary` → `palette.textPrimary`, `isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary` → `palette.textSecondary`; delete `isDark`.

- [ ] **Step 4: Verify no AppColors remain, then delete.** `grep -rn "AppColors\|app_colors" lib/` → only `lib/theme/app_colors.dart` itself. Then `git rm lib/theme/app_colors.dart`.

- [ ] **Step 5: Gates + commit.**

```bash
flutter analyze   # clean
flutter test      # 22/22
git add lib/widgets/search_bar_widget.dart lib/widgets/gradient_button.dart lib/widgets/empty_state_widget.dart
git commit -m "refactor: baseline widgets on palette; retire AppColors"
```

(`git rm` stages the deletion itself.)

---

### Task 7: Hero 1 — Book-a-Service dashboard card

**Files:** Create `lib/widgets/book_service_card.dart`; Modify `lib/screens/workflow/quick_service_wizard.dart:21-47`, `lib/screens/dashboard/dashboard_screen.dart` (body column), Test: `test/hero_widgets_test.dart` (new).

- [ ] **Step 1: Wizard preselect params.** In `quick_service_wizard.dart` change the widget to:

```dart
class QuickServiceWizard extends StatefulWidget {
  final Customer? initialCustomer;
  final Vehicle? initialVehicle;

  const QuickServiceWizard({super.key, this.initialCustomer, this.initialVehicle});

  @override
  State<QuickServiceWizard> createState() => _QuickServiceWizardState();
}
```

and in the State add (the class currently has no initState — add one above `dispose`):

```dart
  @override
  void initState() {
    super.initState();
    final customer = widget.initialCustomer;
    final vehicle = widget.initialVehicle;
    if (customer != null) _selectedCustomer = customer;
    if (vehicle != null) {
      _selectedVehicle = vehicle;
      _kmController.text = vehicle.currentKm.toString();
      _currentStep = 2;
    } else if (customer != null) {
      _currentStep = 1;
    }
  }
```

- [ ] **Step 2: Create `lib/widgets/book_service_card.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/vehicle.dart';
import '../providers/garage_provider.dart';
import '../theme/app_dimens.dart';
import '../theme/app_palette.dart';
import '../screens/workflow/quick_service_wizard.dart';
import '../screens/job_cards/create_job_card_screen.dart';

/// Dashboard hero card modeled on a travel booking search card:
/// customer + vehicle rows, a read-only date/odometer pill row, service
/// chips, and one red CTA. Uses only existing provider data and flows.
class BookServiceCard extends StatefulWidget {
  const BookServiceCard({super.key});

  @override
  State<BookServiceCard> createState() => _BookServiceCardState();
}

class _BookServiceCardState extends State<BookServiceCard> {
  Customer? _customer;
  Vehicle? _vehicle;
  bool _quickService = true;

  Future<void> _pickCustomer() async {
    final provider = context.read<GarageProvider>();
    final selected = await showModalBottomSheet<Customer>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusSheet)),
      ),
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        final customers = provider.customers;
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: customers.length,
            itemBuilder: (_, i) {
              final customer = customers[i];
              return ListTile(
                title: Text(customer.name),
                subtitle: Text(customer.phone),
                onTap: () => Navigator.pop(sheetContext, customer),
                tileColor: i.isOdd ? palette.cardAlt : null,
              );
            },
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      _customer = selected;
      if (_vehicle?.customerId != selected.id) _vehicle = null;
    });
  }

  Future<void> _pickVehicle() async {
    final customer = _customer;
    if (customer == null) {
      await _pickCustomer();
      return;
    }
    final provider = context.read<GarageProvider>();
    final vehicles = provider.getVehiclesForCustomer(customer.id);
    if (!mounted) return;
    if (vehicles.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      return;
    }
    final selected = await showModalBottomSheet<Vehicle>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusSheet)),
      ),
      builder: (sheetContext) {
        final palette = sheetContext.palette;
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: vehicles.length,
            itemBuilder: (_, i) {
              final vehicle = vehicles[i];
              return ListTile(
                title: Text('${vehicle.make} ${vehicle.model}'),
                subtitle: Text(vehicle.registrationNumber),
                onTap: () => Navigator.pop(sheetContext, vehicle),
                tileColor: i.isOdd ? palette.cardAlt : null,
              );
            },
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() => _vehicle = selected);
  }

  void _start() {
    final customer = _customer;
    if (customer == null) {
      _pickCustomer();
      return;
    }
    if (_quickService) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuickServiceWizard(initialCustomer: customer, initialVehicle: _vehicle),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateJobCardScreen(customer: customer, vehicle: _vehicle),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final today = DateTime.now();
    final provider = context.watch<GarageProvider>();
    final vehicleKm = _vehicle == null
        ? '—'
        : provider.getVehicleById(_vehicle!.id)?.currentKm.toString() ?? '—';

    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingCard),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: palette.border),
        boxShadow: AppDimens.cardShadow(palette.textPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book a Service', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          const SizedBox(height: 12),
          _bookingRow(
            palette: palette,
            label: 'Customer',
            value: _customer?.name ?? 'Select customer',
            icon: Icons.person_outline_rounded,
            hasValue: _customer != null,
            onTap: _pickCustomer,
          ),
          const SizedBox(height: 8),
          _bookingRow(
            palette: palette,
            label: 'Vehicle',
            value: _vehicle == null
                ? 'Select vehicle'
                : '${_vehicle!.make} ${_vehicle!.model} • ${_vehicle!.registrationNumber}',
            icon: Icons.directions_car_outlined,
            hasValue: _vehicle != null,
            onTap: _pickVehicle,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _pill(
                  palette: palette,
                  label: 'Date',
                  value: '${today.day} ${_month(today.month)} ${today.year}',
                  icon: Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pill(
                  palette: palette,
                  label: 'Odometer (km)',
                  value: vehicleKm,
                  icon: Icons.speed_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip(palette: palette, label: 'Quick Service', selected: _quickService,
                  onTap: () => setState(() => _quickService = true)),
              const SizedBox(width: 8),
              _chip(palette: palette, label: 'New Job Card', selected: !_quickService,
                  onTap: () => setState(() => _quickService = false)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                ),
              ),
              icon: const Icon(Icons.bolt_rounded, size: 20),
              label: Text(
                _quickService ? 'Start Quick Service' : 'Create Job Card',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _month(int month) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];

  Widget _bookingRow({
    required AppPalette palette,
    required String label,
    required String value,
    required IconData icon,
    required bool hasValue,
    required VoidCallback onTap,
  }) {
    return Material(
      color: palette.cardAlt,
      borderRadius: BorderRadius.circular(AppDimens.radiusTile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusTile),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: hasValue ? palette.primary : palette.border,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: palette.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: hasValue ? palette.textPrimary : palette.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 20, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required AppPalette palette,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.cardAlt,
        borderRadius: BorderRadius.circular(AppDimens.radiusTile),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: palette.textMuted)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.textPrimary)),
              ],
            ),
          ),
          Icon(icon, size: 16, color: palette.textMuted),
        ],
      ),
    );
  }

  Widget _chip({
    required AppPalette palette,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
          border: selected ? null : Border.all(color: palette.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 12.5, fontWeight: FontWeight.w600,
              color: selected ? palette.onPrimary : palette.textPrimary),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Insert on the dashboard.** In `dashboard_screen.dart`'s body column, immediately after the bento island Container (which ends right before the closing of the outer Column — locate the bento's closing brackets after the Quick Service action banner Material) add:

```dart
              const SizedBox(height: 16),
              const BookServiceCard(),
```

with import `../../widgets/book_service_card.dart`.

- [ ] **Step 4: Write the smoke test** `test/hero_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/data/mock/mock_garage_repository.dart';
import 'package:garage_manager/providers/garage_provider.dart';
import 'package:garage_manager/widgets/book_service_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BookServiceCard renders rows, chips and CTA', (tester) async {
    final provider = GarageProvider(MockGarageRepository());
    await provider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<GarageProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: BookServiceCard())),
      ),
    );

    expect(find.text('Book a Service'), findsOneWidget);
    expect(find.text('Select customer'), findsOneWidget);
    expect(find.text('Quick Service'), findsOneWidget);
    expect(find.text('New Job Card'), findsOneWidget);
    expect(find.text('Start Quick Service'), findsOneWidget);
  });
}
```

(If `GoogleFonts` inside the widget needs font loading in tests, pump with `pumpWidget(...); await tester.pumpAndSettle();` — google_fonts falls back silently in tests, so no extra setup is expected.)

- [ ] **Step 5: Gates + commit.** `flutter analyze` clean; `flutter test` → 23/23.

```bash
git add lib/widgets/book_service_card.dart lib/screens/workflow/quick_service_wizard.dart lib/screens/dashboard/dashboard_screen.dart test/hero_widgets_test.dart
git commit -m "feat: dashboard Book-a-Service hero card with wizard preselect"
```

---

### Task 8: Hero 2 — Invoice preview as e-ticket + QR

**Files:** `pubspec.yaml`, `lib/screens/invoices/invoice_preview_screen.dart`, Test: `test/hero_widgets_test.dart` (append).

- [ ] **Step 1: Add the dependency.** In `pubspec.yaml` under `dependencies:` add `qr_flutter: ^4.1.0`, then run `flutter pub get` (expect success).

- [ ] **Step 2: Add imports and helper in `invoice_preview_screen.dart`:**

```dart
import 'package:qr_flutter/qr_flutter.dart';
```

Add this private helper to the State class (builds the QR payload; UPI intent while money is owed, invoice number once settled):

```dart
  String _qrPayload(Invoice invoice, GarageProfile profile) {
    if (invoice.balanceDue > 0 && profile.upiId.isNotEmpty) {
      return 'upi://pay?pa=${profile.upiId}'
          '&pn=${Uri.encodeComponent(profile.name)}'
          '&am=${invoice.balanceDue.toStringAsFixed(2)}&cu=INR';
    }
    return invoice.invoiceNumber;
  }
```

(`GarageProfile` type comes from the provider's profile getter — add the model import if not already present: `import '../../models/garage_profile.dart';` — verify the actual model file name via the provider's import list before using the type name. If the profile type name differs, use `provider.profile` inline and `var`.)

- [ ] **Step 3: Build the ticket sections.** Inside the existing paper `Container` (the one using `palette.paperBg`), REPLACE the existing header band block (the `palette.paperHeaderBg` section from the earlier sweep) with the following section stack, inserted ABOVE the existing GSTIN/items table content:

```dart
            // -- Ticket header: brand + confirmation --
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.paperHeaderBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusCard)),
              ),
              child: Column(
                children: [
                  Text(
                    profile.name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.tagline,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: palette.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (invoice.status != InvoiceStatus.cancelled) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.primary, width: 1.6),
                      ),
                      child: Icon(
                        invoice.balanceDue > 0 ? Icons.schedule_rounded : Icons.check_rounded,
                        size: 20,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      invoice.balanceDue > 0 ? 'Awaiting Payment' : 'Payment Settled',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: palette.primary),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.cardAlt,
                      borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                    ),
                    child: Text(
                      'Invoice No: ${invoice.invoiceNumber}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: palette.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // -- QR card --
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusBadge),
                    border: Border.all(color: palette.border),
                  ),
                  child: QrImageView(
                    data: _qrPayload(invoice, profile),
                    size: 140,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            // -- Three-column summary: issue | total | due --
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _ticketColumn('Issued', AppDateFormatter.formatDate(invoice.invoiceDate), palette),
                  ),
                  Expanded(
                    child: _ticketColumn('Total', CurrencyFormatter.format(invoice.grandTotal), palette,
                        highlight: true),
                  ),
                  Expanded(
                    child: _ticketColumn(
                        'Due',
                        invoice.dueDate == null ? '—' : AppDateFormatter.formatDate(invoice.dueDate!),
                        palette),
                  ),
                ],
              ),
            ),
            // -- Customer / vehicle / paid-so-far row --
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: _ticketColumn('Customer', customer?.name ?? '—', palette)),
                  Expanded(
                      child: _ticketColumn('Vehicle', vehicle?.registrationNumber ?? '—', palette)),
                  Expanded(
                      child: _ticketColumn('Paid',
                          CurrencyFormatter.format(invoice.totalPaidAmount), palette)),
                ],
              ),
            ),
```

and add the column helper:

```dart
  Widget _ticketColumn(String label, String value, AppPalette palette, {bool highlight = false}) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: palette.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
              fontSize: highlight ? 13 : 12.5,
              fontWeight: FontWeight.w600,
              color: highlight ? palette.primary : palette.textPrimary),
        ),
      ],
    );
  }
```

Constraints: the paper Container's existing `BorderRadius.circular(AppDimens.radiusCard)` must become `BorderRadius.circular(AppDimens.radiusCard)` with the header's top corners matching — if the paper card clips children (add `clipBehavior: Clip.antiAlias` on the Container so the header's top radius aligns). Keep the existing cancelled banner, items table, totals, notes/terms, and bottom CTA sections exactly where they are; the new stack goes between the paper card's top and the items table. The existing bottom 'Record Payment'/'Bill Settled' logic is untouched.

- [ ] **Step 4: Append the ticket smoke test** to `test/hero_widgets_test.dart`:

```dart
  testWidgets('Invoice preview renders ticket QR and PNR pill', (tester) async {
    final provider = GarageProvider(MockGarageRepository());
    await provider.load();
    final invoice = provider.invoices.first;

    await tester.pumpWidget(
      ChangeNotifierProvider<GarageProvider>.value(
        value: provider,
        child: MaterialApp(
          home: InvoicePreviewScreen(invoiceId: invoice.id),
        ),
      ),
    );

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining(invoice.invoiceNumber), findsWidgets);
  });
```

with imports `package:qr_flutter/qr_flutter.dart` and `../lib/... ` adjusted: `import 'package:garage_manager/screens/invoices/invoice_preview_screen.dart';`. (QrImageView renders in widget tests; if the qr package needs asset loading, wrap the pump in `await tester.runAsync(() async {})` — only add if the test fails.)

- [ ] **Step 5: Gates + commit.** `flutter analyze` clean; `flutter test` → 24/24.

```bash
git add pubspec.yaml pubspec.lock lib/screens/invoices/invoice_preview_screen.dart test/hero_widgets_test.dart
git commit -m "feat: invoice preview as e-ticket with QR and journey summary"
```

---

### Task 9: Final verification

- [ ] **Step 1: Gates.** `flutter analyze` → No issues found!; `flutter test` → 24/24.
- [ ] **Step 2: Grep sweeps (expect the stated allowlists, zero otherwise):**
  - `GoogleFonts.poppins` in lib/ → 0
  - `isDark` in lib/ → 0
  - `AppColors` in lib/ → 0
  - `blueGradient` → 0; `brandGradient` ≥ 2 sites
  - `Color(0x` in lib/screens/** + lib/widgets/** → only `vehicle_selection_screen.dart` IND flag (~:253) and its comment
  - `AppPalette.dark` / `darkTheme` / `toggleTheme` → 0
- [ ] **Step 3: Fix any stray hit** per the canonical mapping (palette slots; `Colors.white` stays only on brandGradient/black banner surfaces), re-run gates, commit fixes as `fix: transit red final sweep`.
- [ ] **Step 4: Manual visual pass is the user's step** (desktop run is classifier-blocked for the agent): dashboard black bento + Book-a-Service card, Inter rendering, red CTAs, invoice ticket + QR, white bottom nav, more-menu without theme toggle.

---

## Self-review notes (completed during plan writing)

- **Spec coverage:** §3 palette → T2; §4 dims → T3; §5 typography → T4 (theme) + T5 (sweep); §6 dark removal → T1 + T6 step 4 (AppColors); §7 hero 1 → T7; §8 hero 2 → T8; §10 verification → T9; §11 qr_flutter → T8 step 1. Gap found & fixed: spec said "Full Service/Repair" chips — no backing data exists; plan uses `Quick Service`/`New Job Card` (both real flows), matching the amended spec §7.
- **Placeholders:** none — every code step is complete; two deliberate read-then-adapt instructions (categoryColors keys, profile type name) are bounded and verified against files read during planning.
- **Type consistency:** `brandGradient` rename used consistently (T2 field + 3 call sites); `AppPalette.light` remains the instance name everywhere; `BookServiceCard`/`_ticketColumn`/`_qrPayload` signatures match their usages; wizard params `initialCustomer`/`initialVehicle` match T7 usage.
