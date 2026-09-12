import 'package:flutter/material.dart';

class AppDimens {
  static const double radiusCard = 20;
  static const double radiusTile = 16;
  static const double radiusInput = 14;
  static const double radiusButton = 16;
  static const double radiusBadge = 12;
  static const double radiusFAB = 18;
  static const double radiusSheet = 24;
  static const double paddingScreen = 16;
  static const double paddingCard = 16;

  /// Standard card shadow (flat design: soft, low alpha) and floating accent glow.
  static List<BoxShadow> cardShadow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
      ];
  static List<BoxShadow> accentGlow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 6)),
      ];
}
