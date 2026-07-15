import 'package:dartz/dartz.dart';

import '../../domain/auth/entities/user_profile.dart';
import '../../domain/auth/failures/auth_failure.dart';
import '../../domain/auth/repositories/i_auth_repository.dart';

/// Caso de uso que resuelve el perfil del usuario autenticado (`GET /auth/me`,
/// back#44) para el panel de cuenta (front#78). Delega en el puerto sin lógica
/// adicional: el token lo firma el interceptor y el fallo esperado (sesión
/// inválida, red) ya viene modelado como [AuthFailure] desde el repositorio.
class GetCurrentUserUseCase {
  final IAuthRepository _repo;
  GetCurrentUserUseCase(this._repo);

  Future<Either<AuthFailure, UserProfile>> execute() => _repo.me();
}
