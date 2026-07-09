// lib/presentation/auth/auth_strings.dart
/// Textos ES centralizados del flujo de auth. Único lugar de literales para que
/// front#4 (i18n) los externalice a .arb sin cazar strings por las pantallas.
class AuthStrings {
  AuthStrings._();

  static const String loginTitle = 'Iniciar sesión';
  static const String registerTitle = 'Crear cuenta';
  static const String emailLabel = 'Email';
  static const String passwordLabel = 'Contraseña';
  static const String confirmPasswordLabel = 'Confirmar contraseña';
  static const String rememberMe = 'Recordarme';
  static const String forgotPassword = '¿Olvidaste tu contraseña?';
  static const String loginButton = 'Entrar';
  static const String registerButton = 'Registrarme';
  static const String goToRegister = '¿No tienes cuenta? Regístrate';
  static const String goToLogin = '¿Ya tienes cuenta? Inicia sesión';

  static const String emailInvalid = 'Email inválido';
  static const String passwordTooShort = 'Mínimo 8 caracteres';
  static const String passwordEmpty = 'Ingresa tu contraseña';
  static const String confirmMismatch = 'Las contraseñas no coinciden';
}
