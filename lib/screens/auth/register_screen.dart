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

/// First-run registration: creates the user + their garage (they become
/// owner) and signs them straight in.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  /// Set by the first submit attempt; from then on fields re-validate
  /// as they are edited, so fixed errors clear immediately.
  bool _submitted = false;
  final _name = TextEditingController();
  final _garage = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _garage.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_submitted) setState(() => _submitted = true);
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    try {
      await auth.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        garageName: _garage.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, errorMessage(e), type: SnackBarType.error);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, tr('Registration failed. Please try again.'),
          type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Create workshop account'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingScreen, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                autovalidateMode: _submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr('Your garage, your account'),
                      style: GoogleFonts.poppins(
                        fontSize: AppText.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('You will be the owner with full permissions.'),
                      style: GoogleFonts.poppins(
                          fontSize: AppText.body,
                          color: context.palette.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: tr('Your name'),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? tr('Name is required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _garage,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: tr('Garage name'),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store_outlined),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? tr('Garage name is required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: tr('Email'),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: tr('Password (min 8 characters)'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < 8
                          ? tr('Minimum 8 characters')
                          : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: auth.isBusy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: auth.isBusy
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.palette.onPrimary),
                              )
                            : Text(tr('Create account')),
                      ),
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
