import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/network/dio_client.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/in_memory_session_token_store.dart';

/// Adapter que no toca la red: registra los headers del request y devuelve un
/// 200 vacío, para ejercer el interceptor de punta a punta (proxy determinista
/// de la verificación e2e contra el back).
class _CapturingAdapter implements HttpClientAdapter {
  Map<String, dynamic>? capturedHeaders;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    capturedHeaders = Map<String, dynamic>.from(options.headers);
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

void main() {
  test('una sesión remember:false firma el POST /scores saliente', () async {
    // Arrange — token solo en memoria (lo que hace saveSession con persist:false).
    final session = InMemorySessionTokenStore()..current = AuthToken('jwt-mem');
    final dio = DioClient.create(session);
    final adapter = _CapturingAdapter();
    dio.httpClientAdapter = adapter;
    // Act
    await dio.post('/scores', data: {'levelId': '1'});
    // Assert
    expect(adapter.capturedHeaders?['Authorization'], 'Bearer jwt-mem');
  });
}
