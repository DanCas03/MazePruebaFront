import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../value_objects/auth_token.dart';
import '../value_objects/email.dart';

/// Puerto (DIP) del lazo de autenticación remota. El dominio expone el contrato;
/// la infraestructura (Dio) lo implementa. Devuelve Either para modelar el fallo
/// esperado (credenciales, red) sin excepciones que crucen capas.
abstract interface class IAuthRepository {
  Future<Either<AuthFailure, AuthToken>> login(Email email, String password);
  Future<Either<AuthFailure, AuthToken>> register(Email email, String password);
}
