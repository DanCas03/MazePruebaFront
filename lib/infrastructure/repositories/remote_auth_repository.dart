import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../domain/auth/failures/auth_failure.dart';
import '../../domain/auth/repositories/i_auth_repository.dart';
import '../../domain/auth/value_objects/auth_token.dart';
import '../../domain/auth/value_objects/email.dart';
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
      Email email, String password) async {
    try {
      final token = await _remote.register(email.value, password);
      return Right(AuthToken(token));
    } on DioException catch (e) {
      return Left(_mapRegister(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  AuthFailure _mapLogin(DioException e) {
    if (_isNetwork(e)) return const NetworkFailure();
    if (e.response?.statusCode == 401) return const InvalidCredentials();
    return const UnexpectedFailure();
  }

  AuthFailure _mapRegister(DioException e) {
    if (_isNetwork(e)) return const NetworkFailure();
    if (e.response?.statusCode == 400) return const EmailAlreadyRegistered();
    return const UnexpectedFailure();
  }

  bool _isNetwork(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.connectionError;
}
