import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../domain/auth/entities/user_profile.dart';
import '../../domain/auth/failures/auth_failure.dart';
import '../../domain/auth/repositories/i_auth_repository.dart';
import '../../domain/auth/value_objects/auth_token.dart';
import '../../domain/auth/value_objects/email.dart';
import '../../domain/auth/value_objects/username.dart';
import '../data_sources/remote/auth_remote_data_source.dart';

/// Adapter: implementa el puerto IAuthRepository traduciendo el data source Dio
/// al lenguaje del dominio (AuthToken / AuthFailure). Aquí muere DioException:
/// ninguna capa superior conoce HTTP.
class RemoteAuthRepository implements IAuthRepository {
  final AuthRemoteDataSource _remote;
  RemoteAuthRepository(this._remote);

  @override
  Future<Either<AuthFailure, AuthToken>> login(
      Email email, String password) async {
    try {
      final token = await _remote.login(email.value, password);
      return Right(AuthToken(token));
    } on DioException catch (e) {
      return Left(_mapLogin(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<AuthFailure, AuthToken>> register(
      Email email, String username, String password) async {
    try {
      final token = await _remote.register(email.value, username, password);
      return Right(AuthToken(token));
    } on DioException catch (e) {
      return Left(_mapRegister(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<AuthFailure, UserProfile>> me() async {
    try {
      final data = await _remote.me();
      return Right(UserProfile(
        id: data['id'] as String,
        username: Username(data['username'] as String),
        email: Email(data['email'] as String),
      ));
    } on DioException catch (e) {
      return Left(_mapMe(e));
    } catch (_) {
      // Incluye un payload malformado (campo ausente / VO que rechaza el valor):
      // no debe tumbar la pantalla, se degrada a fallo inesperado.
      return const Left(UnexpectedFailure());
    }
  }

  AuthFailure _mapLogin(DioException e) {
    if (_isNetwork(e)) return const NetworkFailure();
    if (e.response?.statusCode == 401) return const InvalidCredentials();
    return const UnexpectedFailure();
  }

  AuthFailure _mapMe(DioException e) {
    if (_isNetwork(e)) return const NetworkFailure();
    // 401: token ausente/expirado — la sesión ya no vale como credencial.
    if (e.response?.statusCode == 401) return const InvalidCredentials();
    // 404 (el token es válido pero el usuario ya no existe) y demás caen a
    // inesperado: no son estados accionables por el jugador desde este panel.
    return const UnexpectedFailure();
  }

  AuthFailure _mapRegister(DioException e) {
    if (_isNetwork(e)) return const NetworkFailure();
    // El back responde 409 (Conflict) para email/username ya tomados —
    // no 400, que es Bad Request por payload inválido (bug real que este
    // fix corrige: antes se mapeaba 400, enmascarando errores de validación
    // no relacionados como si fueran "ya registrado").
    if (e.response?.statusCode == 409) return const EmailAlreadyRegistered();
    return const UnexpectedFailure();
  }

  bool _isNetwork(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.connectionError;
}
