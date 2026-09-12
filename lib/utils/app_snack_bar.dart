import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Severity of an app-wide snack bar, mapped onto the status colors the
/// screens already use for this kind of feedback.
enum SnackBarType { success, error, info }

/// Shows a themed snack bar, hiding any currently visible one first so
/// rapid successive messages replace each other instead of queueing up.
void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarType type = SnackBarType.info,
}) {
  final Color background = switch (type) {
    // Emerald "paid" green, coral "pending" red and brand blue — the same
    // AppColors the screens show for success/error/neutral feedback today.
    SnackBarType.success => AppColors.paid,
    SnackBarType.error => AppColors.pending,
    SnackBarType.info => AppColors.primary,
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}
