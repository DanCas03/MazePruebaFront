import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/state/auth_controller.dart';
import 'package:flutter_arrow_maze/application/state/auth_form_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/restore_session_use_case.dart';
import 'package:flutter_arrow_maze/core/auth/auth_gate.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_repository.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_token_storage.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_remote_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/in_memory_session_token_store.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/auth/screens/login_screen.dart';
import 'package:flutter_arrow_maze/presentation/auth/screens/register_screen.dart';
import 'package:flutter_arrow_maze/presentation/home/screens/home_screen.dart';
import 'package:flutter_arrow_maze/presentation/providers/dependency_providers.dart';

import 'register_flow_test.mocks.dart';

// front#18: AuthGate ahora dispara el sync de progreso al pasar a Authenticated,
// leyendo syncProgressUseCaseProvider -> remoteProgressRepositoryProvider (cuyo
// default lanza). Un fake que no toca red satisface esa dependencia sin afectar
// la regresión que este test reproduce.
class _FakeRemote implements IRemoteProgressRepository {
  @override
  Future<List<LevelProgress>> pull() async => [];
  @override
  Future<List<LevelProgress>> push(List<LevelProgress> progress) async =>
      progress;
}

/// Regresión de front#15 (revisión final): RegisterScreen se apila con
/// Navigator.push sobre AuthGate en "/". Al registrarse con éxito, AuthGate
/// reconstruye "/" de LoginScreen a HomeScreen, pero si RegisterScreen no se
/// hace pop a sí misma queda encima, tapando HomeScreen. Este test monta el
/// cableado real (AuthGate + AppRouter + AuthController + AuthFormController)
/// para reproducir el bug end-to-end en vez de aislar RegisterScreen con stubs.
@GenerateMocks([IAuthRepository, IAuthTokenStorage])
void main() {
  // Token de larga duración (exp en 2100), igual que en auth_gate_test.dart,
  // para que RestoreSessionUseCase/AuthController lo acepten como válido.
  const longLivedToken =
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1MSIsImV4cCI6NDEwMjQ0NDgwMH0.sig';

  Widget host(MockIAuthRepository repo, MockIAuthTokenStorage storage) =>
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          authControllerProvider.overrideWith(
            () => AuthController(
                storage, RestoreSessionUseCase(storage), InMemorySessionTokenStore()),
          ),
          remoteProgressRepositoryProvider.overrideWithValue(_FakeRemote()),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthGate(),
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );

  testWidgets(
      'popping RegisterScreen after successful sign-up reveals HomeScreen',
      (tester) async {
    // Arrange
    final repo = MockIAuthRepository();
    final storage = MockIAuthTokenStorage();
    when(storage.read()).thenAnswer((_) async => null);
    when(storage.save(any)).thenAnswer((_) async {});
    when(repo.register(any, any, any))
        .thenAnswer((_) async => Right(AuthToken(longLivedToken)));

    await tester.pumpWidget(host(repo, storage));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // Act — navigate to RegisterScreen (pushed on top of "/")
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);

    // Fill valid email, username, password (>=8) and matching confirm.
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'newuser@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de usuario'),
        'newuser01');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña'),
        'password123');
    await tester.enterText(
        find.widgetWithText(TextField, 'Confirmar contraseña'),
        'password123');

    await tester
        .tap(find.widgetWithText(FilledButton, 'Registrarme'));

    // Bounded pumps: HomeScreen has an infinite AnimationController.repeat(),
    // so pumpAndSettle would hang here (mirrors auth_gate_test.dart /
    // home_screen_test.dart). Several async hops separate the tap from the
    // AuthState change (use case call, saveSession, storage.save), so pump a
    // few times to flush the microtask/future chain, then pump through the
    // MaterialPageRoute pop transition (default 300ms) before asserting.
    await tester.pump(); // flush register() future resolution
    await tester.pump(); // flush saveSession()/storage.save() await
    await tester.pump(); // flush AuthState -> Authenticated propagation
    await tester.pump(const Duration(milliseconds: 300)); // pop transition
    await tester.pump(const Duration(milliseconds: 300)); // settle

    // Assert — the discriminating assertion: RegisterScreen must be gone
    // (popped) for HomeScreen (mounted underneath at "/") to be visible.
    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
