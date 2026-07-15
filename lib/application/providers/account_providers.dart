import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/dependency_providers.dart';
import '../../domain/auth/entities/user_profile.dart';
import '../read_models/progress_totals.dart';
import '../state/auth_form_controller.dart';
import '../use_cases/get_current_user_use_case.dart';

/// Providers del panel de cuenta (front#78). Componen el caso de uso de perfil
/// sobre el `authRepositoryProvider` (sobrescrito en main con el Dio firmado) y
/// exponen a la presentación dos vistas reactivas `AsyncValue`, sin que esta
/// conozca `domain/` ni `infrastructure/`.

final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>(
  (ref) => GetCurrentUserUseCase(ref.read(authRepositoryProvider)),
);

/// Perfil del usuario autenticado. `autoDispose`: se re-consulta cada vez que se
/// abre el panel (refleja el usuario actual tras un cambio de sesión) y se
/// libera al cerrarlo. Desenvuelve el Either lanzando el `AuthFailure` en el
/// caso Left para que la UI lo reciba como `AsyncValue.error` y muestre su
/// `message` localizado con opción de reintento.
final currentUserProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final result = await ref.read(getCurrentUserUseCaseProvider).execute();
  return result.fold((failure) => throw failure, (profile) => profile);
});

/// Totales de progreso (estrellas + niveles completados) derivados del progreso
/// local. No necesita backend: reduce `getAll()` con `ProgressTotals.from`.
/// `autoDispose` por el mismo motivo que [currentUserProvider].
final progressTotalsProvider =
    FutureProvider.autoDispose<ProgressTotals>((ref) async {
  final progress = await ref.read(levelProgressRepositoryProvider).getAll();
  return ProgressTotals.from(progress);
});
