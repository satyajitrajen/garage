import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_text.dart';

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
    // Status colors from the palette; info is near-black — brand red is
    // reserved for actions (spec color-usage ratio).
    SnackBarType.success => AppPalette.light.paid,
    SnackBarType.error => AppPalette.light.absent,
    SnackBarType.info => AppPalette.light.textPrimary,
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppText.body,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}
