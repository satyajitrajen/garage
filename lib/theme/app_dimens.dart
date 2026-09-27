import 'package:flutter/material.dart';

class AppDimens {
  static const double radiusCard = 12;
  static const double radiusTile = 12;
  static const double radiusInput = 12;
  static const double radiusButton = 12;
  static const double radiusBadge = 8;
  static const double radiusFAB = 16;
  static const double radiusSheet = 24;
  static const double paddingScreen = 16;
  static const double paddingCard = 16;

  /// Reference elevation: cards `0 2 8 @3.5%`, floating panels `0 8 24 @6%`.
  // Cards are flat: a 1px border separates them. Shadow tokens stay so call
  // sites keep compiling, but render nothing.
  static List<BoxShadow> cardShadow(Color color) => const [];
  static List<BoxShadow> accentGlow(Color color) => const [];
}
