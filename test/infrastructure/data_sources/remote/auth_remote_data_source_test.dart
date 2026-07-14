import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/infrastructure/data_sources/remote/auth_remote_data_source.dart';

import 'auth_remote_data_source_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio dio;
  late AuthRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = AuthRemoteDataSource(dio);
  });

  Response<dynamic> okResponse(String path, Map<String, dynamic> data) => Response(
        requestOptions: RequestOptions(path: path),
        data: data,
        statusCode: 200,
      );

  test('login POSTs /auth/login and returns the token field', () async {
    // Arrange
    when(dio.post('/auth/login', data: anyNamed('data')))
        .thenAnswer((_) async => okResponse('/auth/login', {'token': 'jwt-123'}));
    // Act
    final token = await dataSource.login('a@b.com', 'secret12');
    // Assert
    expect(token, 'jwt-123');
    verify(dio.post('/auth/login', data: {'email': 'a@b.com', 'password': 'secret12'}))
        .called(1);
  });

  test('register POSTs /auth/register with username and returns the token field', () async {
    // Arrange
    when(dio.post('/auth/register', data: anyNamed('data')))
        .thenAnswer((_) async => okResponse('/auth/register', {'token': 'jwt-456'}));
    // Act
    final token = await dataSource.register('a@b.com', 'player_01', 'secret12');
    // Assert
    expect(token, 'jwt-456');
    verify(dio.post('/auth/register', data: {
      'email': 'a@b.com',
      'username': 'player_01',
      'password': 'secret12',
    })).called(1);
  });

  test('propagates DioException from login', () async {
    // Arrange
    when(dio.post('/auth/login', data: anyNamed('data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
            requestOptions: RequestOptions(path: '/auth/login'), statusCode: 401),
        type: DioExceptionType.badResponse,
      ),
    );
    // Act / Assert
    expect(() => dataSource.login('a@b.com', 'bad'), throwsA(isA<DioException>()));
  });
}
