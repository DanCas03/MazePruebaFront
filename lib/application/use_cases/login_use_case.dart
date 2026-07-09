import 'package:dartz/dartz.dart';

import '../../domain/auth/failures/auth_failure.dart';
import '../../domain/auth/repositories/i_auth_repository.dart';
import '../../domain/auth/value_objects/auth_token.dart';
import '../../domain/auth/value_objects/email.dart';

/// Caso de uso de inicio de sesión. Construye el VO Email (valida formato) y
/// delega en el puerto. Un email malformado que sortee la validación de la UI
/// se traduce a un fallo de dominio, no a una excepción que rompa la pantalla.
class LoginUseCase {
  final IAuthRepository _repo;
  LoginUseCase(this._repo);

  Future<Either<AuthFailure, AuthToken>> execute(
      String email, String password) async {
    final Email emailVo;
    try {
      emailVo = Email(email);
    } on ArgumentError {
      return const Left(InvalidCredentials());
    }
    return _repo.login(emailVo, password);
  }
}
