import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class WorkshopEfficiencyGauge extends StatelessWidget {
  final int scorePercentage;
  final String statusLabel;

  const WorkshopEfficiencyGauge({
    super.key,
    this.scorePercentage = 92,
    this.statusLabel = 'Optimal Flow',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 170,
            height: 155,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Custom wireframe shield mesh background
                CustomPaint(
                  size: const Size(170, 155),
                  painter: _ShieldMeshPainter(isDark: isDark),
                ),

                // Center percentage text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$scorePercentage%',
                      style: GoogleFonts.poppins(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        color: const Color(0xFF047857), // Deep emerald
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShieldMeshPainter extends CustomPainter {
  final bool isDark;

  _ShieldMeshPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Create shield path
    final shieldPath = Path();
    shieldPath.moveTo(w * 0.15, h * 0.15);
    // Top slight dip
    shieldPath.quadraticBezierTo(w * 0.5, h * 0.05, w * 0.85, h * 0.15);
    // Right curve down
    shieldPath.quadraticBezierTo(w * 0.95, h * 0.50, w * 0.5, h * 0.96);
    // Left curve up
    shieldPath.quadraticBezierTo(w * 0.05, h * 0.50, w * 0.15, h * 0.15);
    shieldPath.close();

    // Soft emerald background glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF10B981).withValues(alpha: isDark ? 0.20 : 0.12),
          const Color(0xFF10B981).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(shieldPath, glowPaint);

    // Save clip to shield path for wireframe mesh
    canvas.save();
    canvas.clipPath(shieldPath);

    final meshPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.25)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Draw diamond wireframe grid lines
    const step = 14.0;
    for (double x = -h; x < w + h; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), meshPaint);
      canvas.drawLine(Offset(x, h), Offset(x + h, 0), meshPaint);
    }

    // Radial center clear overlay to keep the percentage readable
    final centerClearPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDark ? AppColors.darkBackground : AppColors.background).withValues(alpha: 0.85),
          (isDark ? AppColors.darkBackground : AppColors.background).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.48), radius: 46));
    canvas.drawCircle(Offset(w * 0.5, h * 0.48), 46, centerClearPaint);

    canvas.restore();

    // Shield outer border outline
    final borderPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: isDark ? 0.5 : 0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(shieldPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldMeshPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
