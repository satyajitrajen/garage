import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_message.dart';

/// Confirms and schedules account deletion (App Store guideline 5.1.1(v)).
/// The user must enter their password and type DELETE; the account is then
/// deleted after a 7-day grace period and this device is signed out.
Future<void> showDeleteAccountDialog(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final at = await showDialog<DateTime>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
  if (at != null) {
    navigator.popUntil((r) => r.isFirst);
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: Text(
          'Your account will be deleted on ${DateFormat('d MMM y').format(at)}. '
          'Sign in before then to cancel.'),
    ));
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _confirmed => _confirm.text.trim() == 'DELETE';

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_confirmed) return;
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final at = await context.read<AuthProvider>().deleteAccount(_password.text);
      if (mounted) Navigator.pop(context, at);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not request deletion. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    final garage = context.read<AuthProvider>().currentMembership?.garageName;
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your account will be deleted 7 days from now. Until then you can '
              'sign in and cancel; after that it cannot be undone.\n\n'
              '• Garages you are the only owner of${garage == null ? '' : ' (such as $garage)'} '
              'are deleted with all their job cards, bills, customers, expenses and staff records. '
              'Your team will lose access to them.\n'
              '• Garages that have another owner keep running without you.\n'
              '• If you subscribed through the App Store, cancel it in your Apple ID settings; '
              'deleting the account does not stop Apple billing.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              enabled: !_busy,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _delete(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger),
          onPressed: _busy || !_confirmed ? null : _delete,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Delete account'),
        ),
      ],
    );
  }
}
