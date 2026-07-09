import 'package:dartz/dartz.dart';

import '../../domain/auth/failures/auth_failure.dart';
import '../../domain/auth/repositories/i_auth_repository.dart';
import '../../domain/auth/value_objects/auth_token.dart';
import '../../domain/auth/value_objects/email.dart';
import '../../domain/auth/value_objects/password.dart';

/// Caso de uso de registro. Valida email y política de contraseña (Password VO,
/// ≥8) antes de tocar la red; ambos fallos de VO se traducen a UnexpectedFailure
/// defensivo (el formulario ya los previene en la UI). El valor crudo del
/// password viaja al repo (el back re-valida).
class RegisterUseCase {
  final IAuthRepository _repo;
  RegisterUseCase(this._repo);

  Future<Either<AuthFailure, AuthToken>> execute(
      String email, String password) async {
    final Email emailVo;
    try {
      emailVo = Email(email);
      Password(password); // valida ≥8
    } on ArgumentError {
      return const Left(UnexpectedFailure());
    }
    return _repo.register(emailVo, password);
  }
}
