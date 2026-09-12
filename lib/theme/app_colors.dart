import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors: Vibrant Tech Blue & Cyan (Replacing Black)
  static const Color primary = Color(0xFF0284C7); // Vibrant Tech Blue
  static const Color primaryLight = Color(0xFF38BDF8);
  static const Color primaryDark = Color(0xFF0369A1);
  
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color accent = Color(0xFF0EA5E9); // Vibrant Cyan Blue

  // Design System Backgrounds & Surfaces
  static const Color background = Color(0xFFF8FAFD); // Clean Porcelain
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF0A0F1D); // Deep Midnight
  static const Color darkSurface = Color(0xFF131927);
  static const Color darkCard = Color(0xFF1A2234);

  // The Exact Design System Gradient (Pink -> Peach Cream -> Mint -> Spring Pastel Green)
  static const List<Color> bannerGradient = [
    Color(0xFFFBE6F2), // Soft Lilac Pink
    Color(0xFFFFF0D6), // Warm Peach Cream
    Color(0xFFD4F8EB), // Soft Aqua Mint
    Color(0xFFA7F3D0), // Fresh Pastel Spring Green
  ];

  static const List<double> bannerGradientStops = [0.0, 0.32, 0.68, 1.0];

  static const List<Color> cardGradient = bannerGradient;
  static const List<Color> iridescentGradient = bannerGradient;

  static const List<Color> cardGradientDark = [
    Color(0xFF2A1C24),
    Color(0xFF2A2318),
    Color(0xFF142B24),
    Color(0xFF163528),
  ];

  static const List<Color> iridescentGradientDark = cardGradientDark;

  // Blue Accent Gradient for Highlights & Badges
  static const List<Color> blueGradient = [
    Color(0xFF0EA5E9),
    Color(0xFF2563EB),
  ];

  // 5 Squircle Metric Icon Badges
  // 1. Alert / Urgent (Red)
  static const Color badgeRedBg = Color(0xFFFEE2E2);
  static const Color badgeRedIcon = Color(0xFFEF4444);

  // 2. Risk / Warning (Amber/Orange)
  static const Color badgeOrangeBg = Color(0xFFFEF3C7);
  static const Color badgeOrangeIcon = Color(0xFFF59E0B);

  // 3. System / Active (Violet/Purple)
  static const Color badgePurpleBg = Color(0xFFEDE9FE);
  static const Color badgePurpleIcon = Color(0xFF8B5CF6);

  // 4. Safe / Paid / Completed (Emerald/Green)
  static const Color badgeGreenBg = Color(0xFFD1FAE5);
  static const Color badgeGreenIcon = Color(0xFF10B981);

  // 5. Azure / Info / Progress (Cyan/Blue)
  static const Color badgeBlueBg = Color(0xFFE0F2FE);
  static const Color badgeBlueIcon = Color(0xFF0EA5E9);

  // Status Colors
  static const Color paid = Color(0xFF10B981); // Emerald Green
  static const Color partial = Color(0xFFF59E0B); // Amber
  static const Color pending = Color(0xFFEF4444); // Coral Red
  static const Color inProgress = Color(0xFF0EA5E9); // Tech Sky Blue
  static const Color received = Color(0xFF8B5CF6); // Purple
  static const Color ready = Color(0xFF059669); // Deep Emerald
  static const Color delivered = Color(0xFF10B981); // Green

  // Attendance status
  static const Color present = Color(0xFF10B981);
  static const Color halfDay = Color(0xFFF59E0B);
  static const Color absent = Color(0xFFEF4444);
  static const Color leave = Color(0xFF8B5CF6);

  // Neutrals & Borders
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFEEF2F6);
  static const Color borderDark = Color(0xFF242E42);
  static const Color divider = Color(0xFFF1F5F9);
}
