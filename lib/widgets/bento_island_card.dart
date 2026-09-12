import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class BentoIslandCard extends StatelessWidget {
  final int vehiclesInBay;
  final int pendingInvoices;
  final int activeJobCards;
  final int staffOnDuty;
  final String statusText;
  final VoidCallback? onVehiclesTap;
  final VoidCallback? onPendingInvoicesTap;
  final VoidCallback? onJobCardsTap;
  final VoidCallback? onStaffTap;
  final VoidCallback? onWizardTap;

  const BentoIslandCard({
    super.key,
    required this.vehiclesInBay,
    required this.pendingInvoices,
    required this.activeJobCards,
    required this.staffOnDuty,
    this.statusText = 'Peak Flow!',
    this.onVehiclesTap,
    this.onPendingInvoicesTap,
    this.onJobCardsTap,
    this.onStaffTap,
    this.onWizardTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? AppColors.cardGradientDark
              : AppColors.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 16, left: 14, right: 14, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------
          // TIER 1: STATUS CHIP HEADER
          // -------------------------------------------------------------
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0EA5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GARAGE STATUS: ',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // -------------------------------------------------------------
          // TIER 2: 4-QUADRANT TILES (2x2 Grid)
          // -------------------------------------------------------------
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2234) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildQuadrantTile(
                        icon: Icons.warning_rounded,
                        badgeBg: AppColors.badgeRedBg,
                        iconColor: AppColors.badgeRedIcon,
                        value: '$vehiclesInBay',
                        label: 'VEHICLES IN BAY',
                        onTap: onVehiclesTap,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildQuadrantTile(
                        icon: Icons.shield_rounded,
                        badgeBg: AppColors.badgeOrangeBg,
                        iconColor: AppColors.badgeOrangeIcon,
                        value: '$pendingInvoices',
                        label: 'PENDING DUES',
                        onTap: onPendingInvoicesTap,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuadrantTile(
                        icon: Icons.car_repair_rounded,
                        badgeBg: AppColors.badgePurpleBg,
                        iconColor: AppColors.badgePurpleIcon,
                        value: '$activeJobCards',
                        label: 'JOB CARDS',
                        onTap: onJobCardsTap,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildQuadrantTile(
                        icon: Icons.people_alt_rounded,
                        badgeBg: AppColors.badgeGreenBg,
                        iconColor: AppColors.badgeGreenIcon,
                        value: '$staffOnDuty',
                        label: 'STAFF ON DUTY',
                        onTap: onStaffTap,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // -------------------------------------------------------------
          // TIER 3: ACTION BANNER (EXACT USER GRADIENT)
          // -------------------------------------------------------------
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onWizardTap,
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? AppColors.cardGradientDark
                        : AppColors.bannerGradient,
                    stops: AppColors.bannerGradientStops,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA7F3D0).withValues(alpha: isDark ? 0.2 : 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Dark Squircle Icon (as in user screenshot)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF121726),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Service Wizard',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Create job card, bill & collect in 60s',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuadrantTile({
    required IconData icon,
    required Color badgeBg,
    required Color iconColor,
    required String value,
    required String label,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131927) : const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF242E42) : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Squircle Badge Icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 17),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
