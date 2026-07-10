import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/auth/failures/auth_failure.dart';

void main() {
  test('each failure exposes a non-empty Spanish message', () {
    expect(const InvalidCredentials().message, 'Email o contraseña incorrectos');
    expect(const EmailAlreadyRegistered().message, 'Ese email ya está registrado');
    expect(const NetworkFailure().message, 'Sin conexión. Intenta de nuevo');
    expect(const UnexpectedFailure().message, 'Algo salió mal. Intenta más tarde');
  });

  test('subclasses are AuthFailure', () {
    expect(const InvalidCredentials(), isA<AuthFailure>());
  });
}
