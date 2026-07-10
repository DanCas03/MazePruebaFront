import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/state/auth_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/restore_session_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/core/auth/auth_gate.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_token_storage.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_remote_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/presentation/auth/screens/login_screen.dart';
import 'package:flutter_arrow_maze/presentation/home/screens/home_screen.dart';
import 'package:flutter_arrow_maze/presentation/providers/dependency_providers.dart';

import 'auth_gate_test.mocks.dart';

// front#18: AuthGate ahora dispara el sync de progreso al pasar a Authenticated,
// leyendo syncProgressUseCaseProvider -> remoteProgressRepositoryProvider (cuyo
// default lanza). Un fake que no toca red satisface esa dependencia sin afectar
// las aserciones del guard.
class _FakeRemote implements IRemoteProgressRepository {
  // Cuenta las llamadas a pull() para verificar cuántas veces se disparó el
  // sync desde el listener del AuthGate.
  int pullCalls = 0;

  @override
  Future<List<LevelProgress>> pull() async {
    pullCalls++;
    return [];
  }

  @override
  Future<List<LevelProgress>> push(List<LevelProgress> progress) async =>
      progress;
}

// Repo local en memoria: el sync (getAll -> reconcile -> push -> upsertAll)
// necesita un ILevelProgressRepository. Sin este override el default abre la
// caja Hive real, no inicializada en el test, y ensucia la salida con un
// HiveError. Es ortogonal a lo que verifica el guard.
class _FakeLocal implements ILevelProgressRepository {
  @override
  Future<List<LevelProgress>> getAll() async => [];
  @override
  Future<void> upsertAll(List<LevelProgress> progress) async {}
  @override
  Future<MoveCount?> getProgress(LevelId levelId) => throw UnimplementedError();
  @override
  Future<void> saveProgress(LevelId levelId, MoveCount moves) =>
      throw UnimplementedError();
  @override
  Future<void> markCompleted(LevelId levelId) => throw UnimplementedError();
  @override
  Future<bool> isCompleted(LevelId levelId) => throw UnimplementedError();
}

// Logger silencioso: el sync loguea su resultado (AOP) al completar; en el test
// eso solo ensucia la salida. El logging es ortogonal a lo que verifica el guard.
class _SilentLogger implements ILoggerService {
  @override
  void log(String message, String context) {}
  @override
  void error(String message, String context, [Object? error]) {}
  @override
  void warn(String message, String context) {}
}

@GenerateMocks([IAuthTokenStorage])
void main() {
  Widget host(MockIAuthTokenStorage storage) => ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => AuthController(storage, RestoreSessionUseCase(storage)),
          ),
          remoteProgressRepositoryProvider.overrideWithValue(_FakeRemote()),
          levelProgressRepositoryProvider.overrideWithValue(_FakeLocal()),
          loggerServiceProvider.overrideWithValue(_SilentLogger()),
        ],
        child: const MaterialApp(home: AuthGate()),
      );

  testWidgets('shows LoginScreen when unauthenticated', (tester) async {
    // Arrange
    final storage = MockIAuthTokenStorage();
    when(storage.read()).thenAnswer((_) async => null);
    // Act
    await tester.pumpWidget(host(storage));
    await tester.pumpAndSettle();
    // Assert
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('shows HomeScreen when a valid token is restored', (tester) async {
    // Arrange — long-lived token (exp in 2100)
    final storage = MockIAuthTokenStorage();
    when(storage.read()).thenAnswer((_) async => AuthToken(
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1MSIsImV4cCI6NDEwMjQ0NDgwMH0.sig'));
    // Act
    await tester.pumpWidget(host(storage));
    // HomeScreen anima su logo en bucle infinito (repeat), así que
    // pumpAndSettle nunca se asentaría (ver home_screen_test.dart); bombeamos
    // con pumps acotados en su lugar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Assert
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
      'fires progress sync exactly once on the not-auth -> auth transition '
      'and not again on an auth -> auth rebuild', (tester) async {
    // Arrange — arranca no autenticado; usamos un container propio para poder
    // conducir la transición de estado invocando saveSession sobre el
    // AuthController real (probamos el ref.listen real de auth_gate.dart, no una
    // copia de su lógica). El fake remoto cuenta cuántas veces se llamó pull().
    final storage = MockIAuthTokenStorage();
    when(storage.read()).thenAnswer((_) async => null);
    final remote = _FakeRemote();
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(
        () => AuthController(storage, RestoreSessionUseCase(storage)),
      ),
      remoteProgressRepositoryProvider.overrideWithValue(remote),
      levelProgressRepositoryProvider.overrideWithValue(_FakeLocal()),
      loggerServiceProvider.overrideWithValue(_SilentLogger()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AuthGate()),
    ));
    await tester.pumpAndSettle(); // se asienta en Unauthenticated -> LoginScreen
    expect(remote.pullCalls, 0);

    // Long-lived tokens (exp en 2100); saveSession no valida expiración, solo
    // fija el estado Authenticated. Dos valores distintos para forzar una
    // segunda emisión Authenticated -> Authenticated que dispare el callback.
    final token1 = AuthToken(
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1MSIsImV4cCI6NDEwMjQ0NDgwMH0.sig');
    final token2 = AuthToken(
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1MiIsImV4cCI6NDEwMjQ0NDgwMH0.sig');

    // Act 1 — Unauthenticated -> Authenticated: el sync debe dispararse una vez.
    await container
        .read(authControllerProvider.notifier)
        .saveSession(token1, persist: false);
    await tester.pump(); // deja correr el ref.listen + rebuild (bounded pump)
    // Assert 1
    expect(remote.pullCalls, 1);

    // Act 2 — emite otro Authenticated (sigue autenticado): el guard
    // was-not-auth -> is-auth debe impedir un segundo disparo.
    await container
        .read(authControllerProvider.notifier)
        .saveSession(token2, persist: false);
    await tester.pump();
    // Assert 2 — no volvió a dispararse.
    expect(remote.pullCalls, 1);
  });
}
