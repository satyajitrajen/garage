import 'package:flutter/material.dart';

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
