import 'package:flutter/material.dart';

import '../models/expense.dart';

class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
    required this.onPrimary,
    required this.paid,
    required this.partial,
    required this.pending,
    required this.inProgress,
    required this.received,
    required this.ready,
    required this.delivered,
    required this.cancelled,
    required this.present,
    required this.halfDay,
    required this.absent,
    required this.leave,
    required this.badgeRedBg,
    required this.badgeRedIcon,
    required this.badgeOrangeBg,
    required this.badgeOrangeIcon,
    required this.badgePurpleBg,
    required this.badgePurpleIcon,
    required this.badgeGreenBg,
    required this.badgeGreenIcon,
    required this.badgeBlueBg,
    required this.badgeBlueIcon,
    required this.paperBg,
    required this.paperHeaderBg,
    required this.bannerGradient,
    required this.cardGradient,
    required this.brandGradient,
    required this.categoryColors,
  });

  final Color background, surface, card, cardAlt;
  final Color textPrimary, textSecondary, textMuted;
  final Color border, divider;
  final Color primary, primaryLight, primaryDark, accent, onPrimary;
  final Color paid, partial, pending, inProgress;
  final Color received, ready, delivered, cancelled;
  final Color present, halfDay, absent, leave;
  final Color badgeRedBg, badgeRedIcon;
  final Color badgeOrangeBg, badgeOrangeIcon;
  final Color badgePurpleBg, badgePurpleIcon;
  final Color badgeGreenBg, badgeGreenIcon;
  final Color badgeBlueBg, badgeBlueIcon;
  final Color paperBg, paperHeaderBg;
  final List<Color> bannerGradient, cardGradient, brandGradient;
  final Map<ExpenseCategory, Color> categoryColors;

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
    accent: Color(0xFF171717),
    onPrimary: Color(0xFFFFFFFF),
    paid: Color(0xFF25A75B),
    partial: Color(0xFFF59E0B),
    pending: Color(0xFFF59E0B),
    inProgress: Color(0xFF2563EB),
    received: Color(0xFF656565),
    ready: Color(0xFF25A75B),
    delivered: Color(0xFF25A75B),
    cancelled: Color(0xFF989898),
    present: Color(0xFF25A75B),
    halfDay: Color(0xFFF59E0B),
    absent: Color(0xFFDC2626),
    leave: Color(0xFF989898),
    badgeRedBg: Color(0xFFF1F1F1),
    badgeRedIcon: Color(0xFF3F3F3F),
    badgeOrangeBg: Color(0xFFF1F1F1),
    badgeOrangeIcon: Color(0xFF3F3F3F),
    badgePurpleBg: Color(0xFFF1F1F1),
    badgePurpleIcon: Color(0xFF3F3F3F),
    badgeGreenBg: Color(0xFFF1F1F1),
    badgeGreenIcon: Color(0xFF3F3F3F),
    badgeBlueBg: Color(0xFFF1F1F1),
    badgeBlueIcon: Color(0xFF3F3F3F),
    paperBg: Color(0xFFFFFFFF),
    paperHeaderBg: Color(0xFFF8F8F8),
    bannerGradient: [Color(0xFF1A1A1A), Color(0xFF111111)],
    cardGradient: [Color(0xFFFFFFFF), Color(0xFFF8F8F8)],
    brandGradient: [Color(0xFFF01018), Color(0xFFF01018)],
    // Expense categories are told apart by icon and label; colour adds noise.
    categoryColors: {
      ExpenseCategory.rent: Color(0xFF656565),
      ExpenseCategory.electricityUtilities: Color(0xFF656565),
      ExpenseCategory.internetPhone: Color(0xFF656565),
      ExpenseCategory.toolsEquipment: Color(0xFF656565),
      ExpenseCategory.consumables: Color(0xFF656565),
      ExpenseCategory.partsStock: Color(0xFF656565),
      ExpenseCategory.staffFood: Color(0xFF656565),
      ExpenseCategory.fuelGenerator: Color(0xFF656565),
      ExpenseCategory.miscellaneous: Color(0xFF656565),
    },
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
