import '../../l10n/app_language.dart';

/// Shared auth-field validators so every auth screen surfaces the exact
/// catalog strings from docs/UI_UX_GUIDELINES.md §7.
String? validateEmail(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return tr('Email is required');
  if (!t.contains('@') || !t.contains('.')) return 'Enter a valid email';
  return null;
}
