// lib/presentation/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/state/auth_form_controller.dart';
import '../../../application/state/auth_form_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/auth/value_objects/email.dart';
import '../auth_strings.dart';
import '../widgets/auth_text_field.dart';
import 'register_screen.dart';

/// Pantalla de inicio de sesión. Presentación pura: valida en el cliente y
/// delega el envío en authFormControllerProvider. No navega ella misma tras el
/// login: el AuthGate resuelve la transición al cambiar AuthState.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate() {
    String? emailErr;
    String? passErr;
    try {
      Email(_email.text.trim());
    } on ArgumentError {
      emailErr = AuthStrings.emailInvalid;
    }
    if (_password.text.isEmpty) passErr = AuthStrings.passwordEmpty;
    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
    });
    return emailErr == null && passErr == null;
  }

  void _submit() {
    if (!_validate()) return;
    ref.read(authFormControllerProvider.notifier).login(
          _email.text.trim(),
          _password.text,
          remember: _remember,
        );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(authFormControllerProvider);
    final submitting = formState is FormSubmitting;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AuthStrings.loginTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: onBackground,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  controller: _email,
                  label: AuthStrings.emailLabel,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _password,
                  label: AuthStrings.passwordLabel,
                  obscureText: true,
                  errorText: _passwordError,
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? true),
                    ),
                    Text(AuthStrings.rememberMe,
                        style: TextStyle(color: onBackground)),
                    const Spacer(),
                    // "Olvidé contraseña": sin endpoint de reset en el back
                    // (fuera de alcance de front#15); deshabilitado como placeholder.
                    const TextButton(
                      onPressed: null,
                      child: Text(AuthStrings.forgotPassword),
                    ),
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
                      : const Text(AuthStrings.loginButton),
                ),
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                  child: const Text(AuthStrings.goToRegister),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
