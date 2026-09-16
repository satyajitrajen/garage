import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Hides [child] when the current membership lacks [permission].
/// Owners always pass. Optionally shows [fallback] instead of nothing.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  final String permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    late final AuthProvider auth;
    try {
      auth = context.watch<AuthProvider>();
    } catch (_) {
      // No AuthProvider in scope — everything visible.
      return child;
    }
    // In mock mode (no session) everything is visible — matches the old
    // single-garage behaviour.
    if (!auth.isAuthenticated) return child;
    if (auth.can(permission)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Action helper: returns `true` when allowed, otherwise shows a SnackBar and
/// returns `false` so call sites can `if (!ensurePermission(...)) return;`.
bool ensurePermission(BuildContext context, String permission) {
  late final AuthProvider auth;
  try {
    auth = context.read<AuthProvider>();
  } catch (_) {
    return true;
  }
  if (!auth.isAuthenticated || auth.can(permission)) {
    return true;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('You do not have permission for this action.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  return false;
}
