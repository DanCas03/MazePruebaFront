import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/auth_controller.dart';
import 'package:flutter_arrow_maze/application/state/auth_form_controller.dart';
import 'package:flutter_arrow_maze/application/state/auth_state.dart';
import 'package:flutter_arrow_maze/application/use_cases/restore_session_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/core/auth/auth_gate.dart';
import 'package:flutter_arrow_maze/core/di/dependency_providers.dart';
import 'package:flutter_arrow_maze/domain/auth/entities/user_profile.dart';
import 'package:flutter_arrow_maze/domain/auth/failures/auth_failure.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_repository.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_token_storage.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/email.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/username.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_remote_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/in_memory_session_token_store.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/auth/screens/login_screen.dart';
import 'package:flutter_arrow_maze/presentation/home/screens/home_screen.dart';

import '../../support/auth_fakes.dart';

// Token de larga vida (exp en 2100): el restore lo acepta -> arranca autenticado.
final _validToken = AuthToken(
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1MSIsImV4cCI6NDEwMjQ0NDgwMH0.sig');

/// Storage en memoria: arranca con un token vivo; `clear()` (logout) lo borra.
class _FakeStorage implements IAuthTokenStorage {
  AuthToken? _token;
  _FakeStorage(this._token);
  @override
  Future<void> save(AuthToken token) async => _token = token;
  @override
  Future<AuthToken?> read() async => _token;
  @override
  Future<void> clear() async => _token = null;
}

/// Puerto de auth: `me()` resuelve el perfil mostrado en el panel.
class _FakeAuthRepo implements IAuthRepository {
  @override
  Future<Either<AuthFailure, UserProfile>> me() async => Right(UserProfile(
        id: 'u-1',
        username: Username('player_01'),
        email: Email('player@arrowmaze.com'),
      ));
  @override
  Future<Either<AuthFailure, AuthToken>> login(Email email, String password) =>
      throw UnimplementedError();
  @override
  Future<Either<AuthFailure, AuthToken>> register(
          Email email, String username, String password) =>
      throw UnimplementedError();
}

/// Progreso local: alimenta tanto el sync del gate como los totales del panel.
class _FakeLocal implements ILevelProgressRepository {
  @override
  Future<List<LevelProgress>> getAll() async => [
        LevelProgress(levelId: LevelId('l1'), completed: true, bestStars: 3),
      ];
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

class _FakeRemote implements IRemoteProgressRepository {
  @override
  Future<List<LevelProgress>> pull() async => [];
  @override
  Future<List<LevelProgress>> push(List<LevelProgress> progress) async =>
      progress;
}

class _SilentLogger implements ILoggerService {
  @override
  void log(String message, String context) {}
  @override
  void error(String message, String context, [Object? error]) {}
  @override
  void warn(String message, String context) {}
}

void main() {
  ProviderContainer buildContainer() {
    final storage = _FakeStorage(_validToken);
    return ProviderContainer(overrides: [
      authControllerProvider.overrideWith(
        () => AuthController(storage, RestoreSessionUseCase(storage),
            InMemorySessionTokenStore(), NoopUserScopedStorage()),
      ),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
      levelProgressRepositoryProvider.overrideWithValue(_FakeLocal()),
      remoteProgressRepositoryProvider.overrideWithValue(_FakeRemote()),
      loggerServiceProvider.overrideWithValue(_SilentLogger()),
    ]);
  }

  Widget host(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthGate(),
        ),
      );

  // HomeScreen anima su logo en bucle infinito (repeat): pumpAndSettle nunca se
  // asentaría, así que bombeamos con pumps acotados (mismo patrón que
  // home_screen_test / auth_gate_test).
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('tapping Sign out signs the user out and lands on LoginScreen',
      (tester) async {
    // Arrange — arranca autenticado -> HomeScreen.
    final container = buildContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(host(container));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    // Act 1 — abre el panel de cuenta desde el icono top-left.
    await tester.tap(find.byTooltip('Cuenta'));
    await settle(tester);
    // El perfil resuelto se muestra en el panel.
    expect(find.text('player_01'), findsOneWidget);
    expect(find.text('player@arrowmaze.com'), findsOneWidget);

    // Act 2 — cierra sesión.
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await settle(tester);

    // Assert — el gate conmutó a LoginScreen y la sesión se limpió.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(
      container.read(authControllerProvider).valueOrNull,
      isA<Unauthenticated>(),
    );
  });

  testWidgets('account panel shows the local progress totals', (tester) async {
    // Arrange
    final container = buildContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(host(container));
    await settle(tester);

    // Act — abre el panel.
    await tester.tap(find.byTooltip('Cuenta'));
    await settle(tester);

    // Assert — 3 estrellas y 1 nivel completado (del _FakeLocal).
    expect(find.text('3 estrellas'), findsOneWidget);
    expect(find.text('1 niveles completados'), findsOneWidget);
  });
}
