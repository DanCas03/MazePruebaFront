// lib/presentation/auth/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/state/auth_controller.dart';
import '../../../application/state/auth_form_controller.dart';
import '../../../application/state/auth_form_state.dart';
import '../../../application/state/auth_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/auth/value_objects/email.dart';
import '../../../domain/auth/value_objects/password.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_text_field.dart';

/// Pantalla de registro. Igual que login pero con confirmación de contraseña y
/// política ≥8 (Password.minLength). No navega tras el registro: el AuthGate
/// resuelve la transición al autenticarse. A diferencia de LoginScreen (que
/// ES la ruta "/"), esta pantalla se apila con Navigator.push encima del
/// AuthGate: debe hacerse pop a sí misma al autenticarse para revelar el
/// HomeScreen que el AuthGate ya montó en la raíz (ver listener en [build]).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _remember = true;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    final l10n = AppLocalizations.of(context);
    String? emailErr;
    String? passErr;
    String? confirmErr;
    try {
      Email(_email.text.trim());
    } on ArgumentError {
      emailErr = l10n.emailInvalid;
    }
    if (_password.text.length < Password.minLength) {
      passErr = l10n.passwordTooShort;
    }
    if (_confirm.text != _password.text) {
      confirmErr = l10n.confirmMismatch;
    }
    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
      _confirmError = confirmErr;
    });
    return emailErr == null && passErr == null && confirmErr == null;
  }

  void _submit() {
    if (!_validate()) return;
    ref.read(authFormControllerProvider.notifier).register(
          _email.text.trim(),
          _password.text,
          remember: _remember,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Al autenticarse, RegisterScreen (que está apilada sobre el AuthGate en
    // "/") debe cerrarse para revelar el HomeScreen que el AuthGate ya montó
    // en la raíz.
    ref.listen(authControllerProvider, (previous, next) {
      next.whenData((state) {
        if (state is Authenticated && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    });
    final l10n = AppLocalizations.of(context);
    final formState = ref.watch(authFormControllerProvider);
    final submitting = formState is FormSubmitting;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.registerTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: onBackground,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  controller: _email,
                  label: l10n.emailLabel,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _password,
                  label: l10n.passwordLabel,
                  obscureText: true,
                  errorText: _passwordError,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _confirm,
                  label: l10n.confirmPasswordLabel,
                  obscureText: true,
                  errorText: _confirmError,
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? true),
                    ),
                    Text(l10n.rememberMe,
                        style: TextStyle(color: onBackground)),
                  ],
                ),
                if (formState is FormError) ...[
                  const SizedBox(height: 8),
                  Text(formState.failure.message,
                      style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.registerButton),
                ),
                TextButton(
                  onPressed:
                      submitting ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.goToLogin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
