import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/error_message.dart';
import 'delete_account_dialog.dart';

/// The signed-in user's own account: display name, password, and sign out.
/// Garage details live in Garage settings; this is about the person.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _savingName = false;
  bool _savingPassword = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
        text: context.read<AuthProvider>().user?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (!(_nameForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingName = true);
    try {
      await context.read<AuthProvider>().updateName(_name.text.trim());
      if (!mounted) return;
      showAppSnackBar(context, 'Name updated.');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingPassword = true);
    try {
      await context.read<AuthProvider>().changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
          );
      if (!mounted) return;
      _current.clear();
      _new.clear();
      _confirm.clear();
      showAppSnackBar(
          context, 'Password changed. Other devices have been signed out.');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in with your email and password.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final palette = context.palette;
    final user = auth.user;
    final m = auth.currentMembership;
    final name = user?.name ?? '';
    final initial = name.isEmpty ? '?' : name.trim()[0].toUpperCase();
    final sectionStyle = GoogleFonts.poppins(
        fontSize: AppText.subtitle, fontWeight: FontWeight.w700);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: palette.primary,
                child: Text(initial,
                    style: GoogleFonts.poppins(
                        fontSize: AppText.headline,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.poppins(
                            fontSize: AppText.headline,
                            fontWeight: FontWeight.w600)),
                    Text(user?.email ?? '',
                        style: GoogleFonts.poppins(
                            fontSize: AppText.caption,
                            color: palette.textSecondary)),
                    if (m != null)
                      Text('${m.role[0].toUpperCase()}${m.role.substring(1)} · ${m.garageName}',
                          style: GoogleFonts.poppins(
                              fontSize: AppText.caption,
                              color: palette.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Your name', style: sectionStyle),
          const SizedBox(height: 10),
          Form(
            key: _nameForm,
            child: TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _saveName(),
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Name is required';
                if (t.length > 100) return 'Keep it under 100 characters';
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _savingName ? null : _saveName,
            child: _savingName
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save name'),
          ),
          const SizedBox(height: 32),
          Text('Change password', style: sectionStyle),
          const SizedBox(height: 10),
          Form(
            key: _passwordForm,
            child: Column(
              children: [
                _passwordField(_current, 'Current password',
                    validator: (v) => (v ?? '').isEmpty
                        ? 'Enter your current password'
                        : null),
                const SizedBox(height: 12),
                _passwordField(_new, 'New password (min 8 characters)',
                    validator: (v) => (v ?? '').length < 8
                        ? 'Use at least 8 characters'
                        : null),
                const SizedBox(height: 12),
                _passwordField(_confirm, 'Confirm new password',
                    validator: (v) =>
                        v != _new.text ? 'Passwords do not match' : null),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _savingPassword ? null : _changePassword,
            child: _savingPassword
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Change password'),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.primary,
              side: BorderSide(color: palette.primary),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showDeleteAccountDialog(context),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
  }

  Widget _passwordField(TextEditingController c, String label,
      {required String? Function(String?) validator}) {
    return TextFormField(
      controller: c,
      obscureText: _obscure,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: validator,
    );
  }
}
