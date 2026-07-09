import '../../domain/auth/failures/auth_failure.dart';

/// Estado del formulario de auth (State pattern sellado): la UI hace pattern
/// matching para deshabilitar el botón mientras envía y mostrar el error.
sealed class AuthFormState {
  const AuthFormState();
}

class FormIdle extends AuthFormState {
  const FormIdle();
}

class FormSubmitting extends AuthFormState {
  const FormSubmitting();
}

class FormError extends AuthFormState {
  final AuthFailure failure;
  const FormError(this.failure);
}
