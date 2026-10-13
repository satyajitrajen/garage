import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../data/api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/error_message.dart';
import 'auth_validators.dart';
import '../../l10n/app_language.dart';

/// Logged-out email verification: resend the link or confirm a token.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  final String? email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _form = GlobalKey<FormState>();
  // Own Form for the email field so "Resend" validates only the email while
  // "Confirm verification" keeps validating just the token.
  final _emailForm = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _token = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (!(_emailForm.currentState?.validate() ?? false)) return;
    try {
      await context.read<AuthProvider>().requestVerify(email: _email.text);
      if (!mounted) return;
      showAppSnackBar(context, tr('If the email exists, a link was sent.'));
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, tr('Request failed. Please try again.'),
          type: SnackBarType.error);
    }
  }

  Future<void> _confirm() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    try {
      await context.read<AuthProvider>().verify(token: _token.text);
      if (!mounted) return;
      showAppSnackBar(context, tr('Email verified. Please sign in.'),
          type: SnackBarType.success);
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, tr('Verification failed. Please try again.'),
          type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Verify email'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingScreen, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tr('Verify your email'),
                        style: GoogleFonts.poppins(
                            fontSize: AppText.title,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      tr('We sent a link after registration. Paste the token here or resend the email.'),
                      style: GoogleFonts.poppins(
                          fontSize: AppText.body,
                          color: context.palette.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: _emailForm,
                      child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: tr('Email'),
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: validateEmail,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: auth.isBusy ? null : _resend,
                      child: Text(tr('Resend verification email')),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _token,
                      decoration: InputDecoration(
                        labelText: tr('Verification token'),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.mark_email_read_outlined),
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Token is required' : null,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: auth.isBusy ? null : _confirm,
                      child: Text(tr('Confirm verification')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
