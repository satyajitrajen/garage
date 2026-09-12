import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_snack_bar.dart';

/// Real outbound actions: dial a phone number, open a WhatsApp chat and
/// hand text to the OS share sheet. Every action degrades to an error
/// snack bar when no app on the device can handle it.
class ContactActions {
  ContactActions._();

  /// Dials [phone] through the device dialer (tel: deep link).
  static Future<void> call(BuildContext context, String phone) =>
      _launch(context, Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));

  /// Opens a WhatsApp chat with [phone] via the wa.me web link, optionally
  /// pre-filling the first [message].
  static Future<void> whatsapp(
    BuildContext context,
    String phone, {
    String message = '',
  }) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // The ?text= query is omitted entirely when there is no message.
    final uri = Uri.parse(
      message.isEmpty
          ? 'https://wa.me/$digits'
          : 'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
    await _launch(context, uri);
  }

  /// Opens the OS share sheet with [title] and [text].
  static Future<void> shareText(
    BuildContext context, {
    required String title,
    required String text,
  }) async {
    try {
      await SharePlus.instance.share(ShareParams(title: title, text: text));
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          'Could not open the share sheet',
          type: SnackBarType.error,
        );
      }
    }
  }

  /// Launches [uri] in an external app, showing an error snack bar when the
  /// launch fails or nothing on the device can handle the link.
  static Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        showAppSnackBar(
          context,
          'No app found to handle this action',
          type: SnackBarType.error,
        );
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          'No app found to handle this action',
          type: SnackBarType.error,
        );
      }
    }
  }
}
