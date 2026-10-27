import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_message.dart';

/// Shown instead of the app while an account deletion is pending, so the
/// user either keeps the account or signs out knowing the date.
class DeletionPendingScreen extends StatefulWidget {
  const DeletionPendingScreen({super.key, required this.deleteAt});

  final DateTime deleteAt;

  @override
  State<DeletionPendingScreen> createState() => _DeletionPendingScreenState();
}

class _DeletionPendingScreenState extends State<DeletionPendingScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().cancelAccountDeletion();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not cancel. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM y').format(widget.deleteAt);
    final danger = Theme.of(context).colorScheme.error;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_forever_outlined, size: 48, color: danger),
                const SizedBox(height: 16),
                Text(
                  'Account scheduled for deletion',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your account and the garages you solely own will be '
                  'permanently deleted on $date. Cancel to keep everything '
                  'as it is.',
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: danger)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _cancel,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Cancel deletion'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed:
                      _busy ? null : () => context.read<AuthProvider>().logout(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
