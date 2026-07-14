import 'package:dartz/dartz.dart';

import '../../domain/auth/failures/auth_failure.dart';
import '../../domain/auth/repositories/i_auth_repository.dart';
import '../../domain/auth/value_objects/auth_token.dart';
import '../../domain/auth/value_objects/email.dart';
import '../../domain/auth/value_objects/password.dart';
import '../../domain/auth/value_objects/username.dart';

/// Caso de uso de registro. Valida email, username y política de contraseña
/// (VOs) antes de tocar la red; todo fallo de VO se traduce a
/// UnexpectedFailure defensivo (el formulario ya los previene en la UI). Los
/// valores crudos de username/password viajan al repo (el back re-valida).
class RegisterUseCase {
  final IAuthRepository _repo;
  RegisterUseCase(this._repo);

  Future<Either<AuthFailure, AuthToken>> execute(
      String email, String username, String password) async {
    final Email emailVo;
    try {
      emailVo = Email(email);
      Username(username); // valida 3-20 chars, letras/dígitos/guion bajo
      Password(password); // valida ≥8
    } on ArgumentError {
      return const Left(UnexpectedFailure());
    }
    return _repo.register(emailVo, username, password);
  }
}
