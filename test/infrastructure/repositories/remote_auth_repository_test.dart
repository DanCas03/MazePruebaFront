import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/domain/auth/entities/user_profile.dart';
import 'package:flutter_arrow_maze/domain/auth/failures/auth_failure.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/email.dart';
import 'package:flutter_arrow_maze/infrastructure/data_sources/remote/auth_remote_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/remote_auth_repository.dart';

import 'remote_auth_repository_test.mocks.dart';

DioException _dioError({int? status, DioExceptionType type = DioExceptionType.badResponse}) =>
    DioException(
      requestOptions: RequestOptions(path: '/auth'),
      type: type,
      response: status == null
          ? null
          : Response(requestOptions: RequestOptions(path: '/auth'), statusCode: status),
    );

@GenerateMocks([AuthRemoteDataSource])
void main() {
  late MockAuthRemoteDataSource remote;
  late RemoteAuthRepository repo;
  final email = Email('a@b.com');

  setUp(() {
    remote = MockAuthRemoteDataSource();
    repo = RemoteAuthRepository(remote);
  });

  test('login returns Right(AuthToken) on success', () async {
    // Arrange
    when(remote.login('a@b.com', 'secret12')).thenAnswer((_) async => 'jwt-1');
    // Act
    final result = await repo.login(email, 'secret12');
    // Assert
    expect(result.isRight(), isTrue);
    result.map((t) => expect(t, AuthToken('jwt-1')));
  });

  test('login maps 401 to InvalidCredentials', () async {
    when(remote.login(any, any)).thenThrow(_dioError(status: 401));
    final result = await repo.login(email, 'bad');
    expect(result, const Left<AuthFailure, AuthToken>(InvalidCredentials()));
  });

  test('login maps connectionError to NetworkFailure', () async {
    when(remote.login(any, any))
        .thenThrow(_dioError(type: DioExceptionType.connectionError));
    final result = await repo.login(email, 'x');
    expect(result, const Left<AuthFailure, AuthToken>(NetworkFailure()));
  });

  test('register maps 409 to EmailAlreadyRegistered', () async {
    // El back usa 409 (Conflict) para email/username ya tomados.
    when(remote.register(any, any, any)).thenThrow(_dioError(status: 409));
    final result = await repo.register(email, 'player_01', 'secret12');
    expect(result, const Left<AuthFailure, AuthToken>(EmailAlreadyRegistered()));
  });

  test('register maps 400 to UnexpectedFailure, not EmailAlreadyRegistered', () async {
    // Regresión: 400 es Bad Request (payload inválido), no "ya registrado".
    // Mapearlo a EmailAlreadyRegistered enmascaraba errores de validación
    // reales (p.ej. un campo requerido faltante) como un falso "ya existe".
    when(remote.register(any, any, any)).thenThrow(_dioError(status: 400));
    final result = await repo.register(email, 'player_01', 'secret12');
    expect(result, const Left<AuthFailure, AuthToken>(UnexpectedFailure()));
  });

  test('register returns UnexpectedFailure on non-Dio error', () async {
    when(remote.register(any, any, any)).thenThrow(Exception('boom'));
    final result = await repo.register(email, 'player_01', 'secret12');
    expect(result, const Left<AuthFailure, AuthToken>(UnexpectedFailure()));
  });

  test('me returns Right(UserProfile) mapping the raw fields to VOs', () async {
    // Arrange
    when(remote.me()).thenAnswer((_) async =>
        {'id': 'u-1', 'username': 'player_01', 'email': 'a@b.com'});
    // Act
    final result = await repo.me();
    // Assert
    expect(result.isRight(), isTrue);
    result.map((p) {
      expect(p.id, 'u-1');
      expect(p.username.value, 'player_01');
      expect(p.email.value, 'a@b.com');
    });
  });

  test('me maps 401 to InvalidCredentials', () async {
    when(remote.me()).thenThrow(_dioError(status: 401));
    final result = await repo.me();
    expect(result, const Left<AuthFailure, UserProfile>(InvalidCredentials()));
  });

  test('me maps connectionError to NetworkFailure', () async {
    when(remote.me()).thenThrow(_dioError(type: DioExceptionType.connectionError));
    final result = await repo.me();
    expect(result, const Left<AuthFailure, UserProfile>(NetworkFailure()));
  });

  test('me maps 404 (user gone) to UnexpectedFailure', () async {
    when(remote.me()).thenThrow(_dioError(status: 404));
    final result = await repo.me();
    expect(result, const Left<AuthFailure, UserProfile>(UnexpectedFailure()));
  });

  test('me degrades a malformed payload to UnexpectedFailure', () async {
    // El VO Username rechaza un valor fuera de política -> ArgumentError,
    // que el repo captura como fallo inesperado en vez de tumbar la pantalla.
    when(remote.me()).thenAnswer(
        (_) async => {'id': 'u-1', 'username': 'x', 'email': 'a@b.com'});
    final result = await repo.me();
    expect(result, const Left<AuthFailure, UserProfile>(UnexpectedFailure()));
  });
}
