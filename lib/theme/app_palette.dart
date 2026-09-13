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
    required this.blueGradient,
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
  final List<Color> bannerGradient, cardGradient, blueGradient;
  final Map<ExpenseCategory, Color> categoryColors;

  static const light = AppPalette(
    background: Color(0xFFF8FAFD),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    border: Color(0xFFEEF2F6),
    divider: Color(0xFFF1F5F9),
    primary: Color(0xFF0284C7),
    primaryLight: Color(0xFF38BDF8),
    primaryDark: Color(0xFF0369A1),
    accent: Color(0xFF0EA5E9),
    onPrimary: Color(0xFFFFFFFF),
    paid: Color(0xFF10B981),
    partial: Color(0xFFF59E0B),
    pending: Color(0xFFEF4444),
    inProgress: Color(0xFF0EA5E9),
    received: Color(0xFF8B5CF6),
    ready: Color(0xFF059669),
    delivered: Color(0xFF10B981),
    cancelled: Color(0xFFEF4444),
    present: Color(0xFF10B981),
    halfDay: Color(0xFFF59E0B),
    absent: Color(0xFFEF4444),
    leave: Color(0xFF8B5CF6),
    badgeRedBg: Color(0xFFFEE2E2),
    badgeRedIcon: Color(0xFFEF4444),
    badgeOrangeBg: Color(0xFFFEF3C7),
    badgeOrangeIcon: Color(0xFFF59E0B),
    badgePurpleBg: Color(0xFFEDE9FE),
    badgePurpleIcon: Color(0xFF8B5CF6),
    badgeGreenBg: Color(0xFFD1FAE5),
    badgeGreenIcon: Color(0xFF10B981),
    badgeBlueBg: Color(0xFFE0F2FE),
    badgeBlueIcon: Color(0xFF0EA5E9),
    paperBg: Color(0xFFFFFFFF),
    paperHeaderBg: Color(0xFFF1F5F9),
    bannerGradient: [Color(0xFFFBE6F2), Color(0xFFFFF0D6), Color(0xFFD4F8EB), Color(0xFFA7F3D0)],
    cardGradient: [Color(0xFFFBE6F2), Color(0xFFFFF0D6), Color(0xFFD4F8EB), Color(0xFFA7F3D0)],
    blueGradient: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
    categoryColors: {
      ExpenseCategory.rent: Color(0xFF8B5CF6),
      ExpenseCategory.electricityUtilities: Color(0xFFF59E0B),
      ExpenseCategory.internetPhone: Color(0xFF0EA5E9),
      ExpenseCategory.toolsEquipment: Color(0xFF64748B),
      ExpenseCategory.consumables: Color(0xFF10B981),
      ExpenseCategory.partsStock: Color(0xFFEF4444),
      ExpenseCategory.staffFood: Color(0xFF10B981),
      ExpenseCategory.fuelGenerator: Color(0xFFEF4444),
      ExpenseCategory.miscellaneous: Color(0xFF64748B),
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
