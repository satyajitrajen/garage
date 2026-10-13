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
import 'reset_password_screen.dart';
import '../../l10n/app_language.dart';

/// Logged-out forgot-password step: request a reset email (always succeeds
/// server-side to avoid account enumeration).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    try {
      await context.read<AuthProvider>().forgot(email: _email.text);
      if (!mounted) return;
      setState(() => _sent = true);
      showAppSnackBar(context, tr('If the email exists, a reset link was sent.'));
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, tr('Request failed. Please try again.'),
          type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Reset password'))),
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
                    Text(tr('Forgot your password?'),
                        style: GoogleFonts.poppins(
                            fontSize: AppText.title,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      tr('Enter your account email and we will send a reset link.'),
                      style: GoogleFonts.poppins(
                          fontSize: AppText.body,
                          color: context.palette.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: tr('Email'),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: auth.isBusy ? null : _submit,
                      child: Text(_sent ? tr('Resend email') : tr('Send reset email')),
                    ),
                    if (_sent) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ResetPasswordScreen()),
                        ),
                        child: Text(tr('I have a reset token')),
                      ),
                    ],
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
