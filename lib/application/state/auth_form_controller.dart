import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth/failures/auth_failure.dart';
import '../../domain/auth/repositories/i_auth_repository.dart';
import '../../domain/auth/value_objects/auth_token.dart';
import '../use_cases/login_use_case.dart';
import '../use_cases/register_use_case.dart';
import 'auth_controller.dart';
import 'auth_form_state.dart';

/// Puerto de repo remoto de auth. Se sobrescribe en `main` con
/// RemoteAuthRepository (DIP); la fábrica por defecto falla explícitamente para
/// no acoplar este archivo a impls concretas.
final authRepositoryProvider = Provider<IAuthRepository>(
  (ref) => throw UnimplementedError(
    'authRepositoryProvider must be overridden with composed dependencies',
  ),
);

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.read(authRepositoryProvider)),
);

final registerUseCaseProvider = Provider<RegisterUseCase>(
  (ref) => RegisterUseCase(ref.read(authRepositoryProvider)),
);

final authFormControllerProvider =
    NotifierProvider<AuthFormController, AuthFormState>(AuthFormController.new);

/// Orquesta el envío del formulario (Observer/State): invoca el use case y, en
/// éxito, delega en AuthController.saveSession (que decide persistir según
/// "recordarme"). La UI solo observa FormIdle/FormSubmitting/FormError; la
/// navegación post-login la resuelve el AuthGate al cambiar AuthState.
class AuthFormController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const FormIdle();

  Future<void> login(String email, String password,
      {required bool remember}) async {
    await _submit(
      () => ref.read(loginUseCaseProvider).execute(email, password),
      remember: remember,
    );
  }

  Future<void> register(String email, String password,
      {required bool remember}) async {
    await _submit(
      () => ref.read(registerUseCaseProvider).execute(email, password),
      remember: remember,
    );
  }

  /// Fragmento común de login/register (Observer/State): emite Submitting,
  /// ejecuta el use case y bifurca en éxito/fracaso. Extraído para eliminar
  /// duplicación entre ambos flujos, que solo difieren en el use case a invocar.
  Future<void> _submit(
    Future<Either<AuthFailure, AuthToken>> Function() action, {
    required bool remember,
  }) async {
    state = const FormSubmitting();
    final result = await action();
    await result.fold(
      (failure) async => state = FormError(failure),
      (token) async {
        await ref
            .read(authControllerProvider.notifier)
            .saveSession(token, persist: remember);
        state = const FormIdle();
      },
    );
  }
}
